"""Registro impostazioni: legge config/settings.toml.

Nessuna soglia è scritta nel codice: tutto passa da qui.
"""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from datetime import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SETTINGS_FILE = ROOT / "config" / "settings.toml"


def parse_hhmm(value: str) -> time:
    """'07:00' -> time(7, 0). '24:00' is accepted as end of day."""
    h, m = (int(x) for x in value.split(":"))
    if h == 24 and m == 0:
        return time(23, 59, 59)
    return time(h, m)


@dataclass(frozen=True)
class Settings:
    entries: list[dict[str, Any]]
    job: dict[str, Any]

    def __getitem__(self, setting_id: str) -> Any:
        for e in self.entries:
            if e["id"] == setting_id:
                return e["value"]
        raise KeyError(setting_id)

    def time(self, setting_id: str) -> time:
        return parse_hhmm(self[setting_id])

    def cap(self, source: str) -> int:
        """JOB-06: daily call cap for a source (0 = source off)."""
        return int(self["JOB-06"].get(source, 0))

    def published(self) -> dict[str, Any]:
        """Shape of data/settings.json read by the app's settings page."""
        return {"settings": self.entries, "job": {k: self.job[k] for k in ("airports", "regions", "currency")}}


def load(path: Path = SETTINGS_FILE) -> Settings:
    with path.open("rb") as f:
        raw = tomllib.load(f)
    entries = raw["setting"]
    ids = [e["id"] for e in entries]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        raise ValueError(f"ID duplicati nel registro: {sorted(dupes)}")
    return Settings(entries=entries, job=raw["job"])
