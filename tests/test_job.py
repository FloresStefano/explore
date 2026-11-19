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

    def test_ponte_joins_holiday_and_weekend(self):
        # Holiday at one end, weekend at the other: Fri 25 Dec (evening departure the day before) - Sun 27.
        t = trip("2026-12-24", "2026-12-27", "2026-12-24T19:00")
        self.assertEqual((t.kind, t.leave), ("ponte", 0))
        # Holiday only in the middle: Sat 5 - Wed 9 Dec ends on a workday, not a ponte.
        self.assertNotEqual(trip("2026-12-05", "2026-12-09").kind, "ponte")
        # Leaving Fri 4 Dec in the morning: the stay starts on a workday, not a ponte.
        self.assertIsNone(trip("2026-12-04", "2026-12-08", "2026-12-04T10:00").kind)
        # Leaving Fri 4 Dec after 18:00 counts as starting on Saturday: ponte with Monday's leave.
        t = trip("2026-12-04", "2026-12-08", "2026-12-04T19:30", "2026-12-08T22:00")
        self.assertEqual((t.kind, t.leave), ("ponte", 1))

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

    def test_short_stay_discarded(self):
        # Sat evening - Sun midday, one night: 21:45-22:00 + 08:00-10:45 = 3 useful hours.
        o = offer("2026-12-12T19:00", "2026-12-12T20:45", "2026-12-13T12:45", "2026-12-13T14:30",
                  out="2026-12-12")
        self.assertLess(useful_hours(S, o), S["SEL-08"])
        self.assertEqual(discard_reason(S, o), "SEL-08")

    def test_price_cap(self):
        o = offer("2026-12-11T18:00", "2026-12-11T19:45", "2026-12-13T20:00", "2026-12-13T21:45")
        o.price = S["JOB-09"]
        self.assertIsNone(discard_reason(S, o))  # exactly at the cap is kept
        o.price = S["JOB-09"] + 0.01
        self.assertEqual(discard_reason(S, o), "JOB-09")


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


class CrazyTest(unittest.TestCase):
    def test_texts_cover_every_airport_combination(self):
        from job import crazy

        def o(origin, out, price, kind="weekend"):
            return {"origin": origin, "destination": "BCN", "out_date": out, "ret_date": out, "price": price, "type": kind}

        offers = [o("BGY", f"2026-12-{d:02d}", 40) for d in range(1, 31)]  # 30 from Bergamo
        offers += [o("VRN", "2026-12-31", 30), o("TSF", "2026-12-31", 60), o("TSF", "2026-12-30", 20, "ponte")]
        ids = {crazy.offer_id(x) for x in crazy.needed(offers, ["VRN", "BGY", "TSF"])}
        self.assertIn("VRN-BCN-2026-12-31-2026-12-31", ids)  # top of the Verona-only ranking
        self.assertEqual(len(ids), 32)  # the ponte has its own ranking; over 50 euro never appears
        self.assertIn("TSF-BCN-2026-12-30-2026-12-30", ids)
        self.assertNotIn("TSF-BCN-2026-12-31-2026-12-31", ids)

    def test_request_has_times_and_net_hours(self):
        from job import crazy
        o = {"origin": "VRN", "destination": "BCN", "city": "Barcellona", "out_date": "2026-12-04",
             "ret_date": "2026-12-06", "price": 39.98, "useful_hours": 25.2,
             "outbound": {"departure": "2026-12-04T19:10+01:00", "arrival": "2026-12-04T21:00+01:00"},
             "inbound": {"departure": "2026-12-06T20:40+01:00", "arrival": "2026-12-06T22:30+01:00"}}
        r = crazy.request_item(o)
        self.assertEqual((r["from"], r["dep"], r["arr"], r["hours"]), ("Verona", "19:10", "22:30", 25.2))
        self.assertEqual(crazy.request_item({**o, "outbound": None})["dep"], "")
        # Texts written by an older version are not reused.
        prev = {"items": {crazy.offer_id(o): {"title": "t", "text": "x"}}}
        res = crazy.publish([], ["VRN"], prev, "http://unused", [])
        self.assertEqual((res["version"], res["items"]), (crazy.VERSION, {}))


class KiwiTest(unittest.TestCase):
    def test_week_blocks_cover_every_pair_once(self):
        from job.calendar_it import search_pairs
        from job.run import week_blocks
        pairs = search_pairs(S, date(2026, 11, 18), CAL)
        blocks = week_blocks(pairs)
        covered = [w.key for _, ws in blocks.values() for w in ws]
        self.assertEqual(sorted(covered), sorted(w.key for w in pairs))
        for rep, ws in blocks.values():
            self.assertEqual(rep, ws[0])
            self.assertEqual(len({w.out.isocalendar()[:2] for w in ws}), 1)

    def test_routes_keep_direct_round_trips_only(self):
        from unittest import mock
        from job.sources import kiwi

        def leg(a, b, dep, arr, stops=0, carrier="V7"):
            segs = [{"from": a, "to": b, "carrier": carrier, "carrierName": "Volotea", "flightNumber": f"{carrier}1414"}]
            return {"route": [a, b], "departureTime": dep, "arrivalTime": arr, "stops": stops,
                    "segments": segs if not stops else segs * 2}

        data = {"currency": "EUR", "itineraries": [
            {"price": 57, "bookingUrl": "https://kiwi.com/u/x",
             "outbound": leg("VRN", "BCN", "2026-12-11T19:00:00", "2026-12-11T20:45:00"),
             "inbound": leg("BCN", "VRN", "2026-12-13T20:00:00", "2026-12-13T21:45:00")},
            {"price": 40, "outbound": leg("VRN", "BCN", "2026-12-11T07:00:00", "2026-12-11T12:00:00", stops=1),
             "inbound": leg("BCN", "VRN", "2026-12-13T20:00:00", "2026-12-13T21:45:00")},
        ]}
        k = kiwi.Kiwi(market="it-it", currency="EUR", language="it", country="IT")
        with mock.patch.object(kiwi, "call", return_value=data) as call:
            offers = k.routes("VRN", "BCN", date(2026, 12, 9), date(2026, 12, 12), date(2026, 12, 10),
                              date(2026, 12, 15), (1, 5), "2026-11-18")
        self.assertIn("FR", call.call_args[0][0]["exclude_airlines"])
        self.assertEqual(len(offers), 1)  # the one with a stop is dropped
        o = offers[0]
        self.assertEqual((o.out_date, o.ret_date, o.price, o.airlines), ("2026-12-11", "2026-12-13", 57.0, ["Volotea"]))
        self.assertEqual(o.outbound.flight, "V71414")
        self.assertIsNone(discard_reason(S, o))
        self.assertEqual(trip_of(S, CAL, o).kind, "weekend")


class KpiTest(unittest.TestCase):
    def test_three_indicators(self):
        from job import kpi
        airports = {"VRN": {"lat": 45.3957, "lon": 10.8885, "tz": "Europe/Rome"},
                    "BCN": {"lat": 41.2971, "lon": 2.0785, "tz": "Europe/Madrid"}}
        o = {"origin": "VRN", "destination": "BCN", "price": 50, "useful_hours": 25,
             "outbound": {"arrival": "2026-12-11T20:00+01:00"}, "inbound": {"departure": "2026-12-13T20:00+01:00"}}
        k = kpi.kpis(o, airports)
        self.assertTrue(820 < k["km"] < 870)  # Verona - Barcelona, about 845 km
        self.assertAlmostEqual(k["eur_km"], 50 / k["km"], places=3)
        self.assertEqual(k["eur_h"], 2.0)
        # 48 hours in December Barcelona: two days of about 9 hours of light.
        self.assertTrue(35 <= k["sun"] <= 40, k["sun"])

    def test_country_zone_when_the_airport_has_none(self):
        from job import kpi
        place = {"lat": 41.4147, "lon": 19.7206, "country_code": "al"}  # Tirana, no tz
        self.assertIsNotNone(kpi.sun_share(datetime(2026, 12, 12, 8), datetime(2026, 12, 12, 20), place))
