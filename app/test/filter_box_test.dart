import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weekend_break/common.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  testWidgets('type and month combo boxes report the chosen value', (tester) async {
    String? type;
    String? month;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Row(children: [
            Expanded(child: TypeBox(value: type, onChanged: (v) => setState(() => type = v))),
            Expanded(
                child: MonthBox(
                    months: const ['2026-11', '2026-12'], value: month, onChanged: (v) => setState(() => month = v))),
          ]),
        ),
      ),
    ));

    expect(find.text('Tutti i tipi'), findsOneWidget);
    await tester.tap(find.text('Tutti i tipi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ponti').last);
    await tester.pumpAndSettle();
    expect(type, 'ponte');
    expect(find.text('Ponti'), findsOneWidget);

    await tester.tap(find.text('Tutti i mesi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dicembre 2026').last);
    await tester.pumpAndSettle();
    expect(month, '2026-12');
    expect(find.text('Dicembre 2026'), findsOneWidget);

    await tester.tap(find.text('Ponti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutti i tipi').last);
    await tester.pumpAndSettle();
    expect(type, isNull);
  });
}
