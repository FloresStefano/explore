"""Motore finestre (sezione 4): puro calcolo di calendario, nessuna chiamata esterna.

Three kinds of break (FIN-07..FIN-12):
- weekend:  no leave, at most FIN-07 nights, Friday departures from FIN-04 on;
- weekend+: exactly FIN-08 leave day, spent on Friday or Monday, at most FIN-09 nights;
- ponte:    contains a holiday on a weekday (national, patron or school closure),
            FIN-10..FIN-11 nights, at most FIN-03 leave days.
When a trip fits several kinds, FIN-12 sets the precedence (ponte first).
Dates alone give the candidates; the final kind and leave count are assigned to
each offer, because a daytime departure on a working day costs that day.
"""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta

from .settings import ROOT, Settings

FRI, SAT, SUN, MON = 4, 5, 6, 0


def easter(year: int) -> date:
    """Gregorian Easter Sunday (anonymous Gregorian algorithm)."""
    a = year % 19
    b, c = divmod(year, 100)
    d, e = divmod(b, 4)
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month, day = divmod(h + l - 7 * m + 114, 31)
    return date(year, month, day + 1)


def national_holidays(year: int) -> dict[date, str]:
    """Festività nazionali italiane."""
    e = easter(year)
    days = {
        date(year, 1, 1): "Capodanno",
        date(year, 1, 6): "Epifania",
        e: "Pasqua",
        e + timedelta(days=1): "Lunedì dell'Angelo",
        date(year, 4, 25): "Festa della Liberazione",
        date(year, 5, 1): "Festa dei Lavoratori",
        date(year, 6, 2): "Festa della Repubblica",
        date(year, 8, 15): "Ferragosto",
        date(year, 11, 1): "Ognissanti",
        date(year, 12, 8): "Immacolata",
        date(year, 12, 25): "Natale",
        date(year, 12, 26): "Santo Stefano",
    }
    if year >= 2026:  # San Francesco, di nuovo festa nazionale dal 2026 (da riverificare ogni anno)
        days[date(year, 10, 4)] = "San Francesco"
    return days


def load_school(region: str) -> dict[date, str]:
    """School closures of a region from config/school/<region>.toml (FIN-05)."""
    path = ROOT / "config" / "school" / f"{region}.toml"
    if not path.exists():
        return {}
    with path.open("rb") as f:
        raw = tomllib.load(f)
    days: dict[date, str] = {}
    for c in raw.get("closure", []):
        d, end = date.fromisoformat(c["from"]), date.fromisoformat(c["to"])
        while d <= end:
            days[d] = c["name"]
            d += timedelta(days=1)
    return days


def load_patrons() -> dict[str, dict]:
    with (ROOT / "config" / "patrons.toml").open("rb") as f:
        return tomllib.load(f)


class Calendar:
    """Days off and bridge qualifiers for one user context (region and patron)."""

    def __init__(self, patron: tuple[str, str] | None = None, school: dict[date, str] | None = None):
        self.patron = patron  # ("05-21", "San Zeno")
        self.school = school or {}
        self._national: dict[int, dict[date, str]] = {}

    @classmethod
    def for_context(cls, comune: str) -> "Calendar":
        p = load_patrons().get(comune, {})
        return cls((p["patron"], p["saint"]) if p.get("patron") else None, load_school(p.get("region", "")))

    def holiday(self, d: date) -> str | None:
        """National holiday or patron: a real day off."""
        if d.year not in self._national:
            self._national[d.year] = national_holidays(d.year)
        if name := self._national[d.year].get(d):
            return name
        if self.patron and d.strftime("%m-%d") == self.patron[0]:
            return self.patron[1]
        return None

    def is_workday(self, d: date) -> bool:
        return d.weekday() < 5 and self.holiday(d) is None

    def qualifier(self, d: date) -> tuple[str, bool] | None:
        """(name, is_school_only) when a weekday makes a bridge: holiday, patron or school closure."""
        if d.weekday() >= 5:
            return None
        if name := self.holiday(d):
            return name, False
        if name := self.school.get(d):
            return name, True
        return None


@dataclass
class Trip:
    """Classification of one trip: kind, leave days and why."""

    kind: str | None  # "weekend" | "weekend+" | "ponte" | None (not a valid break)
    leave: int
    leave_dates: list[date]
    nights: int
    holidays: list[str] = field(default_factory=list)
    needs_parent_leave: bool = False


def _hhmm(value: str) -> time:
    h, m = (int(x) for x in value.split(":"))
    return time(23, 59, 59) if h == 24 else time(h, m)


def classify(s: Settings, cal: Calendar, out: date, ret: date, departure: datetime | None = None,
             landing: datetime | None = None) -> Trip:
    """Kind and leave of a trip. Without flight times, assumes the evening departure (cheapest)."""
    nights = (ret - out).days
    back = landing.date() if (landing and s["FIN-13"]) else ret  # FIN-13: the landing day counts
    leave_dates = []
    if cal.is_workday(out) and departure is not None and departure.time() < _hhmm(s["FIN-04"]):
        leave_dates.append(out)
    d = out + timedelta(days=1)
    while d <= back:
        if cal.is_workday(d):
            leave_dates.append(d)
        d += timedelta(days=1)
    leave = len(leave_dates)
    stay = [out + timedelta(days=i) for i in range((back - out).days + 1)]
    weekend_day = any(d.weekday() >= SAT for d in stay)

    # A ponte joins two days off with leave: the first and the last day of the stay are a
    # weekday holiday (national, patron or school closure) at one end and a Saturday or Sunday
    # at the other. Leaving a workday after FIN-04 (18:00) counts as starting the day after.
    first = out + timedelta(days=1) if cal.is_workday(out) and out not in leave_dates else out
    ends = (first, back)
    hol_end = next((d for d in ends if cal.qualifier(d)), None)
    joins = hol_end is not None and first != back and any(d.weekday() >= SAT for d in ends if d != hol_end)
    quals = [q for d in stay if d >= first and (q := cal.qualifier(d))] if joins else []
    names = list(dict.fromkeys(q[0] for q in quals))

    kinds = {
        "ponte": joins and s["FIN-10"] <= nights <= s["FIN-11"] and leave <= s["FIN-03"],
        "weekend+": leave == s["FIN-08"] and nights <= s["FIN-09"] and weekend_day
                    and all(d.weekday() in (FRI, MON) for d in leave_dates),
        "weekend": leave == 0 and s["FIN-01"] <= nights <= s["FIN-07"] and weekend_day,
    }
    kind = next((k for k in s["FIN-12"] if kinds.get(k)), None)
    if not s["FIN-01"] <= nights <= s["FIN-02"]:
        kind = None
    # The holiday end is only a school closure: parents still need leave for it.
    parent = kind == "ponte" and cal.qualifier(hol_end)[1]
    return Trip(kind, leave, leave_dates, nights, names if kind == "ponte" else [], parent)


@dataclass
class Window:
    out: date
    ret: date
    trip: Trip

    @property
    def nights(self) -> int:
        return self.trip.nights

    @property
    def key(self) -> str:
        return f"{self.out.isoformat()}_{self.ret.isoformat()}"

    def to_json(self) -> dict:
        return {
            "out": self.out.isoformat(), "ret": self.ret.isoformat(), "nights": self.trip.nights,
            "type": self.trip.kind, "leave_days": self.trip.leave,
            "leave_dates": [d.isoformat() for d in self.trip.leave_dates],
            "holidays": self.trip.holidays, "needs_parent_leave": self.trip.needs_parent_leave,
        }


def windows(s: Settings, start: date, days: int, cal: Calendar) -> list[Window]:
    """All candidate windows departing in [start, start+days), dates only (evening departure)."""
    result = []
    for i in range(days):
        out = start + timedelta(days=i)
        for nights in range(s["FIN-01"], s["FIN-02"] + 1):
            ret = out + timedelta(days=nights)
            trip = classify(s, cal, out, ret)
            if trip.kind:
                result.append(Window(out, ret, trip))
    return result


def search_pairs(s: Settings, today: date, cal: Calendar) -> list[Window]:
    """Date pairs the job searches offers for: candidate windows within JOB-01."""
    return windows(s, today + timedelta(days=1), s["JOB-01"], cal)


def bridges(s: Settings, start: date, days: int, cal: Calendar) -> list[dict]:
    """For each bridge-making day, the cheapest ponte around it (fewest leave days, then longest)."""
    ponti = [w for w in windows(s, start, days, cal) if w.trip.kind == "ponte"]
    best: dict[str, Window] = {}
    for w in ponti:
        for i in range(w.nights + 1):
            d = w.out + timedelta(days=i)
            if not cal.qualifier(d):
                continue
            cur = best.get(d.isoformat())
            if cur is None or (w.trip.leave, -w.nights) < (cur.trip.leave, -cur.nights):
                best[d.isoformat()] = w
    unique = {w.key: w for w in best.values()}
    return [w.to_json() for w in sorted(unique.values(), key=lambda w: w.out)]


def day_marks(start: date, days: int, cal: Calendar) -> dict[str, dict]:
    """Holidays, patron and school closures in the horizon, for the calendar grid."""
    marks = {}
    for i in range(days):
        d = start + timedelta(days=i)
        if name := cal.holiday(d):
            marks[d.isoformat()] = {"kind": "festivita", "name": name}
        elif name := cal.school.get(d):
            marks[d.isoformat()] = {"kind": "scuola", "name": name}
    return marks
