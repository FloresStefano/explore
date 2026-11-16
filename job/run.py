"""Job giornaliero (sezione 6): coda, fonti, selezione, storico, file pubblicati.

    python -m job.run                # normal daily run
    python -m job.run --cap 5        # at most 5 calls per source (local tests)
"""

from __future__ import annotations

import argparse
import json
import time
import traceback
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from .calendar_it import Calendar, Window, search_pairs, windows
from .history import History
from .model import Leg, Offer
from .selection import discard_reason, offer_leave_days, useful_hours
from .settings import ROOT, Settings, load
from .sources.base import AnywhereSource
from .sources.ryanair import Ryanair
from .sources.skiplagged import Skiplagged
from .workqueue import WorkQueue

DATA = ROOT / "data"
STATE = ROOT / "state"
ARCHIVE = ROOT / "archive"
MAX_CONSECUTIVE_ERRORS = 5  # a source failing this often in a row is probably blocked: stop it for today

PATRONS = {
    # Tabella comune-patrono (sezione 4). Per ora solo Verona, inserita a mano.
    "Verona": {"region": "veneto", "patron": "05-21", "saint": "San Zeno", "airports": ["VRN", "BGY", "TSF"]},
}


def write_json(path: Path, payload, compact: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":")) if compact else \
        json.dumps(payload, ensure_ascii=False, indent=1)
    path.write_text(text + "\n", "utf-8")


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text("utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


# ---------- airports and routes ----------

def airport_info(s: Settings, fr: Ryanair, today: date, meta: dict) -> dict[str, dict]:
    """Code -> name, city, country, coordinates, time zone. Cached, refreshed every JOB-05 days."""
    path = STATE / "airports.json"
    cache = read_json(path, {})
    fresh = cache.get("updated") and (today - date.fromisoformat(cache["updated"])).days < s["JOB-05"]
    if fresh:
        return cache["airports"]
    try:
        airports = {a["code"]: {
            "code": a["code"], "name": a["name"], "city": a["city"]["name"], "country": a["country"]["name"],
            "country_code": a["country"]["code"], "lat": a["coordinates"]["latitude"],
            "lon": a["coordinates"]["longitude"], "tz": a["timeZone"],
        } for a in fr.airports()}
        write_json(path, {"updated": today.isoformat(), "airports": airports})
        return airports
    except Exception as e:
        meta["warnings"].append(f"airports: {e}")
        return cache.get("airports", {})


def publish_routes(s: Settings, fr: Ryanair, today: date, airports: dict, offers_by_ap: dict, meta: dict) -> None:
    """data/routes/<AP>.json: direct destinations, airlines, active months (sezione 9)."""
    for ap in s.job["airports"]:
        path = DATA / "routes" / f"{ap}.json"
        current = read_json(path, {"airport": ap, "destinations": {}})
        dests: dict[str, dict] = current["destinations"]
        if not current.get("ryanair_updated") or (today - date.fromisoformat(current["ryanair_updated"])).days >= s["JOB-05"]:
            try:
                for r in fr.routes(ap):
                    code = r["arrivalAirport"]["code"]
                    d = dests.setdefault(code, {"airlines": [], "months": []})
                    d["seasonal"] = bool(r.get("seasonal"))
                    d["airlines"] = sorted(set(d["airlines"]) | {"Ryanair"})
                    d["last_confirmed"] = today.isoformat()
                current["ryanair_updated"] = today.isoformat()
            except Exception as e:
                meta["warnings"].append(f"routes {ap}: {e}")
        # Every destination seen in a search enters the map and marks its month as active.
        for pair in offers_by_ap.get(ap, {}).values():
            for o in pair["offers"]:
                d = dests.setdefault(o["destination"], {"airlines": [], "months": []})
                d["airlines"] = sorted(set(d["airlines"]) | set(o["airlines"]))
                d["months"] = sorted(set(d["months"]) | {o["out_date"][:7]})
                d["last_confirmed"] = max(d.get("last_confirmed", ""), o["observed_at"])
        for code, d in dests.items():
            d.update({k: v for k, v in airports.get(code, {}).items() if k != "code"})
        current["destinations"] = dict(sorted(dests.items()))
        current["updated"] = today.isoformat()
        write_json(path, current)


# ---------- offers ----------

def tz_iso(dt: datetime, tz: str | None) -> str:
    if tz:
        return dt.replace(tzinfo=ZoneInfo(tz)).isoformat(timespec="minutes")
    return dt.isoformat(timespec="minutes")


def leg_json(leg: Leg, airports: dict) -> dict:
    return {
        "from": leg.origin, "to": leg.destination, "flight": leg.flight, "airline": leg.airline,
        "departure": tz_iso(leg.departure, airports.get(leg.origin, {}).get("tz")),
        "arrival": tz_iso(leg.arrival, airports.get(leg.destination, {}).get("tz")),
    }


def window_type(w: Window) -> str:
    """Comparable trips (IMP-02): plain weekends vs everything around a holiday or with leave."""
    return "weekend" if w.reason == "weekend" else "ponte"


def offer_json(s: Settings, cal: Calendar, o: Offer, w: Window, airports: dict) -> dict:
    hours = useful_hours(s, o)
    dest = airports.get(o.destination, {})
    return {
        "origin": o.origin, "destination": o.destination,
        "destination_name": dest.get("name"), "city": dest.get("city"), "country": dest.get("country"),
        "out_date": o.out_date, "ret_date": o.ret_date, "nights": w.nights,
        "window": window_type(w), "window_reason": w.reason,
        "leave_days": offer_leave_days(s, cal, o, w.leave_days),
        "outbound": leg_json(o.outbound, airports) if o.outbound else None,
        "inbound": leg_json(o.inbound, airports) if o.inbound else None,
        "airlines": o.airlines, "price": o.price, "currency": o.currency, "fare": o.fare,
        "useful_hours": hours, "price_per_hour": round(o.price / hours, 2) if hours else None,
        # Sezione 8: filled once the history passes IMP-03.
        "reference_price": None, "discount_pct": None, "lowest_since": None, "unmissable": False,
        "source": o.source, "observed_at": o.observed_at, "link": o.link,
    }


def run_source(s: Settings, src: AnywhereSource, cap: int, today: date, pairs: list[Window], queue: WorkQueue,
               store: dict, history: History, cal: Calendar, airports: dict, discards: Counter) -> dict:
    stats = {"enabled": True, "cap": cap, "calls": 0, "ok": 0, "errors": 0, "offers": 0, "last_error": None}
    units = queue.pick(s, today, src.name, s.job["airports"], pairs, cap)
    stats["due_not_picked"] = None if len(units) < cap else "possibile arretrato"
    observed = today.isoformat()
    streak = 0
    for u in units:
        stats["calls"] += 1
        try:
            offers = src.anywhere(u.airport, u.window.out, u.window.ret, observed)
        except Exception as e:
            stats["errors"] += 1
            stats["last_error"] = f"{type(e).__name__}: {e}"[:300]
            queue.failed(u, stats["last_error"])
            streak += 1
            if streak >= MAX_CONSECUTIVE_ERRORS:
                stats["stopped"] = f"{streak} errori consecutivi"
                break
            continue
        streak = 0
        stats["ok"] += 1
        queue.done(u, today, len(offers))
        kept = []
        for o in offers:
            reason = discard_reason(s, o)
            history.add(f"{o.origin}-{o.destination}", observed, o.out_date, o.ret_date, u.window.nights,
                        window_type(u.window), o.price, o.source, reason is None)
            if reason:
                discards[reason] += 1
            elif o.has_times and useful_hours(s, o) <= 0:
                discards["SEL-06"] += 1
            else:
                kept.append(offer_json(s, cal, o, u.window, airports))
        stats["offers"] += len(kept)
        pair = store[u.airport].setdefault(u.window.key, {**u.window.to_json(), "offers": []})
        pair["offers"] = [x for x in pair["offers"] if x["source"] != src.name] + kept
        pair["offers"].sort(key=lambda x: (x["price_per_hour"] is None, x["price_per_hour"] or 0, x["price"]))
        time.sleep(s.job["pause_seconds"])
    return stats


def run_skiplagged(s: Settings, sk: Skiplagged, cap_disc: int, cap_route: int, today: date, pairs: list[Window],
                   queue: WorkQueue, store: dict, history: History, cal: Calendar, airports: dict,
                   discards: Counter) -> tuple[dict, dict]:
    """Other carriers (sezione 6, passo 5): "anywhere" discovery, then exact times per route.

    Discovery gives a price per destination but no times. Destinations where Ryanair
    is not already as cheap become candidates for a route search, which returns
    direct round trips with times; only those can be selected and published.
    """
    observed = today.isoformat()
    by_key = {w.key: w for w in pairs}
    cand_path = STATE / "candidates.json"
    cands: dict[str, dict[str, float]] = {k: v for k, v in read_json(cand_path, {}).items()
                                          if k.split("|")[1] in by_key}
    disc = {"enabled": True, "cap": cap_disc, "calls": 0, "ok": 0, "errors": 0, "destinations": 0, "last_error": None}
    streak = 0
    for u in queue.pick(s, today, sk.name, s.job["skiplagged_airports"], pairs, max(cap_disc, 0)):
        disc["calls"] += 1
        try:
            deals = sk.anywhere(u.airport, u.window.out, u.window.ret, observed)
        except Exception as e:
            disc["errors"] += 1
            disc["last_error"] = f"{type(e).__name__}: {e}"[:300]
            queue.failed(u, disc["last_error"])
            streak += 1
            if streak >= MAX_CONSECUTIVE_ERRORS:
                disc["stopped"] = f"{streak} errori consecutivi"
                break
            continue
        streak = 0
        disc["ok"] += 1
        disc["destinations"] += len(deals)
        queue.done(u, today, len(deals))
        cands[f"{u.airport}|{u.window.key}"] = {o.destination: o.price for o in deals}
        time.sleep(s.job["pause_seconds"])
    for code, place in sk.places.items():
        airports.setdefault(code, {"code": code, "name": place["city"], **place})
    write_json(cand_path, cands)

    def ryanair_covers(ap: str, key: str, dest: str, price: float) -> bool:
        offers = store.get(ap, {}).get(key, {}).get("offers", [])
        return any(o["source"] == "ryanair" and o["destination"] == dest and o["price"] <= price * 1.02 for o in offers)

    items = [(f"{ck.split('|')[0]}-{dest}", by_key[ck.split("|")[1]])
             for ck, dests in cands.items() for dest, price in dests.items()
             if ck.split("|")[0] in store and not ryanair_covers(*ck.split("|"), dest, price)]
    route = {"enabled": True, "cap": cap_route, "calls": 0, "ok": 0, "errors": 0, "offers": 0, "last_error": None,
             "candidates": len(items)}
    streak = 0
    for u in queue.pick_items(s, today, f"{sk.name}_route", items, max(cap_route, 0)):
        origin, dest = u.airport.split("-")
        route["calls"] += 1
        try:
            found = sk.route(origin, dest, u.window.out, u.window.ret, observed)
        except Exception as e:
            route["errors"] += 1
            route["last_error"] = f"{type(e).__name__}: {e}"[:300]
            queue.failed(u, route["last_error"])
            streak += 1
            if streak >= MAX_CONSECUTIVE_ERRORS:
                route["stopped"] = f"{streak} errori consecutivi"
                break
            continue
        streak = 0
        route["ok"] += 1
        queue.done(u, today, len(found))
        kept = []
        for o in found:
            if set(o.airlines) == {"Ryanair"}:
                continue  # the Ryanair adapter already has these, with exact prices
            reason = discard_reason(s, o)
            history.add(f"{origin}-{dest}", observed, o.out_date, o.ret_date, u.window.nights,
                        window_type(u.window), o.price, o.source, reason is None)
            if reason:
                discards[reason] += 1
            elif useful_hours(s, o) <= 0:
                discards["SEL-06"] += 1
            else:
                kept.append(offer_json(s, cal, o, u.window, airports))
        kept.sort(key=lambda x: x["price_per_hour"])
        kept = kept[:4]
        route["offers"] += len(kept)
        pair = store[origin].setdefault(u.window.key, {**u.window.to_json(), "offers": []})
        pair["offers"] = [x for x in pair["offers"]
                          if not (x["source"] == sk.name and x["destination"] == dest)] + kept
        pair["offers"].sort(key=lambda x: (x["price_per_hour"] is None, x["price_per_hour"] or 0, x["price"]))
        time.sleep(s.job["pause_seconds"])
    return disc, route


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cap", type=int, help="override JOB-06 for every enabled source")
    args = ap.parse_args(argv)

    started = datetime.now(timezone.utc)
    today = started.date()
    s = load()
    j = s.job
    kw = dict(market=j["market"], currency=j["currency"], language=j["language"], country=j["country"])
    meta: dict = {"run_at": started.isoformat(timespec="seconds"), "sources": {}, "warnings": []}
    cal = Calendar()

    fr = Ryanair(**kw)
    airports = airport_info(s, fr, today, meta)

    # Windows (national) and the date pairs we search.
    nat = windows(s, today, s["FIN-06"], cal)
    write_json(DATA / "windows" / "national.json",
               {"generated": today.isoformat(), "windows": [w.to_json() for w in nat]})
    pairs = search_pairs(s, today)
    keys = {w.key for w in pairs}

    # Offers store: keep yesterday's pairs that are still in range.
    store = {}
    for a in j["airports"]:
        old = read_json(DATA / "offers" / f"{a}.json", {}).get("pairs", {})
        store[a] = {k: v for k, v in old.items() if k in keys}
        # Offers of sources that are not re-read every cycle must not linger for ever.
        oldest = (today - timedelta(days=2 * s["JOB-04"])).isoformat()
        for pair in store[a].values():
            pair["offers"] = [o for o in pair["offers"] if o["source"] == "ryanair" or o["observed_at"] >= oldest]

    queue = WorkQueue(STATE / "queue.json")
    # JOB-06 is a daily cap: count calls already made today by earlier runs.
    usage_all = read_json(STATE / "usage.json", {})
    usage = usage_all.setdefault(today.isoformat(), {})
    history = History(ARCHIVE / "observations")
    discards: Counter = Counter()

    def cap_left(name: str) -> int:
        """JOB-06 minus what earlier runs used today; 0 or less means nothing to do."""
        cap = s.cap(name)
        if args.cap is not None and cap > 0:
            cap = args.cap
        return cap - usage.get(name, 0) if cap > 0 else -1

    def idle(name: str) -> dict:
        if s.cap(name) <= 0:
            return {"enabled": False}
        return {"enabled": True, "calls": 0, "note": "tetto giornaliero già raggiunto"}

    if cap_left(fr.name) > 0:
        try:
            meta["sources"][fr.name] = run_source(s, fr, cap_left(fr.name), today, pairs, queue, store, history,
                                                  cal, airports, discards)
        except Exception:
            meta["sources"][fr.name] = {"enabled": True, "crashed": traceback.format_exc()[-800:]}
    else:
        meta["sources"][fr.name] = idle(fr.name)

    sk = Skiplagged(**kw)
    airports.update({k: v for k, v in read_json(STATE / "places.json", {}).items() if k not in airports})
    meta["sources"]["skiplagged"], meta["sources"]["skiplagged_route"] = idle("skiplagged"), idle("skiplagged_route")
    if cap_left("skiplagged") > 0 or cap_left("skiplagged_route") > 0:
        try:
            disc, route = run_skiplagged(s, sk, cap_left("skiplagged"), cap_left("skiplagged_route"), today, pairs,
                                         queue, store, history, cal, airports, discards)
            if cap_left("skiplagged") > 0:
                meta["sources"]["skiplagged"] = disc
            if cap_left("skiplagged_route") > 0:
                meta["sources"]["skiplagged_route"] = route
        except Exception:
            meta["sources"]["skiplagged"] = {"enabled": True, "crashed": traceback.format_exc()[-800:]}
    write_json(STATE / "places.json", {k: v for k, v in airports.items() if "lat" not in v})
    for name, st in meta["sources"].items():
        usage[name] = usage.get(name, 0) + st.get("calls", 0)
    write_json(STATE / "usage.json", {k: v for k, v in usage_all.items() if k >= (today - timedelta(days=30)).isoformat()})
    queue.save(today)
    history.save()
    history.publish(DATA / "history")

    for a, pairs_map in store.items():
        write_json(DATA / "offers" / f"{a}.json", {"airport": a, "updated": today.isoformat(),
                                                    "pairs": dict(sorted(pairs_map.items()))}, compact=True)

    # Home (sezione 8): best offer per route, ranked by price per useful hour.
    best: dict[str, dict] = {}
    for pairs_map in store.values():
        for pair in pairs_map.values():
            for o in pair["offers"]:
                if o["price_per_hour"] is None:
                    continue
                route = f"{o['origin']}-{o['destination']}"
                if route not in best or o["price_per_hour"] < best[route]["price_per_hour"]:
                    best[route] = o
    top = sorted(best.values(), key=lambda o: o["price_per_hour"])[: s["IMP-04"]]
    write_json(DATA / "top.json", {"updated": today.isoformat(), "offers": top})

    publish_routes(s, fr, today, airports, store, meta)
    write_json(DATA / "settings.json", s.published())
    write_json(DATA / "patrons.json", PATRONS)

    coverage = {}
    for a in j["airports"]:
        fresh = sum(1 for w in pairs if (st := queue.state.get(f"ryanair|{a}|{w.key}", {}).get("fetched"))
                    and (today - date.fromisoformat(st)).days < queue.refresh_days(s, today, w.out))
        coverage[a] = {"pairs": len(pairs), "fresh": fresh}
    meta.update({"discards": dict(sorted(discards.items())), "coverage_ryanair": coverage,
                 "seconds": round((datetime.now(timezone.utc) - started).total_seconds())})
    write_json(DATA / "meta.json", meta)
    print(json.dumps(meta, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
