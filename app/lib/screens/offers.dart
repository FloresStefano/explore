import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import '../ticket.dart';

/// Offers for one date pair, or for one destination across all pairs.
class OffersScreen extends StatefulWidget {
  const OffersScreen.window(this.window, {super.key}) : destination = null, destinationName = null;
  final Json? window;
  final String? destination;
  final String? destinationName;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  late final Future<List<Json>> _offers;
  String _sort = 'ore';
  String? _airport;

  @override
  void initState() {
    super.initState();
    final w = widget.window!;
    _offers = App.repo.offersFor('${w['out']}_${w['ret']}', App.prefs.airports);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.window!;
    Widget end(String iso, CrossAxisAlignment align) {
      final parts = fmtDay(iso).split(' ');
      return Column(crossAxisAlignment: align, children: [
        Text('${parts[0].toUpperCase()} ${parts[1]}',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        Text(parts.skip(2).join(' '), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ]);
    }

    return Scaffold(
      body: PageShell(
        headerHeight: 200,
        header: Column(children: [
          Row(children: [
            RoundIcon(Icons.arrow_back, tooltip: 'Indietro', onTap: () => Navigator.pop(context)),
            const Expanded(
              child: Text('Offerte',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 40),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            end(w['out'] as String, CrossAxisAlignment.start),
            const SizedBox(width: 12),
            const Icon(Icons.flight, color: Colors.white, size: 18),
            Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.35))),
            const SizedBox(width: 12),
            end(w['ret'] as String, CrossAxisAlignment.end),
          ]),
          const SizedBox(height: 8),
          Text('${w['nights']} notti · ${leaveLabel(w['leave_days'] as num)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
        ]),
        child: FutureBuilder(
          future: _offers,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            var offers = [...?snap.data];
            if (_airport != null) offers = offers.where((o) => o['origin'] == _airport).toList();
            num key(Json o) => _sort == 'prezzo' ? o['price'] as num : (o['price_per_hour'] as num?) ?? 1e9;
            offers.sort((a, b) => key(a).compareTo(key(b)));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    Pill('Più ore utili', selected: _sort == 'ore', onTap: () => setState(() => _sort = 'ore')),
                    Pill('Prezzo', selected: _sort == 'prezzo', onTap: () => setState(() => _sort = 'prezzo')),
                    for (final a in App.prefs.airports)
                      Pill(airportCity[a] ?? a,
                          selected: _airport == a, onTap: () => setState(() => _airport = _airport == a ? null : a)),
                  ]),
                ),
                const SizedBox(height: 14),
                if (offers.isEmpty)
                  const EmptyNote('Nessuna offerta per queste date.\nI dati si completano nei prossimi giorni.',
                      icon: Icons.airplanemode_inactive)
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 4),
                    child: Text('${offers.length} offerte trovate', style: const TextStyle(fontSize: 12.5, color: muted)),
                  ),
                  for (final o in offers.take(60)) TicketCard(o),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
