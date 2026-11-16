import unittest
from datetime import date, datetime

from job.calendar_it import Calendar, easter, leave_days, windows
from job.model import Leg, Offer
from job.selection import discard_reason, offer_leave_days, useful_hours
from job.settings import load

S = load()


def offer(out_dep, out_arr, ret_dep, ret_arr, out="2026-12-11", ret="2026-12-13", ret_to="VRN"):
    return Offer(origin="VRN", destination="BCN", out_date=out, ret_date=ret, price=50, currency="EUR",
                 source="test", observed_at="2026-11-16", link="",
                 outbound=Leg("VRN", "BCN", datetime.fromisoformat(out_dep), datetime.fromisoformat(out_arr)),
                 inbound=Leg("BCN", ret_to, datetime.fromisoformat(ret_dep), datetime.fromisoformat(ret_arr)))


class CalendarTest(unittest.TestCase):
    def test_easter(self):
        self.assertEqual(easter(2026), date(2026, 4, 5))
        self.assertEqual(easter(2027), date(2027, 3, 28))

    def test_leave_days(self):
        cal = Calendar()
        self.assertEqual(leave_days(cal, date(2026, 12, 11), date(2026, 12, 13)), 0)  # Fri-Sun
        self.assertEqual(leave_days(cal, date(2026, 12, 10), date(2026, 12, 13)), 1)  # Thu-Sun
        self.assertEqual(leave_days(cal, date(2026, 12, 11), date(2026, 12, 14)), 1)  # Fri-Mon
        # Immacolata on Tue 8 Dec 2026: Sat 5 - Tue 8 costs only Monday.
        self.assertEqual(leave_days(cal, date(2026, 12, 5), date(2026, 12, 8)), 1)

    def test_patron_lowers_cost(self):
        cal = Calendar({date(2027, 5, 21): "San Zeno"})  # Friday
        self.assertEqual(leave_days(cal, date(2027, 5, 20), date(2027, 5, 23)), 0)

    def test_windows(self):
        ws = {w.key: w for w in windows(S, date(2026, 12, 1), 14)}
        self.assertEqual(ws["2026-12-04_2026-12-06"].reason, "weekend")
        self.assertEqual(ws["2026-12-05_2026-12-08"].reason, "ponte")
        self.assertIn("Immacolata", ws["2026-12-05_2026-12-08"].holidays)
        self.assertNotIn("2026-12-01_2026-12-04", ws)  # Tue-Fri: no free day, 3 leave days


class SelectionTest(unittest.TestCase):
    def test_good_offer_passes(self):
        o = offer("2026-12-11T18:00", "2026-12-11T19:45", "2026-12-13T20:00", "2026-12-13T21:45")
        self.assertIsNone(discard_reason(S, o))
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

    def test_friday_morning_costs_half_day(self):
        cal = Calendar()
        o = offer("2026-12-11T09:00", "2026-12-11T10:45", "2026-12-13T20:00", "2026-12-13T21:45")
        self.assertEqual(offer_leave_days(S, cal, o, 0), 0.5)


if __name__ == "__main__":
    unittest.main()
