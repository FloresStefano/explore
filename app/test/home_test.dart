import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weekend_break/common.dart';
import 'package:weekend_break/screens/home.dart';
import 'package:weekend_break/screens/home_bits.dart';
import 'package:weekend_break/theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  testWidgets('home shows the slogan and opens the destinations', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(onExplore: () => opened = true))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('IL MONDO È TROPPO PICCOLO'), findsOneWidget);
    expect(find.text('PER NON GIRARLO TUTTO'), findsOneWidget);
    expect(find.text('Non hai più scuse!'), findsOneWidget);
    // The countdown line depends on the day the test runs.
    expect(
        find.text(isWeekendNow(DateTime.now()) ? 'È weekend! Sei ancora a casa?' : 'Il prossimo weekend inizia tra'),
        findsAny);
    await tester.ensureVisible(find.text('Scopri le destinazioni'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Scopri le destinazioni'));
    expect(opened, isTrue);
  });

  test('the next weekend starts on Friday at 18:00', () {
    expect(nextWeekendStart(DateTime(2026, 11, 18, 10)), DateTime(2026, 11, 20, 18)); // Wednesday
    expect(nextWeekendStart(DateTime(2026, 11, 20, 17, 59)), DateTime(2026, 11, 20, 18)); // Friday afternoon
    expect(nextWeekendStart(DateTime(2026, 11, 20, 18, 30)), DateTime(2026, 11, 27, 18)); // Friday evening
    expect(nextWeekendStart(DateTime(2026, 11, 22, 12)), DateTime(2026, 11, 27, 18)); // Sunday
    expect(isWeekendNow(DateTime(2026, 11, 20, 18, 30)), isTrue);
    expect(isWeekendNow(DateTime(2026, 11, 21, 9)), isTrue);
    expect(isWeekendNow(DateTime(2026, 11, 23, 9)), isFalse);
  });

  testWidgets('countdown shows days, hours, minutes and seconds', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WeekendCountdown(now: () => DateTime(2026, 11, 18, 10, 0, 0)))));
    // Wednesday 10:00 -> Friday 18:00 = 2 days 8 hours.
    expect(find.text('02'), findsOneWidget);
    expect(find.text('08'), findsOneWidget);
    expect(find.text('00'), findsNWidgets(2));
  });

  // Large text (130%) on a small phone: no overflow anywhere on the Home, cards and filters.
  testWidgets('large text fits on a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget scaled(Widget child) => MaterialApp(
          theme: appTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 2600), textScaler: TextScaler.linear(1.3)),
            child: Scaffold(body: child),
          ),
        );
    await tester.pumpWidget(scaled(HomeScreen(onExplore: () {})));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final stats = Stats([
      {'price': 29.98, 'type': 'weekend', 'destination': 'PRG'},
      {'price': 49.0, 'type': 'weekend+', 'destination': 'PRG'},
      {'price': 89.0, 'type': 'ponte', 'destination': 'BRQ'},
    ]);
    await tester.pumpWidget(scaled(ListView(padding: const EdgeInsets.all(16), children: [
      AggregateCard(badge: 'ES', title: 'Repubblica Ceca', subtitle: '12 mete · 395 offerte', stats: stats, onTap: () {}),
      const SizedBox(height: 12),
      const FilterBar(months: ['2026-11', '2026-12'], airlines: ['Ryanair', 'Wizz Air Malta']),
    ])));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
