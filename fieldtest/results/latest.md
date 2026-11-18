# Prova fonti: github 20261118T202930Z

Weekend di prova: 2026-12-11 → 2026-12-13  
Rete: {'region': 'Virginia', 'country': 'US', 'org': 'AS14618 Amazon.com, Inc.'}

| Prova | Esito | Dettagli |
| --- | --- | --- |
| ryanair_anywhere_VRN | ✅ 0.1s | destinations=8 |
| ryanair_anywhere_BGY | ✅ 0.24s | destinations=59 |
| ryanair_anywhere_TSF | ✅ 0.1s | destinations=18 |
| ryanair_routes_VRN | ✅ 0.06s | routes=19 |
| skiplagged_anywhere_VRN | ❌ | RuntimeError: skiplagged sk_destinations_anywhere: [{"type": "text", "text": "Failed to fetch from skipsy: Request faile |
| skiplagged_route_VRN → PMO | ❌ | RuntimeError: skiplagged sk_flights_search: [{"type": "text", "text": "Failed to fetch from search: Request failed with  |
| skiplagged_route_VRN → CTA | ❌ | RuntimeError: skiplagged sk_flights_search: [{"type": "text", "text": "Failed to fetch from search: Request failed with  |
| skiplagged_route_VRN → NAP | ❌ | RuntimeError: skiplagged sk_flights_search: [{"type": "text", "text": "Failed to fetch from search: Request failed with  |
| skiplagged_route_VRN → BRI | ❌ | RuntimeError: skiplagged sk_flights_search: [{"type": "text", "text": "Failed to fetch from search: Request failed with  |
| skiplagged_route_VRN → CAG | ❌ | RuntimeError: skiplagged sk_flights_search: [{"type": "text", "text": "Failed to fetch from search: Request failed with  |
| skiplagged_route_VRN → OLB | ❌ | RuntimeError: skiplagged sk_flights_search: [{"type": "text", "text": "Failed to fetch from search: Request failed with  |
| google_flights_VRN → PMO | ✅ 1.25s | direct=1, airlines=['Ryanair'], min_price=52 |
| google_flights_VRN → CTA | ❌ | FlightsNotFound: no flights found; received error |
| google_flights_VRN → NAP | ❌ | FlightsNotFound: no flights found; received error |
| google_flights_VRN → BRI | ✅ 0.5s | direct=2, airlines=['Ryanair'], min_price=46 |
| google_flights_VRN → CAG | ✅ 0.54s | direct=1, airlines=['Ryanair'], min_price=59 |
| google_flights_VRN → OLB | ✅ 0.47s | direct=0 |
| google_flights_VRN → BCN | ❌ | FlightsNotFound: no flights found; received error |
| google_flights_VRN → TIA | ✅ 0.33s | direct=3, airlines=['Ryanair', 'Wizz Air'], non_ryanair=['Wizz Air'], min_price=32 |
| google_flights_VRN → LGW | ✅ 0.54s | direct=4, airlines=['British Airways', 'easyJet'], non_ryanair=['easyJet'], min_price=131 |
| google_flights_VRN → CDG | ✅ 0.46s | direct=0 |
