"""Ryanair: farefinder (offerte "ovunque") e viste aeroporti/rotte.

Unofficial endpoints used by ryanair.com. No key, works from datacenter IPs.
Per route and day only the cheapest fare is returned.
"""

from __future__ import annotations

from datetime import date, datetime

from .. import net
from ..model import Leg, Offer
from .base import AnywhereSource

FARES = "https://services-api.ryanair.com/farfnd/v4/roundTripFares"
AIRPORTS = "https://www.ryanair.com/api/views/locate/5/airports/{lang}/active"
ROUTES = "https://www.ryanair.com/api/views/locate/searchWidget/routes/{lang}/airport/{code}"


class Ryanair(AnywhereSource):
    name = "ryanair"

    def anywhere(self, origin: str, out: date, ret: date, observed_at: str) -> list[Offer]:
        data = net.get_json(FARES, params={
            "departureAirportIataCode": origin,
            "outboundDepartureDateFrom": out.isoformat(),
            "outboundDepartureDateTo": out.isoformat(),
            "inboundDepartureDateFrom": ret.isoformat(),
            "inboundDepartureDateTo": ret.isoformat(),
            "market": self.market,
            "adultPaxCount": 1,
            "currency": self.currency,
        })
        offers = []
        for f in data.get("fares") or []:
            o, i = f["outbound"], f["inbound"]
            dest = o["arrivalAirport"]["iataCode"]
            offers.append(Offer(
                origin=origin,
                destination=dest,
                out_date=out.isoformat(),
                ret_date=ret.isoformat(),
                price=round(float(f["summary"]["price"]["value"]), 2),
                currency=f["summary"]["price"]["currencyCode"],
                source=self.name,
                observed_at=observed_at,
                link=self.link(origin, dest, out, ret),
                outbound=_leg(o),
                inbound=_leg(i),
                airlines=["Ryanair"],
            ))
        return offers

    def link(self, origin: str, dest: str, out: date, ret: date) -> str:
        lang, country = self.market.split("-")[0], self.market.split("-")[1]
        return (f"https://www.ryanair.com/{country}/{lang}/trip/flights/select?adults=1&teens=0&children=0&infants=0"
                f"&dateOut={out.isoformat()}&dateIn={ret.isoformat()}&isReturn=true"
                f"&originIata={origin}&destinationIata={dest}")

    def airports(self) -> list[dict]:
        lang = self.market.split("-")[0]
        return net.get_json(AIRPORTS.format(lang=lang))

    def routes(self, code: str) -> list[dict]:
        lang = self.market.split("-")[0]
        return net.get_json(ROUTES.format(lang=lang, code=code))


def _leg(x: dict) -> Leg:
    return Leg(
        origin=x["departureAirport"]["iataCode"],
        destination=x["arrivalAirport"]["iataCode"],
        departure=datetime.fromisoformat(x["departureDate"]),
        arrival=datetime.fromisoformat(x["arrivalDate"]),
        flight=x.get("flightNumber") or "",
        airline="Ryanair",
    )
