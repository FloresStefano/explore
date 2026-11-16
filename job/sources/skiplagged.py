"""Skiplagged via MCP pubblico (https://mcp.skiplagged.com/mcp), chiamato come normale HTTP.

No auth. "Anywhere" deals give price but no times; sk_flights_search gives times.
Prices are converted from USD by Skiplagged and are approximate.
"""

from __future__ import annotations

import json
from datetime import date, datetime
from itertools import count

from .. import net
from ..model import Leg, Offer
from .base import AnywhereSource

URL = "https://mcp.skiplagged.com/mcp"
_ids = count(1)


def call_tool(name: str, arguments: dict, timeout: float = 60) -> dict:
    """One JSON-RPC tools/call; the server answers with a single SSE message."""
    raw = net.request(URL, body={"jsonrpc": "2.0", "id": next(_ids), "method": "tools/call",
                                 "params": {"name": name, "arguments": arguments}},
                      headers={"Accept": "application/json, text/event-stream"}, timeout=timeout).decode()
    payload = raw
    if "data:" in raw:
        payload = "\n".join(line[5:].strip() for line in raw.splitlines() if line.startswith("data:"))
    msg = json.loads(payload)
    if "error" in msg:
        raise RuntimeError(f"skiplagged {name}: {msg['error']}")
    result = msg["result"]
    if result.get("isError"):
        raise RuntimeError(f"skiplagged {name}: {json.dumps(result.get('content'))[:300]}")
    return result.get("structuredContent") or {}


class Skiplagged(AnywhereSource):
    name = "skiplagged"

    def anywhere(self, origin: str, out: date, ret: date, observed_at: str) -> list[Offer]:
        data = call_tool("sk_destinations_anywhere", {
            "from": origin, "depart": out.isoformat(), "return": ret.isoformat(),
            "currency": self.currency, "adults": 1,
        })
        offers = []
        for r in data.get("results") or []:
            dest = (r.get("destination") or {}).get("airport")
            price = (r.get("price") or {}).get("amount")
            if not dest or price is None or r.get("flightType", "Standard") != "Standard":
                continue  # skip hidden-city / interlining tricks
            offers.append(Offer(
                origin=origin, destination=dest, out_date=out.isoformat(), ret_date=ret.isoformat(),
                price=round(float(price), 2), currency=self.currency, source=self.name,
                observed_at=observed_at, link=_clean_link(r.get("deepLink") or ""),
                stops=-1,  # unknown until a route search confirms it is direct
            ))
        return offers

    def flights(self, origin: str, dest: str, out: date, ret: date | None = None, limit: int = 20) -> dict:
        args = {"origin": origin, "destination": dest, "departureDate": out.isoformat(), "currency": self.currency,
                "maxStops": "none", "includeHiddenCity": False, "includeVirtualInterlining": False,
                "sort": "price", "limit": limit}
        if ret:
            args["returnDate"] = ret.isoformat()
        return call_tool("sk_flights_search", args)


def _clean_link(url: str) -> str:
    return url.split("?utm_")[0]


def leg_from_card(card: dict, airline: str = "") -> Leg:
    return Leg(origin=card["departure"]["airport"], destination=card["arrival"]["airport"],
               departure=datetime.fromisoformat(card["departure"]["dateTime"][:16]),
               arrival=datetime.fromisoformat(card["arrival"]["dateTime"][:16]), airline=airline)
