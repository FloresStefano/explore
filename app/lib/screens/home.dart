import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import '../ticket.dart';
import 'settings.dart';

/// Area 1: the best offers by every criterion.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<Json>, Json?)> _data = _load();
  String _kind = 'tutte'; // tutte | weekend | ponte
  bool _noLeave = false;

  Future<(List<Json>, Json?)> _load() async => (await App.repo.top(), await App.repo.meta());

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.prefs,
      builder: (context, _) {
        final airports = App.prefs.airports;
        return PageShell(
          header: HeaderTitle(
            kicker: 'Partenza da',
            title: airports.map((a) => airportCity[a] ?? a).join(' · '),
            action: RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
          ),
          child: FutureBuilder(
            future: _data,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final (all, meta) = snap.data ?? (const <Json>[], null);
              final offers = all.where((o) {
                if (!airports.contains(o['origin'])) return false;
                if (_kind != 'tutte' && o['window'] != _kind) return false;
                if (_noLeave && ((o['leave_days'] as num?) ?? 0) > 0) return false;
                return true;
              }).toList();
              final unmissable = offers.where((o) => o['unmissable'] == true).length;
              return RefreshIndicator(
                onRefresh: () async => setState(() => _data = _load()),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    WhiteCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            for (final (k, label) in const [('tutte', 'Tutte'), ('weekend', 'Weekend'), ('ponte', 'Ponti')])
                              Pill(label, selected: _kind == k, onTap: () => setState(() => _kind = k)),
                            Pill('Senza ferie', selected: _noLeave, onTap: () => setState(() => _noLeave = !_noLeave)),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        Text(unmissable > 0 ? 'Offerte imperdibili' : 'Le migliori occasioni',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          unmissable > 0
                              ? '$unmissable sotto il prezzo abituale di almeno il 30%'
                              : 'Ordinate per prezzo per ora utile a destinazione. Lo sconto sul prezzo abituale '
                                  'comparirà quando lo storico sarà maturo.',
                          style: const TextStyle(fontSize: 12.5, color: muted, height: 1.35),
                        ),
                        if (meta?['run_at'] != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.update, size: 14, color: muted),
                            const SizedBox(width: 6),
                            Text('Dati aggiornati ${fmtDay(meta!['run_at'] as String)}',
                                style: const TextStyle(fontSize: 12, color: muted)),
                          ]),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (all.isEmpty)
                      const EmptyNote('Nessun dato disponibile al momento.\nTrascina verso il basso per riprovare.')
                    else if (offers.isEmpty)
                      const EmptyNote('Nessuna offerta con questi filtri.', icon: Icons.filter_alt_off_outlined)
                    else
                      for (final o in offers) TicketCard(o),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
