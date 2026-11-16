"""Google Flights tramite la libreria fast-flights, per singola rotta.

From European IPs Google answers with the consent page: we send the consent
cookies ourselves (FetchIntegration) instead of the library's default fetcher.
"""

from __future__ import annotations

import re
from datetime import date, datetime

from ..model import Leg, Offer
from .base import RouteSource

URL = "https://www.google.com/travel/flights"
CONSENT_COOKIES = {
    "SOCS": "CAESHAgBEhJnd3NfMjAyMzA4MTAtMF9SQzIaAmVuIAEaBgiAo_CmBg",
    "CONSENT": "YES+cb.20230810-00-p0.it+FX+000",
}
# "I prezzi sono attualmente bassi/tipici/alti". Not in the server-rendered page so far:
# kept so the field test notices if Google starts sending it.
PRICE_LEVEL = re.compile(r"(?:sono attualmente|are currently)\s+(bass|tipic|alt|low|typical|high)", re.I)


def fetch_html(origin: str, dest: str, out: date, ret: date | None, currency: str, language: str,
               country: str) -> str:
    from fast_flights import FlightQuery, Passengers, create_query
    from primp import Client

    legs = [FlightQuery(date=out.isoformat(), from_airport=origin, to_airport=dest, max_stops=0)]
    if ret:
        legs.append(FlightQuery(date=ret.isoformat(), from_airport=dest, to_airport=origin, max_stops=0))
    q = create_query(flights=legs, trip="round-trip" if ret else "one-way", currency=currency,
                     language=language, passengers=Passengers(adults=1))
    client = Client(impersonate="chrome_145", impersonate_os="macos", referer=True, cookie_store=True)
    params = q.params()
    params["gl"] = country
    res = client.get(URL, params=params, cookies=CONSENT_COOKIES)
    if res.status_code != 200:
        raise RuntimeError(f"google flights HTTP {res.status_code}")
    return res.text


def parse(html: str) -> list:
    from fast_flights.parser import parse as ff_parse

    if "<title>Prima di continuare" in html or "consent.google" in html[:5000]:
        raise RuntimeError("google flights: pagina di consenso")
    try:
        return list(ff_parse(html))
    except (TypeError, IndexError):
        return []  # the parser crashes on pages without results (no flights that day)


def price_level(html: str) -> str | None:
    m = PRICE_LEVEL.search(html)
    return m.group(1).lower() if m else None


class GoogleFlights(RouteSource):
    name = "google_flights"

    def route(self, origin: str, destination: str, out: date, ret: date, observed_at: str) -> list[Offer]:
        """Outbound options for the pair; Google prices them as part of the round trip.

        The return leg's times need a second request per outbound, which the job
        does only for candidates that survive the first selection (section 6).
        """
        html = fetch_html(origin, destination, out, ret, self.currency, self.language, self.country)
        offers = []
        for f in parse(html):
            if len(f.flights) != 1:
                continue  # SEL-03: direct only
            leg = f.flights[0]
            offers.append(Offer(
                origin=origin, destination=destination, out_date=out.isoformat(), ret_date=ret.isoformat(),
                price=float(f.price), currency=self.currency, source=self.name, observed_at=observed_at,
                link=f"https://www.google.com/travel/flights?q=Flights%20from%20{origin}%20to%20{destination}"
                     f"%20on%20{out.isoformat()}%20through%20{ret.isoformat()}",
                outbound=Leg(origin=leg.from_airport.code, destination=leg.to_airport.code,
                             departure=_dt(leg.departure), arrival=_dt(leg.arrival), airline=", ".join(f.airlines)),
                airlines=list(f.airlines),
            ))
        return offers


def _dt(x) -> datetime:
    (y, m, d), (hh, mm) = x.date, x.time
    return datetime(y, m, d, hh or 0, mm or 0)
