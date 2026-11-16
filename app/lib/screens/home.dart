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
  String _sort = 'consigliate';

  static const _sorts = {
    'consigliate': 'Consigliate',
    'prezzo_asc': 'Prezzo crescente',
    'prezzo_desc': 'Prezzo decrescente',
    'notti_asc': 'Durata: più brevi',
    'notti_desc': 'Durata: più lunghe',
    'meta': 'Destinazione A-Z',
  };

  int _compare(Json a, Json b) {
    num n(Json o, String k) => (o[k] as num?) ?? double.infinity;
    final byPrice = n(a, 'price').compareTo(n(b, 'price'));
    switch (_sort) {
      case 'prezzo_asc':
        return byPrice;
      case 'prezzo_desc':
        return -byPrice;
      case 'notti_asc':
        final c = n(a, 'nights').compareTo(n(b, 'nights'));
        return c != 0 ? c : byPrice;
      case 'notti_desc':
        final c = n(b, 'nights').compareTo(n(a, 'nights'));
        return c != 0 ? c : byPrice;
      case 'meta':
        final c = '${a['city'] ?? a['destination']}'.compareTo('${b['city'] ?? b['destination']}');
        return c != 0 ? c : byPrice;
      default:
        return n(a, 'price_per_hour').compareTo(n(b, 'price_per_hour'));
    }
  }

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
              }).toList()
                ..sort(_compare);
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
                              : 'Scelte per prezzo per ora utile a destinazione. Lo sconto sul prezzo abituale '
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
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: Text('${offers.length} offerte',
                            style: const TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w500)),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Ordina le offerte',
                        initialValue: _sort,
                        onSelected: (v) => setState(() => _sort = v),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        itemBuilder: (_) => [
                          for (final e in _sorts.entries)
                            PopupMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: e.key == _sort ? FontWeight.w700 : FontWeight.w400,
                                      color: e.key == _sort ? indigo : ink)),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.swap_vert, size: 17, color: indigo),
                            const SizedBox(width: 6),
                            Text(_sorts[_sort]!,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink)),
                            const Icon(Icons.expand_more, size: 18, color: muted),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
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
