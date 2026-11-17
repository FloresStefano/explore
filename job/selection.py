"""Selezione dei voli (sezione 7): scarti automatici, poi ore utili e prezzo per ora utile."""

from __future__ import annotations

from datetime import date, datetime, timedelta

from .calendar_it import Calendar, Trip, classify
from .model import Offer
from .settings import Settings


def _hours(value: str) -> timedelta:
    h, m = (int(x) for x in value.split(":"))
    return timedelta(hours=h, minutes=m)


def discard_reason(s: Settings, o: Offer) -> str | None:
    """ID of the first rule the offer breaks, or None if it passes.

    Offers without times (e.g. Skiplagged deals) cannot be judged and are not
    discarded here; they are never ranked either (see useful_hours).
    """
    if o.price > s["JOB-09"]:
        return "JOB-09"
    nights = (date.fromisoformat(o.ret_date) - date.fromisoformat(o.out_date)).days
    if not s["FIN-01"] <= nights <= s["FIN-02"]:
        return "FIN-01" if nights < s["FIN-01"] else "FIN-02"
    if o.stops > s["SEL-03"]:
        return "SEL-03"
    if not o.has_times:
        return None
    if s["SEL-04"] and o.inbound.destination != o.origin:
        return "SEL-04"
    if o.inbound.departure.time() < s.time("SEL-01"):
        return "SEL-01"
    landing_limit = datetime.fromisoformat(o.out_date) + _hours(s["SEL-02"])
    if o.outbound.arrival > landing_limit:
        return "SEL-02"
    return None


def trip_of(s: Settings, cal: Calendar, o: Offer) -> Trip:
    """Kind of break and leave days of this offer, from its actual flight times."""
    return classify(s, cal, date.fromisoformat(o.out_date), date.fromisoformat(o.ret_date),
                    o.outbound.departure if o.outbound else None, o.inbound.arrival if o.inbound else None)


def useful_hours(s: Settings, o: Offer) -> float:
    """Ore utili: hours between landing+margin and take-off-margin falling in the daytime band.

    Both times are local to the destination airport, as the sources report them.
    """
    if not o.has_times:
        return 0.0
    after, before = s["SEL-07"]
    start = o.outbound.arrival + timedelta(hours=after)
    end = o.inbound.departure - timedelta(hours=before)
    if end <= start:
        return 0.0
    day_from, day_to = (_hours(x) for x in s["SEL-06"])
    total = timedelta()
    d = start.date()
    while d <= end.date():
        midnight = datetime(d.year, d.month, d.day)
        lo, hi = max(start, midnight + day_from), min(end, midnight + day_to)
        if hi > lo:
            total += hi - lo
        d += timedelta(days=1)
    return round(total.total_seconds() / 3600, 1)
