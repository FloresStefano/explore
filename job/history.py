"""Storico prezzi (sezione 8): tutte le osservazioni, non solo le migliori.

Raw archive: archive/observations/<ORIG>-<DEST>.csv, one row per observation day,
route and date pair, keeping the day's minimum. The client gets a derived JSON.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

FIELDS = ["observed", "out", "ret", "nights", "window", "price", "source", "selected"]


class History:
    def __init__(self, root: Path):
        self.root = root
        self._cache: dict[str, dict[tuple, dict]] = {}
        self.touched: set[str] = set()

    def _load(self, route: str) -> dict[tuple, dict]:
        if route not in self._cache:
            rows: dict[tuple, dict] = {}
            p = self.root / f"{route}.csv"
            if p.exists():
                with p.open(newline="", encoding="utf-8") as f:
                    for r in csv.DictReader(f):
                        rows[(r["observed"], r["out"], r["ret"])] = r
            self._cache[route] = rows
        return self._cache[route]

    def add(self, route: str, observed: str, out: str, ret: str, nights: int, window: str, price: float,
            source: str, selected: bool) -> None:
        rows = self._load(route)
        key = (observed, out, ret)
        old = rows.get(key)
        if old and float(old["price"]) <= price:
            return
        rows[key] = {"observed": observed, "out": out, "ret": ret, "nights": str(nights), "window": window,
                     "price": f"{price:.2f}", "source": source, "selected": "1" if selected else "0"}
        self.touched.add(route)

    def rows(self, route: str) -> list[dict]:
        return sorted(self._load(route).values(), key=lambda r: (r["observed"], r["out"], r["ret"]))

    def save(self) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        for route in self.touched:
            with (self.root / f"{route}.csv").open("w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
                w.writeheader()
                w.writerows(self.rows(route))

    def publish(self, out_dir: Path) -> None:
        """data/history/<route>.json for the Statistics charts (only routes touched today)."""
        out_dir.mkdir(parents=True, exist_ok=True)
        for route in self.touched:
            obs = [[r["observed"], r["out"], r["ret"], float(r["price"]), r["window"]] for r in self.rows(route)]
            payload = {"route": route, "fields": ["observed", "out", "ret", "price", "window"], "observations": obs}
            (out_dir / f"{route}.json").write_text(json.dumps(payload, separators=(",", ":")), "utf-8")
