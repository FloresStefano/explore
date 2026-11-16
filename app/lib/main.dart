import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'common.dart';
import 'data.dart';
import 'screens/calendar.dart';
import 'screens/home.dart';
import 'screens/map.dart';
import 'screens/stats.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it');
  await App.prefs.load();
  runApp(const WeekendBreakApp());
}

class WeekendBreakApp extends StatelessWidget {
  const WeekendBreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: indigo, primary: indigo, surface: Colors.white),
      scaffoldBackgroundColor: pageBg,
    );
    return MaterialApp(
      title: 'Weekend Break',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink)),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _built = <int>{0};

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Calendario'),
    (Icons.public_outlined, Icons.public, 'Mappa'),
    (Icons.show_chart, Icons.show_chart, 'Statistiche'),
  ];

  Widget _page(int i) {
    if (!_built.contains(i)) return const SizedBox();
    return switch (i) { 0 => const HomeScreen(), 1 => const CalendarScreen(), 2 => const MapScreen(), _ => const StatsScreen() };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [for (var i = 0; i < 4; i++) _page(i)]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: navy.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: InkResponse(
                      onTap: () => setState(() {
                        _built.add(i);
                        _tab = i;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_tab == i ? _items[i].$2 : _items[i].$1, color: _tab == i ? indigo : muted, size: 24),
                          const SizedBox(height: 3),
                          Text(_items[i].$3,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500,
                                  color: _tab == i ? indigo : muted)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
