"""Prova sul campo delle fonti (piano, passo 1).

Run from the GitHub runner: queries every source from Verona on a test weekend and
records what comes back. Writes fieldtest/results/<stamp>.json and latest.md.

    python -m job.fieldtest [--label github]
"""

from __future__ import annotations

import argparse
import json
import platform
import time
import traceback
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from . import net
from .settings import ROOT, load
from .sources import google_flights
from .sources.ryanair import Ryanair
from .sources.skiplagged import Skiplagged

OUT_DIR = ROOT / "fieldtest" / "results"
# Routes from Verona flown (also) by carriers other than Ryanair: Volotea's base and Wizz/easyJet.
CROSS_ROUTES = ["PMO", "CTA", "NAP", "BRI", "CAG", "OLB", "BCN", "TIA", "LGW", "CDG"]
NON_FR = ("volotea", "wizz", "easyjet", "neos", "aeroitalia", "ita", "vueling", "transavia")


def test_weekend(today: date) -> tuple[date, date]:
    """First Friday at least 3 weeks away, back on Sunday."""
    d = today + timedelta(days=21)
    while d.weekday() != 4:
        d += timedelta(days=1)
    return d, d + timedelta(days=2)


def timed(fn):
    t = time.monotonic()
    try:
        res = fn()
        return {"ok": True, **res, "seconds": round(time.monotonic() - t, 2)}
    except Exception as e:  # the point is to record failures, not to stop
        return {"ok": False, "seconds": round(time.monotonic() - t, 2),
                "error": f"{type(e).__name__}: {e}"[:500], "trace": traceback.format_exc()[-1500:]}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", default=platform.node())
    args = ap.parse_args()

    s = load()
    j = s.job
    today = datetime.now(timezone.utc).date()
    out, ret = test_weekend(today)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    observed = today.isoformat()
    kw = dict(market=j["market"], currency=j["currency"], language=j["language"], country=j["country"])
    report: dict = {"label": args.label, "run_at": stamp, "test_dates": [out.isoformat(), ret.isoformat()]}

    report["network"] = timed(lambda: {"ipinfo": {k: v for k, v in net.get_json("https://ipinfo.io/json").items()
                                                  if k in ("country", "region", "org")}})

    fr = Ryanair(**kw)
    for ap_code in j["airports"]:
        def ryanair_run(code=ap_code):
            offers = fr.anywhere(code, out, ret, observed)
            return {"destinations": len(offers), "with_times": sum(o.has_times for o in offers),
                    "cheapest": sorted(([o.destination, o.price] for o in offers), key=lambda x: x[1])[:5]}
        report[f"ryanair_anywhere_{ap_code}"] = timed(ryanair_run)
        time.sleep(1)
    report["ryanair_routes_VRN"] = timed(lambda: {"routes": len(fr.routes("VRN"))})

    sk = Skiplagged(**kw)

    def sk_anywhere():
        offers = sk.anywhere("VRN", out, ret, observed)
        return {"destinations": len(offers), "with_times": 0,
                "all": sorted(([o.destination, o.price] for o in offers), key=lambda x: x[1])}
    report["skiplagged_anywhere_VRN"] = timed(sk_anywhere)

    sk_routes = {}
    for dest in CROSS_ROUTES[:6]:
        def sk_route(dest=dest):
            data = sk.flights("VRN", dest, out, ret)
            flights = data.get("flights") or []
            airlines = sorted({f.get("airlines", "") for f in flights})
            return {"flights": len(flights), "airlines": airlines,
                    "non_ryanair": [a for a in airlines if any(n in a.lower() for n in NON_FR)],
                    "sample": flights[:2]}
        sk_routes[dest] = timed(sk_route)
        time.sleep(1)
    report["skiplagged_route_VRN"] = sk_routes

    gf = {}
    for dest in CROSS_ROUTES:
        def gf_route(dest=dest):
            html = google_flights.fetch_html("VRN", dest, out, ret, j["currency"], j["language"], j["country"])
            flights = google_flights.parse(html)
            direct = [f for f in flights if len(f.flights) == 1]
            airlines = sorted({a for f in direct for a in f.airlines})
            return {"options": len(flights), "direct": len(direct), "airlines": airlines,
                    "non_ryanair": [a for a in airlines if any(n in a.lower() for n in NON_FR)],
                    "min_price": min((f.price for f in direct), default=None),
                    "price_level": google_flights.price_level(html), "html_bytes": len(html)}
        gf[dest] = timed(gf_route)
        time.sleep(2)
    report["google_flights_VRN"] = gf

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / f"{stamp}-{args.label}.json").write_text(json.dumps(report, indent=1, ensure_ascii=False), "utf-8")
    (OUT_DIR / "latest.md").write_text(summary(report), "utf-8")
    print(summary(report).encode('ascii', 'replace').decode())


def summary(r: dict) -> str:
    def line(name: str, x: dict) -> str:
        if not x.get("ok"):
            return f"| {name} | ❌ | {x.get('error', '')[:120]} |"
        keys = ("destinations", "routes", "flights", "direct", "airlines", "non_ryanair", "min_price", "price_level")
        info = ", ".join(f"{k}={x[k]}" for k in keys if k in x and x[k] not in (None, []))
        return f"| {name} | ✅ {x['seconds']}s | {info} |"

    rows = [f"# Prova fonti: {r['label']} {r['run_at']}", "",
            f"Weekend di prova: {r['test_dates'][0]} → {r['test_dates'][1]}  ",
            f"Rete: {r['network'].get('ipinfo', r['network'].get('error'))}", "",
            "| Prova | Esito | Dettagli |", "| --- | --- | --- |"]
    for k, v in r.items():
        if isinstance(v, dict) and "ok" in v and k != "network":
            rows.append(line(k, v))
        elif isinstance(v, dict) and k.endswith("_VRN") and k not in ("network",):
            rows += [line(f"{k} → {d}", x) for d, x in v.items()]
    return "\n".join(rows) + "\n"


if __name__ == "__main__":
    main()
