import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'common.dart';
import 'data.dart';
import 'theme.dart';
import 'screens/calendar.dart';
import 'screens/destinations.dart';
import 'screens/home.dart';
import 'screens/map.dart';
import 'screens/settings.dart';
import 'screens/crazy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await initializeDateFormatting('it');
  await App.prefs.load();
  runApp(const WeekendBreakApp());
}

class WeekendBreakApp extends StatelessWidget {
  const WeekendBreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weekend Break',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const Shell(),
    );
  }
}

/// Bottom navigation on phones; a collapsible side menu on wide screens.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _built = <int>{0};
  // One navigation stack per section: pages open inside it and the menu stays visible.
  final _navs = List.generate(6, (_) => GlobalKey<NavigatorState>());

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore, 'Destinazioni'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Calendario'),
    (Icons.public_outlined, Icons.public, 'Mappa'),
    (Icons.local_fire_department_outlined, Icons.local_fire_department, 'Pazzie'),
    (Icons.tune, Icons.tune, 'Impostazioni'),
  ];

  Widget _page(int i) {
    if (!_built.contains(i)) return const SizedBox();
    final Widget root = switch (i) {
      0 => HomeScreen(onExplore: () => _go(1)),
      1 => const DestinationsScreen(),
      2 => const CalendarScreen(),
      3 => const MapScreen(),
      4 => const CrazyScreen(),
      _ => const SettingsScreen(embedded: true),
    };
    return Navigator(key: _navs[i], onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root));
  }

  static const _tabNames = ['home', 'destinazioni', 'calendario', 'mappa', 'pazzie', 'impostazioni'];

  @override
  void initState() {
    super.initState();
    // ?tab=calendario opens a section directly (links, bookmarks).
    final i = _tabNames.indexOf(Uri.base.queryParameters['tab'] ?? '');
    if (i > 0) {
      _tab = i;
      _built.add(i);
    }
  }

  void _go(int i) => setState(() {
        // Tapping the current section again goes back to its first page.
        if (_tab == i) _navs[i].currentState?.popUntil((r) => r.isFirst);
        _built.add(i);
        _tab = i;
      });

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    // On phones settings open from the header icon: five tabs at the bottom.
    if (!wide && _tab == 5) _tab = 0;
    final body = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navs[_tab].currentState?.maybePop();
      },
      child: IndexedStack(index: _tab, children: [for (var i = 0; i < _items.length; i++) _page(i)]),
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          ListenableBuilder(listenable: App.prefs, builder: (context, _) => _SideMenu(tab: _tab, onTap: _go)),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      // Material 3 navigation bar: pill indicator on the current section, 48dp+ targets.
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: border))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            _go(i);
          },
          destinations: [
            for (var i = 0; i < 5; i++)
              NavigationDestination(
                icon: Icon(_items[i].$1),
                selectedIcon: Icon(_items[i].$2),
                label: _items[i].$3,
              ),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.tab, required this.onTap});
  final int tab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final open = App.prefs.sideMenuExpanded;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: open ? 232 : 76,
      color: navy,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 10, 22),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: indigo, borderRadius: BorderRadius.circular(Rd.md)),
                child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 20),
              ),
              if (open) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Weekend Break',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: Fs.title)),
                ),
              ],
            ]),
          ),
          for (var i = 0; i < _ShellState._items.length; i++) ...[
            if (i == 5) const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Tooltip(
                message: open ? '' : _ShellState._items[i].$3,
                child: Material(
                  color: tab == i ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(Rd.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rd.md),
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Icon(tab == i ? _ShellState._items[i].$2 : _ShellState._items[i].$1,
                            color: tab == i ? Colors.white : Colors.white70, size: 22),
                        if (open) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(_ShellState._items[i].$3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: tab == i ? Colors.white : Colors.white70,
                                    fontWeight: tab == i ? FontWeight.w700 : FontWeight.w500)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
            child: IconButton(
              tooltip: open ? 'Comprimi il menu' : 'Espandi il menu',
              onPressed: App.prefs.toggleSideMenu,
              icon: Icon(open ? Icons.keyboard_double_arrow_left : Icons.keyboard_double_arrow_right,
                  color: Colors.white70),
            ),
          ),
        ]),
      ),
    );
  }
}
