import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weekend_break/common.dart';
import 'package:weekend_break/data.dart';

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

  testWidgets('a choice in one section shows up in the others', (tester) async {
    Widget bar() => ListenableBuilder(
          listenable: App.filter,
          builder: (_, _) => const FilterBar(months: ['2026-11', '2026-12']),
        );
    // Two sections built at the same time, as in the app's IndexedStack.
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [bar(), bar()]))));
    await tester.tap(find.text('Tutti i tipi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend').last);
    await tester.pumpAndSettle();
    expect(App.filter.type, 'weekend');
    expect(find.text('Weekend'), findsNWidgets(2));

    await tester.tap(find.text('Tutti i prezzi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50–100 €').last);
    await tester.pumpAndSettle();
    expect(App.filter.price, '50-100');
    expect(find.text('50–100 €'), findsNWidgets(2));
  });

  test('airline filter matches any carrier of the trip', () {
    final o = {'price': 40, 'out_date': '2026-12-05', 'ret_date': '2026-12-07', 'airlines': ['Wizz Air Malta', 'Ryanair']};
    expect(const OfferFilter(airline: 'Wizz Air Malta').test(o), isTrue);
    expect(const OfferFilter(airline: 'Ryanair').test(o), isTrue);
    expect(const OfferFilter(airline: 'Lufthansa').test(o), isFalse);
    expect(airlinesOf([o]), ['Ryanair', 'Wizz Air Malta']);
  });

  test('price bands: lower bound excluded, upper bound included', () {
    bool keeps(String band, num price) =>
        OfferFilter(price: band).test({'price': price, 'out_date': '2026-12-05', 'ret_date': '2026-12-07'});
    expect(keeps('0-50', 50), isTrue);
    expect(keeps('50-100', 50), isFalse);
    expect(keeps('50-100', 50.01), isTrue);
    expect(keeps('100-150', 150), isTrue);
    expect(keeps('100-150', 150.5), isFalse);
  });
}
