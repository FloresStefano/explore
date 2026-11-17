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
  // The choice is shared with Home and Map.
  String? get _type => App.filter.type;
  String? get _month => App.filter.month;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.changes,
      builder: (context, _) => PageShell(
        header: HeaderTitle(
          kicker: 'Weekend, weekend+ e ponti',
          title: 'Calendario',
          action: isWide(context) ? null : RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
        ),
        child: FutureBuilder(
          key: ValueKey(App.prefs.airports.join()),
          future: App.repo.catalog(App.prefs.airports),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final all = snap.data ?? const <Json>[];
            final offers = OfferFilter(type: _type, month: _month).apply(all);
            final byMonth = groupOffers(offers, (o) => (o['out_date'] as String).substring(0, 7), byKey: true);
            return ResponsiveList(
              header: [
                FilterBar(
                  type: _type,
                  month: _month,
                  months: monthsOf(all),
                  reversed: true,
                  onType: App.filter.setType,
                  onMonth: App.filter.setMonth,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text('${byMonth.length} mesi · ${offers.length} offerte',
                      style: const TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w500)),
                ),
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
                      builder: (_) => CountriesScreen(
                        kicker: _type == null ? 'Tutte le offerte' : typePlural[_type]!,
                        title: fmtMonthKey(ym),
                        offers: items,
                      ),
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
