import re
import unittest
from datetime import date, datetime

from job.calendar_it import Calendar, classify, easter, windows
from job.model import Leg, Offer
from job.selection import discard_reason, trip_of, useful_hours
from job.settings import ROOT, load

S = load()
CAL = Calendar.for_context("Verona")


def trip(out, ret, dep=None, land=None):
    return classify(S, CAL, date.fromisoformat(out), date.fromisoformat(ret),
                    datetime.fromisoformat(dep) if dep else None, datetime.fromisoformat(land) if land else None)


def offer(out_dep, out_arr, ret_dep, ret_arr, out="2026-12-11", ret="2026-12-13", ret_to="VRN"):
    return Offer(origin="VRN", destination="BCN", out_date=out, ret_date=ret, price=50, currency="EUR",
                 source="test", observed_at="2026-11-16", link="",
                 outbound=Leg("VRN", "BCN", datetime.fromisoformat(out_dep), datetime.fromisoformat(out_arr)),
                 inbound=Leg("BCN", ret_to, datetime.fromisoformat(ret_dep), datetime.fromisoformat(ret_arr)))


class CalendarTest(unittest.TestCase):
    def test_easter(self):
        self.assertEqual(easter(2026), date(2026, 4, 5))
        self.assertEqual(easter(2027), date(2027, 3, 28))

    def test_school_closures_loaded(self):
        self.assertIn(date(2027, 2, 9), CAL.school)  # Carnevale, DGR Veneto 712/2026
        self.assertTrue(CAL.is_workday(date(2027, 2, 9)))  # still a working day for parents


class BreakKindTest(unittest.TestCase):
    """Section 2 of the user's rules: weekend, weekend+, ponte."""

    def test_weekend_needs_evening_departure(self):
        self.assertEqual(trip("2026-12-11", "2026-12-13", "2026-12-11T19:00", "2026-12-13T21:00").kind, "weekend")
        t = trip("2026-12-11", "2026-12-13", "2026-12-11T10:00", "2026-12-13T21:00")
        self.assertEqual((t.kind, t.leave), ("weekend+", 1))

    def test_weekend_one_night(self):
        self.assertEqual(trip("2026-12-12", "2026-12-13").kind, "weekend")
        self.assertEqual(trip("2026-12-11", "2026-12-12").kind, "weekend")

    def test_weekend_plus(self):
        self.assertEqual(trip("2026-12-10", "2026-12-13", "2026-12-10T19:00").kind, "weekend+")  # Thu evening
        self.assertEqual(trip("2026-12-12", "2026-12-14").kind, "weekend+")  # Sat-Mon
        self.assertIsNone(trip("2026-12-10", "2026-12-13", "2026-12-10T09:00").kind)  # Thu + Fri leave

    def test_landing_after_midnight_costs_the_day(self):
        t = trip("2026-12-11", "2026-12-13", "2026-12-11T19:00", "2026-12-14T00:35")
        self.assertEqual((t.kind, t.leave), ("weekend+", 1))

    def test_ponte(self):
        t = trip("2026-12-05", "2026-12-08")  # Sat - Tue Immacolata
        self.assertEqual((t.kind, t.leave), ("ponte", 1))
        self.assertIn("Immacolata", t.holidays)
        self.assertEqual(trip("2027-05-20", "2027-05-23").kind, "ponte")  # San Zeno, Friday

    def test_ponte_beats_weekend(self):
        t = trip("2026-12-26", "2026-12-28")  # Sat - Mon in school holidays
        self.assertEqual(t.kind, "ponte")

    def test_school_only_ponte_needs_parent_leave(self):
        t = trip("2027-02-06", "2027-02-08")  # Sat - Mon of Carnevale
        self.assertEqual(t.kind, "ponte")
        self.assertTrue(t.needs_parent_leave)

    def test_school_closure_on_evening_departure_is_not_a_bridge(self):
        self.assertEqual(trip("2027-04-30", "2027-05-02").kind, "weekend")

    def test_too_much_leave(self):
        self.assertIsNone(trip("2026-12-01", "2026-12-04").kind)  # Tue - Fri

    def test_candidate_windows(self):
        ws = {w.key: w for w in windows(S, date(2026, 12, 1), 14, CAL)}
        self.assertEqual(ws["2026-12-04_2026-12-06"].trip.kind, "weekend")
        self.assertEqual(ws["2026-12-05_2026-12-08"].trip.kind, "ponte")


class SelectionTest(unittest.TestCase):
    def test_good_offer_passes(self):
        o = offer("2026-12-11T18:00", "2026-12-11T19:45", "2026-12-13T20:00", "2026-12-13T21:45")
        self.assertIsNone(discard_reason(S, o))
        self.assertEqual(trip_of(S, CAL, o).kind, "weekend")
        # Fri: 20:45-22:00 = 1.25h, Sat 14h, Sun 08:00-18:00 = 10h -> 25.2
        self.assertEqual(useful_hours(S, o), 25.2)

    def test_early_return_discarded(self):
        o = offer("2026-12-11T18:00", "2026-12-11T19:45", "2026-12-13T06:30", "2026-12-13T08:15")
        self.assertEqual(discard_reason(S, o), "SEL-01")

    def test_landing_after_midnight_discarded(self):
        o = offer("2026-12-11T22:55", "2026-12-12T00:30", "2026-12-13T20:00", "2026-12-13T21:45")
        self.assertEqual(discard_reason(S, o), "SEL-02")

    def test_open_jaw_discarded(self):
        o = offer("2026-12-11T18:00", "2026-12-11T19:45", "2026-12-13T20:00", "2026-12-13T21:45", ret_to="BGY")
        self.assertEqual(discard_reason(S, o), "SEL-04")


class ConfigTest(unittest.TestCase):
    def test_ids_unique_and_present(self):
        ids = [e["id"] for e in S.entries]
        self.assertEqual(len(ids), len(set(ids)))
        for i in ("FIN-07", "FIN-12", "FIN-13", "JOB-08"):
            self.assertIn(i, ids)

    def test_workflow_cron_matches_job08(self):
        wf = (ROOT / ".github" / "workflows" / "daily.yml").read_text("utf-8")
        self.assertIn(f'cron: "{S["JOB-08"]}"', wf)


if __name__ == "__main__":
    unittest.main()
