import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Area 1: the whole catalog grouped by destination country, cheapest first.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.changes,
      builder: (context, _) {
        final airports = App.prefs.airports;
        return PageShell(
          header: HeaderTitle(
            kicker: 'Partenza da',
            title: airports.map((a) => airportCity[a] ?? a).join(' · '),
            action: isWide(context) ? null : RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
          ),
          child: FutureBuilder(
            key: ValueKey(airports.join()),
            future: App.repo.catalog(airports),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Loading();
              final all = snap.data ?? const <Json>[];
              final months = monthsOf(all);
              final offers = OfferFilter(type: App.filter.type, month: App.filter.month, price: App.filter.price).apply(all);
              final groups = groupOffers(offers, (o) => o['country'] as String? ?? '');
              return RefreshIndicator(
                onRefresh: () async {
                  App.repo.refresh();
                  setState(() {});
                },
                child: ResponsiveList(
                  header: [
                    const RecapCard(),
                    const SizedBox(height: 14),
                    FilterBar(months: months),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        all.isEmpty
                            ? ''
                            : '${groups.length} paesi · ${offers.length} offerte · ordinati per prezzo più basso',
                        style: const TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w500),
                      ),
                    ),
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
                    kicker: filterLabel(),
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

/// "Le migliori occasioni": AI news recap of the latest run (7.2), collapsible.
class RecapCard extends StatefulWidget {
  const RecapCard({super.key});

  @override
  State<RecapCard> createState() => _RecapCardState();
}

class _RecapCardState extends State<RecapCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: FutureBuilder(
        future: Future.wait([App.ai.recap(), App.repo.meta()]),
        builder: (context, snap) {
          final r = snap.data?[0];
          final meta = snap.data?[1];
          final runAt = DateTime.tryParse('${meta?['run_at'] ?? r?['run_at'] ?? ''}')?.toLocal();
          final ok = r != null && r['error'] == null;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Le migliori occasioni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Tag('AI', color: violet, bg: violetBg),
            ]),
            if (runAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Raccolta di ${fmtDateTime(runAt)} · ${ago(runAt)}',
                    style: const TextStyle(fontSize: 12, color: muted)),
              ),
            const SizedBox(height: 10),
            if (snap.connectionState != ConnectionState.done)
              const Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: violet)),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Il resoconto della raccolta si sta scrivendo…', style: TextStyle(color: muted)),
                ),
              ])
            else if (!ok)
              Text('Resoconto non disponibile al momento (${r?['error'] ?? 'errore'}).',
                  style: const TextStyle(color: muted, fontSize: 13))
            else ...[
              Text('${r['headline']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: indigo)),
              const SizedBox(height: 6),
              Text('${r['lead']}', style: const TextStyle(fontSize: 14, height: 1.45)),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('${r['body']}', style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF3A3F5C))),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _open = !_open),
                  icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
                  label: Text(_open ? 'Chiudi' : 'Leggi tutto il resoconto'),
                ),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
