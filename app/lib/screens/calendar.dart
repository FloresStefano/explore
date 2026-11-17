import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Area 2: offers grouped by month, then country, then offer.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.changes,
      builder: (context, _) => PageShell(
        headerHeight: sectionHeaderHeight,
        header: HeaderTitle(
          kicker: 'Offerte per mese',
          title: 'Calendario',
          action: isWide(context) ? null : RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
        ),
        child: FutureBuilder(
          key: ValueKey(App.prefs.airports.join()),
          future: App.repo.catalog(App.prefs.airports),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final all = snap.data ?? const <Json>[];
            final offers = OfferFilter.shared().apply(all);
            final byMonth = groupOffers(offers, (o) => (o['out_date'] as String).substring(0, 7), byKey: true);
            return ResponsiveList(
              header: [
                FilterBar(months: monthsOf(all), airlines: airlinesOf(all), reversed: true),
                const SizedBox(height: 12),
                CountLine('${byMonth.length} mesi · ${offers.length} offerte'),
                if (offers.isEmpty)
                  const EmptyNote('Nessuna offerta con questi filtri.', icon: Icons.event_busy_outlined),
              ],
              itemCount: byMonth.length,
              itemBuilder: (context, i) {
                final (ym, items) = byMonth[i];
                final countries = {for (final o in items) o['country']}.length;
                return AggregateCard(
                  badge: fmtMonthShort(ym).toUpperCase(),
                  title: fmtMonthKey(ym),
                  subtitle: '$countries paesi · ${items.length} offerte',
                  stats: Stats(items),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CountriesScreen(section: 'Calendario', path: [fmtMonthKey(ym)], offers: items),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
