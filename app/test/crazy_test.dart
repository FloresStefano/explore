import 'package:flutter_test/flutter_test.dart';
import 'package:weekend_break/screens/crazy.dart';

void main() {
  Map<String, dynamic> o(String dest, String type, String a, String b, num p) =>
      {'origin': 'BGY', 'destination': dest, 'type': type, 'out_date': a, 'ret_date': b, 'price': p};

  final catalog = [
    o('BCN', 'weekend', '2026-12-11', '2026-12-13', 45),
    o('BCN', 'weekend', '2026-12-04', '2026-12-06', 49.99),
    o('PMI', 'weekend', '2026-12-04', '2026-12-06', 50), // not under 50
    o('BCN', 'ponte', '2026-12-05', '2026-12-08', 30), // not a weekend
    o('BCN', 'weekend+', '2026-12-03', '2026-12-06', 70), // Thursday evening: extends 4-6
    o('BCN', 'weekend+', '2026-12-04', '2026-12-07', 65), // Monday: extends 4-6
    o('BCN', 'weekend+', '2026-12-10', '2026-12-13', 60), // another weekend
  ];

  test('weekends under 50 euro, nearest first', () {
    final list = crazyOffers(catalog);
    expect(list.map((x) => x['out_date']), ['2026-12-04', '2026-12-11']);
  });

  test('a weekend opens with its weekend+ extensions', () {
    final ext = crazyExtensions(catalog, catalog[1]);
    expect(ext.map((x) => '${x['type']} ${x['out_date']}'),
        ['weekend 2026-12-04', 'weekend+ 2026-12-04', 'weekend+ 2026-12-03']);
  });

  test('medie and grandi pick their own kind and open only the same trip', () {
    final cat = [
      ...catalog,
      {'origin': 'VRN', 'destination': 'BCN', 'type': 'weekend+', 'out_date': '2026-12-10', 'ret_date': '2026-12-13', 'price': 40},
      {'origin': 'BGY', 'destination': 'BCN', 'type': 'weekend+', 'out_date': '2026-12-10', 'ret_date': '2026-12-13', 'price': 45},
      {'origin': 'BGY', 'destination': 'BCN', 'type': 'weekend', 'out_date': '2026-12-11', 'ret_date': '2026-12-13', 'price': 20},
    ];
    final medie = crazyOffers(cat, 'weekend+');
    expect(medie.map((x) => x['price']), [40, 45]);
    expect(crazyOffers(cat, 'ponte').single['price'], 30);
    // Same weekend+ from both airports, no weekend and no other dates.
    expect(crazyDetail(cat, medie.first).map((x) => '${x['origin']} ${x['price']}'), ['VRN 40', 'BGY 45', 'BGY 60']);
  });
}
