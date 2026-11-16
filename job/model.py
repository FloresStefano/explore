"""Record offerta comune a tutte le fonti (sezione 10)."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime


@dataclass
class Leg:
    """One direct flight. Times are local to the airport they refer to."""

    origin: str
    destination: str
    departure: datetime
    arrival: datetime
    flight: str = ""
    airline: str = ""


@dataclass
class Offer:
    origin: str
    destination: str
    out_date: str  # YYYY-MM-DD, the date pair this offer belongs to
    ret_date: str
    price: float  # round trip, one adult, base fare without bags (SEL-05)
    currency: str
    source: str
    observed_at: str  # ISO date of the observation
    link: str
    outbound: Leg | None = None  # None when the source gives no times (e.g. Skiplagged deals)
    inbound: Leg | None = None
    stops: int = 0
    airlines: list[str] = field(default_factory=list)
    fare: str = "base, senza bagaglio"

    @property
    def has_times(self) -> bool:
        return self.outbound is not None and self.inbound is not None

    def to_json(self) -> dict:
        d = asdict(self)
        for k in ("outbound", "inbound"):
            if d[k]:
                d[k]["departure"] = self.__dict__[k].departure.isoformat(timespec="minutes")
                d[k]["arrival"] = self.__dict__[k].arrival.isoformat(timespec="minutes")
        return d
