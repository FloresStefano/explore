import 'package:flutter_test/flutter_test.dart';
import 'package:weekend_break/screens/days.dart';

void main() {
  Map<String, dynamic> o(String a, String b, num p) => {'out_date': a, 'ret_date': b, 'price': p};
  final offers = [o('2026-12-04', '2026-12-06', 40), o('2026-12-05', '2026-12-08', 30)];

  test('each day gets the lowest price of the trips that include it', () {
    final p = minPriceByDay(offers);
    expect(p['2026-12-04'], 40);
    expect(p['2026-12-05'], 30); // both trips include it
    expect(p['2026-12-08'], 30);
    expect(p['2026-12-09'], isNull);
  });

  test('a day opens the trips that include it', () {
    expect(offersOn(offers, DateTime(2026, 12, 6)).length, 2);
    expect(offersOn(offers, DateTime(2026, 12, 7)).length, 1);
  });
}
