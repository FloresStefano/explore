"""Three indicators for every published offer (stored silently, shown on the Pazzie cards).

- costo chilometrico: price / great-circle km between the departure airport and the destination;
- costo orario: price / useful hours (SEL-06, SEL-07), the same as price_per_hour;
- ore di sole: share of the stay (landing to the return take-off, destination local time)
  that falls between sunrise and sunset there, from the airport's coordinates.
"""

from __future__ import annotations

import math
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

# Destinations without a time zone in the Ryanair list (other carriers): one zone per country.
COUNTRY_TZ = {
    "al": "Europe/Tirane", "at": "Europe/Vienna", "ba": "Europe/Sarajevo", "be": "Europe/Brussels",
    "bg": "Europe/Sofia", "ch": "Europe/Zurich", "cy": "Asia/Nicosia", "cz": "Europe/Prague", "de": "Europe/Berlin",
    "dk": "Europe/Copenhagen", "ee": "Europe/Tallinn", "eg": "Africa/Cairo", "es": "Europe/Madrid",
    "fi": "Europe/Helsinki", "fr": "Europe/Paris", "gb": "Europe/London", "ge": "Asia/Tbilisi", "gr": "Europe/Athens",
    "hr": "Europe/Zagreb", "hu": "Europe/Budapest", "ie": "Europe/Dublin", "il": "Asia/Jerusalem",
    "is": "Atlantic/Reykjavik", "it": "Europe/Rome", "jo": "Asia/Amman", "lt": "Europe/Vilnius",
    "lu": "Europe/Luxembourg", "lv": "Europe/Riga", "ma": "Africa/Casablanca", "md": "Europe/Chisinau",
    "me": "Europe/Podgorica", "mk": "Europe/Skopje", "mt": "Europe/Malta", "nl": "Europe/Amsterdam",
    "no": "Europe/Oslo", "pl": "Europe/Warsaw", "pt": "Europe/Lisbon", "ro": "Europe/Bucharest",
    "rs": "Europe/Belgrade", "se": "Europe/Stockholm", "si": "Europe/Ljubljana", "sk": "Europe/Bratislava",
    "tn": "Africa/Tunis", "tr": "Europe/Istanbul", "ae": "Asia/Dubai", "ua": "Europe/Kyiv", "xk": "Europe/Belgrade",
}


def distance_km(a: dict, b: dict) -> float | None:
    """Great-circle distance between two airports with lat/lon."""
    try:
        la1, lo1, la2, lo2 = (math.radians(float(x)) for x in (a["lat"], a["lon"], b["lat"], b["lon"]))
    except (KeyError, TypeError, ValueError):
        return None
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * 6371.0 * math.asin(math.sqrt(h))


def sun_utc(day: date, lat: float, lon: float) -> tuple[datetime, datetime] | None:
    """Sunrise and sunset in UTC (NOAA approximation, about a minute), None in polar day/night."""
    n = day.timetuple().tm_yday
    g = 2 * math.pi / 365 * (n - 1)
    eqt = 229.18 * (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g)
                    - 0.014615 * math.cos(2 * g) - 0.040849 * math.sin(2 * g))
    decl = (0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g) - 0.006758 * math.cos(2 * g)
            + 0.000907 * math.sin(2 * g) - 0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g))
    phi = math.radians(lat)
    cos_h = (math.cos(math.radians(90.833)) / (math.cos(phi) * math.cos(decl))) - math.tan(phi) * math.tan(decl)
    if not -1 <= cos_h <= 1:
        return None
    ha = math.degrees(math.acos(cos_h))
    midnight = datetime(day.year, day.month, day.day, tzinfo=timezone.utc)
    rise = midnight + timedelta(minutes=720 - 4 * (lon + ha) - eqt)
    sset = midnight + timedelta(minutes=720 - 4 * (lon - ha) - eqt)
    return rise, sset


def _zone(place: dict) -> ZoneInfo | None:
    name = place.get("tz") or COUNTRY_TZ.get(str(place.get("country_code", "")).lower())
    try:
        return ZoneInfo(name) if name else None
    except Exception:
        return None


def sun_share(arrive: datetime, leave: datetime, place: dict) -> int | None:
    """Percentage of the stay [arrive, leave] (naive, destination local time) in daylight."""
    zone = _zone(place)
    if zone is None or leave <= arrive or "lat" not in place:
        return None
    a, b = arrive.replace(tzinfo=zone), leave.replace(tzinfo=zone)
    lit = timedelta()
    d = a.date() - timedelta(days=1)
    while d <= b.date():
        sun = sun_utc(d, float(place["lat"]), float(place["lon"]))
        if sun:
            lo, hi = max(a, sun[0]), min(b, sun[1])
            if hi > lo:
                lit += hi - lo
        d += timedelta(days=1)
    return round(100 * lit / (b - a))


def kpis(o: dict, airports: dict) -> dict:
    """{"km", "eur_km", "eur_h", "sun"} for a published offer; missing parts are left out."""
    out: dict = {}
    origin, dest = airports.get(o["origin"], {}), airports.get(o["destination"], {})
    km = distance_km(origin, dest)
    if km and km > 50:
        out["km"] = round(km)
        out["eur_km"] = round(o["price"] / km, 3)
    if o.get("useful_hours"):
        out["eur_h"] = round(o["price"] / o["useful_hours"], 2)
    out_leg, in_leg = o.get("outbound") or {}, o.get("inbound") or {}
    try:
        arrive = datetime.fromisoformat(out_leg["arrival"][:16])
        leave = datetime.fromisoformat(in_leg["departure"][:16])
    except (KeyError, TypeError, ValueError):
        return out
    sun = sun_share(arrive, leave, dest)
    if sun is not None:
        out["sun"] = sun
    return out
