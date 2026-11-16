"""Motore finestre (sezione 4): puro calcolo di calendario, nessuna chiamata esterna."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta

from .settings import Settings


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


class Calendar:
    """Working days for one user context: national holidays plus optional extras (patron)."""

    def __init__(self, extra: dict[date, str] | None = None):
        self._cache: dict[int, dict[date, str]] = {}
        self.extra = extra or {}

    def holiday(self, d: date) -> str | None:
        if d.year not in self._cache:
            self._cache[d.year] = national_holidays(d.year)
        return self._cache[d.year].get(d) or self.extra.get(d)

    def is_workday(self, d: date) -> bool:
        return d.weekday() < 5 and self.holiday(d) is None


def leave_days(cal: Calendar, out: date, ret: date) -> int:
    """Giorni di ferie per una coppia di date, assumendo partenza serale (FIN-04).

    Departure day is free if the flight leaves after FIN-04; every workday after it,
    return day included, costs a full day. The offer adds half a day when the actual
    outbound flight leaves earlier (see selection.leave_days_for_offer).
    """
    return sum(cal.is_workday(out + timedelta(days=i)) for i in range(1, (ret - out).days + 1))


@dataclass
class Window:
    out: date
    ret: date
    nights: int
    leave_days: int
    reason: str  # weekend | festivita | ponte | chiusura_scolastica | patrono
    holidays: list[str] = field(default_factory=list)
    needs_parent_leave: bool = False

    @property
    def key(self) -> str:
        return f"{self.out.isoformat()}_{self.ret.isoformat()}"

    def to_json(self) -> dict:
        return {
            "out": self.out.isoformat(),
            "ret": self.ret.isoformat(),
            "nights": self.nights,
            "leave_days": self.leave_days,
            "reason": self.reason,
            "holidays": self.holidays,
            "needs_parent_leave": self.needs_parent_leave,
        }


def windows(s: Settings, start: date, days: int, cal: Calendar | None = None) -> list[Window]:
    """All valid break windows starting in [start, start+days).

    Valid: FIN-01..FIN-02 nights, at most FIN-03 leave days, and the stay touches at
    least one non-working day (weekend or holiday), so it is a weekend or a bridge.
    """
    cal = cal or Calendar()
    lo, hi, max_leave = s["FIN-01"], s["FIN-02"], s["FIN-03"]
    result: list[Window] = []
    for i in range(days):
        out = start + timedelta(days=i)
        for nights in range(lo, hi + 1):
            ret = out + timedelta(days=nights)
            stay = [out + timedelta(days=k) for k in range(nights + 1)]
            free = [d for d in stay if not cal.is_workday(d)]
            if not free:
                continue
            cost = leave_days(cal, out, ret)
            if cost > max_leave:
                continue
            names = sorted({h for d in stay if (h := cal.holiday(d))})
            if cost == 0:
                reason = "festivita" if names else "weekend"
            else:
                reason = "ponte"
            result.append(Window(out, ret, nights, cost, reason, names))
    return result


def search_pairs(s: Settings, today: date) -> list[Window]:
    """Date pairs the job searches offers for: national windows within JOB-01.

    A local patron day only lowers the leave cost of pairs, so nearly every local
    window is already here (except a bridge resting only on the patron day).
    """
    return windows(s, today + timedelta(days=1), s["JOB-01"])
