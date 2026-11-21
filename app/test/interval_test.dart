import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weekend_break/screens/interval.dart';

void main() {
  Map<String, dynamic> o(String dest, String a, String b, num p) =>
      {'origin': 'VRN', 'destination': dest, 'city': dest, 'type': 'weekend', 'out_date': a, 'ret_date': b, 'price': p};

  final catalog = [
    o('BCN', '2026-12-04', '2026-12-06', 60),
    o('PMI', '2026-12-05', '2026-12-06', 40), // departure one day later
    o('LIS', '2026-12-03', '2026-12-08', 90), // one day early, two days late
    o('OPO', '2026-12-11', '2026-12-13', 20), // another weekend
  ];
  final out = DateTime(2026, 12, 4), ret = DateTime(2026, 12, 6);

  test('flexibility widens each date, cheapest first', () {
    expect(intervalMatches(catalog, out, ret, 0).map((x) => x['destination']), ['BCN']);
    expect(intervalMatches(catalog, out, ret, 1).map((x) => x['destination']), ['PMI', 'BCN']);
    expect(intervalMatches(catalog, out, ret, 2).map((x) => x['destination']), ['PMI', 'BCN', 'LIS']);
  });

  testWidgets('the card shows what fits and reacts to the flexibility', (tester) async {
    await initializeDateFormatting('it');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: IntervalCard(offers: catalog, today: DateTime(2026, 11, 30))),
    ));
    // Default: next Friday to Sunday, ± 1 day.
    expect(find.text('2 offerte'), findsOneWidget);
    await tester.tap(find.text('Esatte'));
    await tester.pump();
    expect(find.text('1 offerta'), findsOneWidget);
    await tester.tap(find.text('± 2 giorni'));
    await tester.pump();
    expect(find.text('3 offerte'), findsOneWidget);
  });
}
