import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      title: 'Volo via!',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
  final _navs = List.generate(7, (_) => GlobalKey<NavigatorState>());

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore, 'Destinazioni'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Calendario'),
    (Icons.public_outlined, Icons.public, 'Mappa'),
    (Icons.local_fire_department_outlined, Icons.local_fire_department, 'Pazzie'),
    (Icons.tune, Icons.tune, 'Impostazioni'),
    (Icons.info_outline_rounded, Icons.info_rounded, 'Informazioni'),
  ];

  Widget _page(int i) {
    if (!_built.contains(i)) return const SizedBox();
    final Widget root = switch (i) {
      0 => HomeScreen(onExplore: () => _go(1)),
      1 => const DestinationsScreen(),
      2 => const CalendarScreen(),
      3 => const MapScreen(),
      4 => const CrazyScreen(),
      5 => const SettingsScreen(embedded: true),
      _ => const InfoScreen(embedded: true),
    };
    return Navigator(key: _navs[i], onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root));
  }

  static const _tabNames = ['home', 'destinazioni', 'calendario', 'mappa', 'pazzie', 'impostazioni', 'informazioni'];

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
    if (!wide && _tab >= 5) _tab = 0;
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
      duration: Motion.medium,
      curve: Motion.curve,
      width: open ? 236 : 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [navy, navySoft]),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.lg + 4, Sp.xl, Sp.md, Sp.xl),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [indigo, Color(0xFF4F6BF0)]),
                  borderRadius: BorderRadius.circular(Rd.md),
                  boxShadow: [BoxShadow(color: indigo.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20),
              ),
              if (open) ...[
                const SizedBox(width: Sp.md),
                const Expanded(
                  child: Text('Volo via!',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: Fs.title)),
                ),
              ],
            ]),
          ),
          for (var i = 0; i < _ShellState._items.length; i++) ...[
            if (i == 5) const Spacer(),
            _SideItem(
              icon: tab == i ? _ShellState._items[i].$2 : _ShellState._items[i].$1,
              label: _ShellState._items[i].$3,
              selected: tab == i,
              open: open,
              onTap: () => onTap(i),
            ),
          ],
          const SizedBox(height: Sp.sm),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.lg),
            child: Align(
              alignment: open ? Alignment.centerRight : Alignment.center,
              child: IconButton(
                tooltip: open ? 'Comprimi il menu' : 'Espandi il menu',
                onPressed: App.prefs.toggleSideMenu,
                icon: Icon(open ? Icons.keyboard_double_arrow_left_rounded : Icons.keyboard_double_arrow_right_rounded,
                    color: Colors.white60),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One entry of the side menu: a soft pill and an accent bar on the current section, a hover tint.
class _SideItem extends StatefulWidget {
  const _SideItem(
      {required this.icon, required this.label, required this.selected, required this.open, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected, open;
  final VoidCallback onTap;

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final fg = on ? Colors.white : (_hover ? Colors.white : Colors.white70);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 2),
      child: Tooltip(
        message: widget.open ? '' : widget.label,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: Motion.fast,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: Sp.md + 2),
              decoration: BoxDecoration(
                color: on
                    ? Colors.white.withValues(alpha: 0.13)
                    : (_hover ? Colors.white.withValues(alpha: 0.06) : Colors.transparent),
                borderRadius: BorderRadius.circular(Rd.md),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: Motion.medium,
                  curve: Motion.curve,
                  width: 3,
                  height: on ? 18 : 0,
                  margin: const EdgeInsets.only(right: Sp.sm + 2),
                  decoration: BoxDecoration(color: const Color(0xFF8FA6FF), borderRadius: BorderRadius.circular(2)),
                ),
                Icon(widget.icon, color: fg, size: 21),
                if (widget.open) ...[
                  const SizedBox(width: Sp.md + 2),
                  Expanded(
                    child: Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                            color: fg, fontSize: Fs.body, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
