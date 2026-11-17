"""Airport metadata for any destination: Ryanair's list first, OurAirports (public domain) for the rest.

Countries are named in Italian: Ryanair's names when it serves the country, a fixed
table otherwise.
"""

from __future__ import annotations

import csv
import io
from datetime import date

from . import net

OURAIRPORTS = "https://davidmegginson.github.io/ourairports-data/airports.csv"

COUNTRIES_IT = {
    "AE": "Emirati Arabi Uniti", "AL": "Albania", "AM": "Armenia", "AT": "Austria", "AZ": "Azerbaigian",
    "BA": "Bosnia ed Erzegovina", "BE": "Belgio", "BG": "Bulgaria", "BY": "Bielorussia", "CH": "Svizzera",
    "CV": "Capo Verde", "CY": "Cipro", "CZ": "Repubblica Ceca", "DE": "Germania", "DK": "Danimarca",
    "DZ": "Algeria", "EE": "Estonia", "EG": "Egitto", "ES": "Spagna", "FI": "Finlandia", "FR": "Francia",
    "GB": "Regno Unito", "GE": "Georgia", "GR": "Grecia", "HR": "Croazia", "HU": "Ungheria", "IE": "Irlanda",
    "IL": "Israele", "IS": "Islanda", "IT": "Italia", "JO": "Giordania", "KZ": "Kazakistan", "LB": "Libano",
    "LT": "Lituania", "LU": "Lussemburgo", "LV": "Lettonia", "MA": "Marocco", "MD": "Moldavia",
    "ME": "Montenegro", "MK": "Macedonia del Nord", "MT": "Malta", "NL": "Paesi Bassi", "NO": "Norvegia",
    "PL": "Polonia", "PT": "Portogallo", "QA": "Qatar", "RO": "Romania", "RS": "Serbia", "SA": "Arabia Saudita",
    "SE": "Svezia", "SI": "Slovenia", "SK": "Slovacchia", "TN": "Tunisia", "TR": "Turchia", "UA": "Ucraina",
    "US": "Stati Uniti", "UZ": "Uzbekistan", "XK": "Kosovo",
}


def ourairports() -> dict[str, dict]:
    """IATA code -> name, city, country code, coordinates (about 9.000 airports)."""
    text = net.request(OURAIRPORTS, timeout=90, headers={"Accept": "text/csv"}).decode("utf-8")
    out = {}
    for r in csv.DictReader(io.StringIO(text)):
        code = (r.get("iata_code") or "").strip()
        if len(code) != 3 or r.get("type") == "closed":
            continue
        out[code] = {"code": code, "name": r["name"], "city": r.get("municipality") or r["name"],
                     "country_code": r["iso_country"].lower(), "lat": round(float(r["latitude_deg"]), 4),
                     "lon": round(float(r["longitude_deg"]), 4)}
    return out


def complete(airports: dict[str, dict], codes: set[str], cache: dict, today: date, warnings: list) -> dict:
    """Add metadata for `codes` missing from `airports`, using (and refreshing) the OurAirports cache.

    Returns the updated cache: {"updated": iso, "airports": {...}} with only the codes we used.
    """
    names = {a["country_code"].lower(): a["country"] for a in airports.values() if a.get("country_code")}
    missing = {c for c in codes if c not in airports or "lat" not in airports[c]}
    known = cache.get("airports", {})
    if missing - known.keys():
        try:
            full = ourairports()
            known.update({c: full[c] for c in missing if c in full})
            cache = {"updated": today.isoformat(), "airports": known}
        except Exception as e:
            warnings.append(f"ourairports: {e}")
    for c in missing:
        if c in known:
            a = dict(known[c])
            cc = a["country_code"]
            a["country"] = names.get(cc) or COUNTRIES_IT.get(cc.upper()) or cc.upper()
            airports[c] = {**airports.get(c, {}), **a}
    return cache
