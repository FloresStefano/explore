# Prova fonti: github 20261116T173802Z

Weekend di prova: 2026-12-11 → 2026-12-13  
Rete: {'region': 'Virginia', 'country': 'US', 'org': 'AS8075 Microsoft Corporation'}

| Prova | Esito | Dettagli |
| --- | --- | --- |
| ryanair_anywhere_VRN | ✅ 0.18s | destinations=8 |
| ryanair_anywhere_BGY | ✅ 0.2s | destinations=59 |
| ryanair_anywhere_TSF | ✅ 0.14s | destinations=18 |
| ryanair_routes_VRN | ✅ 0.37s | routes=19 |
| skiplagged_anywhere_VRN | ✅ 0.53s | destinations=10 |
| skiplagged_route_VRN → PMO | ✅ 6.09s | flights=1, airlines=['Ryanair'] |
| skiplagged_route_VRN → CTA | ✅ 6.57s | flights=3, airlines=['Ryanair', 'Volotea Airlines', 'Wizz Air Malta'], non_ryanair=['Volotea Airlines', 'Wizz Air Malta'] |
| skiplagged_route_VRN → NAP | ✅ 1.57s | flights=0 |
| skiplagged_route_VRN → BRI | ✅ 8.68s | flights=2, airlines=['Ryanair'] |
| skiplagged_route_VRN → CAG | ✅ 6.43s | flights=1, airlines=['Ryanair'] |
| skiplagged_route_VRN → OLB | ✅ 7.54s | flights=0 |
| google_flights_VRN → PMO | ✅ 0.77s | direct=1, airlines=['Ryanair'], min_price=46 |
| google_flights_VRN → CTA | ❌ | FlightsNotFound: no flights found; received error |
| google_flights_VRN → NAP | ✅ 0.59s | direct=0 |
| google_flights_VRN → BRI | ✅ 0.49s | direct=2, airlines=['Ryanair'], min_price=43 |
| google_flights_VRN → CAG | ✅ 0.35s | direct=1, airlines=['Ryanair'], min_price=59 |
| google_flights_VRN → OLB | ✅ 0.46s | direct=0 |
| google_flights_VRN → BCN | ✅ 0.57s | direct=0 |
| google_flights_VRN → TIA | ✅ 0.73s | direct=3, airlines=['Ryanair', 'Wizz Air'], non_ryanair=['Wizz Air'], min_price=32 |
| google_flights_VRN → LGW | ❌ | FlightsNotFound: no flights found; received error |
| google_flights_VRN → CDG | ✅ 0.49s | direct=0 |
