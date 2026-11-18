"""Pazzie: the top 30 trips under 50 euro of each kind (piccole = weekend, medie = weekend+,
grandi = ponte), with titles and sentences written ahead by the AI.

The app builds its own ranking from the airports chosen on the device, so the job prepares
the texts for every combination of departure airports. Texts already written in a previous
run are kept; only new offers go to the AI Worker (POST /crazy, at most 30 per call).
"""

from __future__ import annotations

from itertools import combinations

from . import net

MAX_PRICE = 50  # same limits as the app (app/lib/screens/crazy.dart)
COUNT = 30
KINDS = ("weekend", "weekend+", "ponte")  # the three tabs of the app
CITY = {"VRN": "Verona", "BGY": "Bergamo", "TSF": "Treviso"}


def offer_id(o: dict) -> str:
    return f"{o['origin']}-{o['destination']}-{o['out_date']}-{o['ret_date']}"


def ranking(offers: list[dict], airports: set[str], kind: str = "weekend") -> list[dict]:
    """The top COUNT trips of this kind under MAX_PRICE from these airports, nearest first."""
    picked = [o for o in offers if o["origin"] in airports and o.get("type") == kind and o["price"] < MAX_PRICE]
    picked.sort(key=lambda o: (o["out_date"], o["price"]))
    return picked[:COUNT]


def needed(offers: list[dict], airports: list[str]) -> list[dict]:
    """Every offer that can appear in the ranking of some combination of airports."""
    seen: dict[str, dict] = {}
    for n in range(1, len(airports) + 1):
        for combo in combinations(airports, n):
            for kind in KINDS:
                for o in ranking(offers, set(combo), kind):
                    seen.setdefault(offer_id(o), o)
    return sorted(seen.values(), key=lambda o: (o["out_date"], o["price"]))


VERSION = 3  # bump when the texts must say something new: older texts are written again


def _time(leg: dict | None, key: str) -> str:
    """Local "HH:MM" of a leg's departure or arrival ("" when unknown)."""
    t = (leg or {}).get(key) or ""
    return t[11:16] if len(t) >= 16 else ""


def request_item(o: dict) -> dict:
    """What the Worker needs to write one entry (same fields as the app sends)."""
    return {
        "id": offer_id(o), "city": o.get("city") or o["destination"], "country": o.get("country", ""),
        "from": CITY.get(o["origin"], o["origin"]), "out": o["out_date"], "ret": o["ret_date"],
        "price": o["price"], "hours": o.get("useful_hours"),
        "dep": _time(o.get("outbound"), "departure"), "arr": _time(o.get("inbound"), "arrival"),
        "kind": o.get("type", "weekend"), "leave": o.get("leave_days", 0),
        "holidays": ", ".join(o.get("holidays") or []),
    }


def publish(offers: list[dict], airports: list[str], previous: dict, ai_url: str, warnings: list[str]) -> dict:
    """{"items": {id: {"title", "text"}}} for every offer the rankings can show."""
    old = previous.get("items", {}) if previous.get("version") == VERSION else {}
    want = needed(offers, airports)
    items = {offer_id(o): old[offer_id(o)] for o in want if offer_id(o) in old}
    todo = [o for o in want if offer_id(o) not in items]
    for i in range(0, len(todo), COUNT):
        batch = todo[i:i + COUNT]
        body = {"items": [request_item(o) for o in batch]}
        try:
            res = net.get_json(f"{ai_url}/crazy", body=body, timeout=120, retries=1)
        except Exception as e:  # the app falls back to a plain sentence, or asks the Worker itself
            warnings.append(f"pazzie: {type(e).__name__}: {e}"[:300])
            continue
        for x in res.get("items", []):
            if x.get("title") and x.get("text"):
                items[x["id"]] = {"title": x["title"], "text": x["text"]}
    return {"version": VERSION, "items": items, "model": "Cloudflare Workers AI"}
