"""Coda di priorità (sezione 6): sceglie cosa rinfrescare entro i tetti per fonte.

Unit of work: (source, airport, out date, return date). Stale units come first;
a failed unit keeps its old timestamp, so it is picked again the next day.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path

from .calendar_it import Window
from .settings import Settings


@dataclass(frozen=True)
class Unit:
    source: str
    airport: str
    window: Window

    @property
    def key(self) -> str:
        return f"{self.source}|{self.airport}|{self.window.key}"


class WorkQueue:
    def __init__(self, path: Path):
        self.path = path
        self.state: dict[str, dict] = json.loads(path.read_text("utf-8")) if path.exists() else {}

    def refresh_days(self, s: Settings, today: date, out: date) -> int:
        return s["JOB-03"] if (out - today).days <= 28 else s["JOB-04"]

    def pick(self, s: Settings, today: date, source: str, airports: list[str], pairs: list[Window],
             cap: int) -> list[Unit]:
        """Up to `cap` due units, most overdue first, nearer departures breaking ties."""
        scored = []
        for w in pairs:
            interval = self.refresh_days(s, today, w.out)
            for ap in airports:
                u = Unit(source, ap, w)
                last = self.state.get(u.key, {}).get("fetched")
                age = (today - date.fromisoformat(last)).days if last else 10_000
                if age < interval:
                    continue
                scored.append((-(age / interval), w.out, ap, u))
        scored.sort(key=lambda x: x[:3])
        return [x[3] for x in scored[:cap]]

    def done(self, u: Unit, today: date, count: int) -> None:
        self.state[u.key] = {"fetched": today.isoformat(), "count": count}

    def failed(self, u: Unit, error: str) -> None:
        entry = self.state.setdefault(u.key, {})
        entry["error"] = error[:200]

    def save(self, today: date) -> None:
        # Forget units whose departure is in the past.
        cutoff = today - timedelta(days=1)
        self.state = {k: v for k, v in self.state.items() if date.fromisoformat(k.split("|")[2][:10]) > cutoff}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self.state, indent=0, sort_keys=True), "utf-8")
