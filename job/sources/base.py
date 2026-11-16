"""Interfaccia comune degli adattatori (sezione 6).

Every source returns the same Offer record. A failing adapter raises; the job
catches it, records it in meta.json and goes on with the other sources.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date

from ..model import Offer


class Source(ABC):
    name: str = ""

    def __init__(self, market: str, currency: str, language: str, country: str):
        # Market and currency are always explicit: the runners are not in Italy.
        self.market = market
        self.currency = currency
        self.language = language
        self.country = country


class AnywhereSource(Source):
    """'From one airport to anywhere' for a date pair."""

    @abstractmethod
    def anywhere(self, origin: str, out: date, ret: date, observed_at: str) -> list[Offer]: ...


class RouteSource(Source):
    """Prices and times for one route and date pair."""

    @abstractmethod
    def route(self, origin: str, destination: str, out: date, ret: date, observed_at: str) -> list[Offer]: ...
