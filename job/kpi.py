"""Three indicators for every published offer (stored silently, shown on the Pazzie cards).

- costo chilometrico: price / great-circle km between the departure airport and the destination;
- costo orario: price / useful hours (SEL-06, SEL-07), the same as price_per_hour;
- vita: share of the stay (landing to the return take-off, destination local time) in the
  hours you live, 07:00-24:00; the night is the seven hours from 00:00 to 07:00.
"""

from __future__ import annotations

import math
from datetime import datetime, time, timedelta

LIFE_FROM = time(7, 0)  # hours of "vita": 07:00 to midnight


def distance_km(a: dict, b: dict) -> float | None:
    """Great-circle distance between two airports with lat/lon."""
    try:
        la1, lo1, la2, lo2 = (math.radians(float(x)) for x in (a["lat"], a["lon"], b["lat"], b["lon"]))
    except (KeyError, TypeError, ValueError):
        return None
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * 6371.0 * math.asin(math.sqrt(h))


def life_share(arrive: datetime, leave: datetime) -> int | None:
    """Percentage of the stay [arrive, leave] (destination local time) between 07:00 and 24:00."""
    if leave <= arrive:
        return None
    lived = timedelta()
    d = arrive.date()
    while d <= leave.date():
        lo = max(arrive, datetime.combine(d, LIFE_FROM))
        hi = min(leave, datetime.combine(d + timedelta(days=1), time(0, 0)))
        if hi > lo:
            lived += hi - lo
        d += timedelta(days=1)
    return round(100 * lived / (leave - arrive))


def kpis(o: dict, airports: dict) -> dict:
    """{"km", "eur_km", "eur_h", "life"} for a published offer; missing parts are left out."""
    out: dict = {}
    origin, dest = airports.get(o["origin"], {}), airports.get(o["destination"], {})
    km = distance_km(origin, dest)
    if km and km > 50:
        out["km"] = round(km)
        out["eur_km"] = round(o["price"] / km, 3)
    if o.get("useful_hours"):
        out["eur_h"] = round(o["price"] / o["useful_hours"], 2)
    try:
        # Both times are local to the destination, as the sources give them.
        arrive = datetime.fromisoformat((o.get("outbound") or {})["arrival"][:16])
        leave = datetime.fromisoformat((o.get("inbound") or {})["departure"][:16])
    except (KeyError, TypeError, ValueError):
        return out
    life = life_share(arrive, leave)
    if life is not None:
        out["life"] = life
    return out
