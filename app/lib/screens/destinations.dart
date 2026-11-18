import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Destinazioni: the whole catalog grouped by destination country, cheapest first.
class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.changes,
      builder: (context, _) {
        final airports = App.prefs.airports;
        return PageShell(
          headerHeight: sectionHeaderHeight,
          header: HeaderTitle(
            kicker: 'Offerte per paese',
            title: 'Destinazioni',
            action: isWide(context) ? null : RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
          ),
          child: FutureBuilder(
            key: ValueKey(airports.join()),
            future: App.repo.catalog(airports),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Loading();
              final all = snap.data ?? const <Json>[];
              final months = monthsOf(all);
              final offers = OfferFilter.shared().apply(all);
              final groups = groupOffers(offers, (o) => o['country'] as String? ?? '');
              return RefreshIndicator(
                onRefresh: () async {
                  App.repo.refresh();
                  setState(() {});
                },
                child: ResponsiveList(
                  header: [
                    FilterBar(months: months, airlines: airlinesOf(all)),
                    const SizedBox(height: 12),
                    CountLine(all.isEmpty ? '' : '${groups.length} paesi · ${offers.length} offerte'),
                    if (all.isEmpty)
                      const EmptyNote('Nessun dato disponibile al momento.\nTrascina verso il basso per riprovare.')
                    else if (offers.isEmpty)
                      const EmptyNote('Nessuna offerta con questi filtri.', icon: Icons.filter_alt_off_outlined),
                  ],
                  itemCount: groups.length,
                  itemBuilder: (context, i) => countryCard(
                    context,
                    groups[i].$1,
                    groups[i].$2,
                    section: 'Destinazioni',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
