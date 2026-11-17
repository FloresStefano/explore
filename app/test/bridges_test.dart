import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weekend_break/screens/calendar.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  final cal = {
    'bridges': [
      {'out': '2026-12-24', 'ret': '2026-12-27', 'leave_days': 0, 'holidays': ['Natale']},
      {'out': '2026-12-24', 'ret': '2026-12-29', 'leave_days': 2, 'holidays': ['Natale', 'Vacanze di Natale (scuole)']},
      {'out': '2026-12-04', 'ret': '2026-12-08', 'leave_days': 1, 'holidays': ["Ponte dell'Immacolata (scuole)", 'Immacolata']},
      {'out': '2027-02-05', 'ret': '2027-02-08', 'leave_days': 1, 'holidays': ['Carnevale (scuole)'], 'needs_parent_leave': true},
    ],
    'marks': {
      '2026-12-08': {'kind': 'festivita'},
      '2026-12-25': {'kind': 'festivita'},
    },
  };

  test('one bridge per holiday, the one with fewest leave days', () {
    final b = Bridge.main(cal);
    expect(b.map((x) => x.name), ['Immacolata', 'Natale', 'Carnevale']);
    expect(b[1].days, 4); // 24-27 dicembre, senza ferie
    expect(b[0].period, '4 – 8 dicembre');
    expect(b[2].parentLeave, isTrue);
  });

  test('offers around the bridge that include a holiday', () {
    final immacolata = Bridge.main(cal).first;
    Map<String, dynamic> o(String a, String b) => {'out_date': a, 'ret_date': b, 'price': 50};
    final found = immacolata.offersIn([
      o('2026-12-05', '2026-12-08'), // inside, includes the 8th
      o('2026-12-03', '2026-12-06'), // a day early but no holiday inside
      o('2026-12-06', '2026-12-09'), // one day of margin, includes the 8th
      o('2026-12-12', '2026-12-14'), // another weekend
    ], cal['marks'] as Map<String, dynamic>);
    expect(found.length, 2);
  });
}
