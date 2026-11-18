"""Kiwi.com via its public MCP server (https://mcp.kiwi.com), called as plain HTTP.

No key. One tool, search-flight: up to 15 itineraries per call, with date ranges,
nights, airline filters and exact times. Used for the carriers the Ryanair adapter
does not see (Volotea, Wizz Air, easyJet, Aeroitalia...): Ryanair's group is always
excluded, its exact prices come from the Ryanair adapter.

Prices are Kiwi.com's for one adult without bags; on the airline's own site the
same flights usually cost a little less, so they are shown as indicative.
"""

from __future__ import annotations

import json
from datetime import date, datetime
from itertools import count

from .. import net
from ..model import Leg, Offer
from .base import Source

URL = "https://mcp.kiwi.com"
# Ryanair, Ryanair UK, Malta Air, Buzz, Lauda Europe: covered by the Ryanair adapter.
RYANAIR_GROUP = "FR,RK,AL,RR,LW"
REGIONS = ("Europe", "Africa", "Asia")
_ids = count(1)


def _d(x: date) -> str:
    return x.strftime("%d/%m/%Y")


def call(arguments: dict, timeout: float = 120) -> dict:
    """One JSON-RPC tools/call of search-flight; the server answers with a single SSE message."""
    raw = net.request(URL, body={"jsonrpc": "2.0", "id": next(_ids), "method": "tools/call",
                                 "params": {"name": "search-flight", "arguments": arguments}},
                      headers={"Accept": "application/json, text/event-stream"}, timeout=timeout, retries=1).decode()
    payload = raw
    if "data:" in raw:
        payload = "\n".join(line[5:].strip() for line in raw.splitlines() if line.startswith("data:"))
    msg = json.loads(payload)
    if "error" in msg:
        raise RuntimeError(f"kiwi: {msg['error']}")
    result = msg["result"]
    if result.get("isError"):
        raise RuntimeError(f"kiwi: {json.dumps(result.get('content'))[:300]}")
    data = result.get("structuredContent")
    if data is None:
        data = json.loads(result["content"][0]["text"])
    return data


def _leg(leg: dict) -> Leg | None:
    """A direct leg, or None when it has stops or misses times."""
    segs = leg.get("segments") or []
    if leg.get("stops") or len(segs) != 1:
        return None
    s = segs[0]
    try:
        dep = datetime.fromisoformat(leg["departureTime"][:16])
        arr = datetime.fromisoformat(leg["arrivalTime"][:16])
    except (KeyError, TypeError, ValueError):
        return None
    carrier, number = str(s.get("carrier") or ""), str(s.get("flightNumber") or "")
    flight = number if number.startswith(carrier) else f"{carrier}{number}"
    return Leg(origin=s["from"], destination=s["to"], departure=dep, arrival=arr,
               flight=flight, airline=s.get("carrierName") or s.get("carrier") or "")


class Kiwi(Source):
    name = "kiwi"

    def base_args(self) -> dict:
        return {"currency": self.currency, "locale": self.language, "adults": 1,
                "max_sector_stopovers": 0, "exclude_airlines": RYANAIR_GROUP, "sort": "price"}

    def discover(self, origin: str, region: str, first: date, last: date, nights: tuple[int, int]) -> dict[str, dict]:
        """Destinations with direct non-Ryanair round trips: code -> cheapest price and airlines."""
        data = call({**self.base_args(), "flyFrom": origin, "flyTo": region,
                     "departureDate": _d(first), "departureDateTo": _d(last),
                     "returnDate": _d(first), "returnDateTo": _d(last),
                     "nights_in_dst_from": nights[0], "nights_in_dst_to": nights[1], "one_for_city": True})
        found: dict[str, dict] = {}
        for it in data.get("itineraries") or []:
            go, back = _leg(it.get("outbound") or {}), _leg(it.get("inbound") or {})
            if not go or not back or go.origin != origin:
                continue
            cur = found.get(go.destination)
            if cur is None or it["price"] < cur["price"]:
                found[go.destination] = {"price": float(it["price"]),
                                         "airlines": sorted({go.airline, back.airline} - {""})}
        return found

    def routes(self, origin: str, dest: str, out_from: date, out_to: date, ret_from: date, ret_to: date,
               nights: tuple[int, int], observed_at: str) -> list[Offer]:
        """The cheapest direct round trips (up to 15) for departures and returns in these ranges."""
        data = call({**self.base_args(), "flyFrom": origin, "flyTo": dest,
                     "departureDate": _d(out_from), "departureDateTo": _d(out_to),
                     "returnDate": _d(ret_from), "returnDateTo": _d(ret_to),
                     "nights_in_dst_from": nights[0], "nights_in_dst_to": nights[1]})
        offers = []
        for it in data.get("itineraries") or []:
            go, back = _leg(it.get("outbound") or {}), _leg(it.get("inbound") or {})
            price = it.get("price")
            if not go or not back or price is None or go.origin != origin or go.destination != dest:
                continue
            offers.append(Offer(
                origin=origin, destination=dest,
                out_date=go.departure.date().isoformat(), ret_date=back.departure.date().isoformat(),
                price=round(float(price), 2), currency=data.get("currency") or self.currency,
                source=self.name, observed_at=observed_at, link=it.get("bookingUrl") or "",
                outbound=go, inbound=back, airlines=list(dict.fromkeys(x for x in (go.airline, back.airline) if x)),
                fare="tariffa minima Kiwi.com, prezzo indicativo",
            ))
        return offers
