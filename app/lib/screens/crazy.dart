import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Price limit and length of the "Pazzie" ranking.
const crazyMaxPrice = 50;
const crazyCount = 30;

String offerId(Json o) => '${o['origin']}-${o['destination']}-${o['out_date']}-${o['ret_date']}';

/// Weekends under 50 euro, from the nearest to the furthest, at most 30.
List<Json> crazyOffers(List<Json> catalog) {
  final list = catalog.where((o) => o['type'] == 'weekend' && (o['price'] as num) < crazyMaxPrice).toList()
    ..sort((a, b) {
      final c = (a['out_date'] as String).compareTo(b['out_date'] as String);
      return c != 0 ? c : (a['price'] as num).compareTo(b['price'] as num);
    });
  return list.take(crazyCount).toList();
}

/// The weekend itself (from any airport) plus the weekend+ trips to the same place that
/// stretch it by a day (Thursday evening or Monday).
List<Json> crazyExtensions(List<Json> catalog, Json sel) {
  DateTime d(Object? s) => DateTime.parse(s as String);
  final a = d(sel['out_date']), b = d(sel['ret_date']);
  final from = a.subtract(const Duration(days: 1)), to = b.add(const Duration(days: 1));
  return catalog.where((o) {
    if (o['destination'] != sel['destination']) return false;
    final oa = d(o['out_date']), ob = d(o['ret_date']);
    if (o['type'] == 'weekend') return oa == a && ob == b;
    if (o['type'] != 'weekend+') return false;
    return !oa.isBefore(from) && !ob.isAfter(to) && !oa.isAfter(b) && !ob.isBefore(a);
  }).toList()
    ..sort((x, y) => (x['price'] as num).compareTo(y['price'] as num));
}

String _period(Json o) {
  final a = DateTime.parse(o['out_date'] as String), b = DateTime.parse(o['ret_date'] as String);
  final dm = DateFormat('d MMMM', 'it');
  return a.month == b.month ? '${a.day}–${dm.format(b)}' : '${dm.format(a)} – ${dm.format(b)}';
}

/// Area 4: "Pazzie", the cheapest weekends told by the AI as a ranking.
class CrazyScreen extends StatelessWidget {
  const CrazyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.prefs,
      builder: (context, _) => PageShell(
        headerHeight: sectionHeaderHeight,
        header: HeaderTitle(
          kicker: 'Weekend sotto i $crazyMaxPrice €',
          title: 'Pazzie',
          action: isWide(context) ? null : RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
        ),
        child: FutureBuilder(
          key: ValueKey(App.prefs.airports.join()),
          future: App.repo.catalog(App.prefs.airports),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final catalog = snap.data ?? const <Json>[];
            final list = crazyOffers(catalog);
            if (list.isEmpty) {
              return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: const [
                EmptyNote('Nessun weekend sotto i 50 € al momento.', icon: Icons.local_fire_department_outlined),
              ]);
            }
            final request = [
              for (final o in list)
                {
                  'id': offerId(o),
                  'city': o['city'] ?? o['destination'],
                  'country': o['country'] ?? '',
                  'from': airportCity[o['origin']] ?? o['origin'],
                  'out': o['out_date'],
                  'ret': o['ret_date'],
                  'price': o['price'],
                },
            ];
            return FutureBuilder(
              future: App.ai.crazy(request),
              builder: (context, ai) {
                final texts = <String, Json>{
                  for (final x in ((ai.data?['items'] as List?) ?? const []).cast<Json>()) '${x['id']}': x,
                };
                final writing = ai.connectionState != ConnectionState.done;
                final failed = !writing && (ai.data == null || ai.data!.containsKey('error'));
                return ResponsiveList(
                  minItemWidth: 420,
                  header: [
                    Row(children: [
                      Expanded(
                        child: CountLine('${list.length} weekend · dal più vicino al più lontano'),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Tag('AI', color: violet, bg: violetBg),
                      ),
                    ]),
                    if (writing)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Row(children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: violet)),
                          SizedBox(width: 8),
                          Text('L\'AI sta scrivendo la classifica…', style: TextStyle(fontSize: 12.5, color: muted)),
                        ]),
                      )
                    else if (failed)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text('Testi AI non disponibili: ecco la classifica in breve.',
                            style: TextStyle(fontSize: 12.5, color: muted)),
                      ),
                  ],
                  itemCount: list.length,
                  itemBuilder: (context, i) => _CrazyCard(
                    rank: i + 1,
                    offer: list[i],
                    ai: texts[offerId(list[i])],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OffersScreen(
                          section: 'Pazzie',
                          path: ['${list[i]['city'] ?? list[i]['destination']}', _period(list[i])],
                          offers: crazyExtensions(catalog, list[i]),
                        ),
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

class _CrazyCard extends StatelessWidget {
  const _CrazyCard({required this.rank, required this.offer, required this.ai, required this.onTap});
  final int rank;
  final Json offer;
  final Json? ai;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final city = '${o['city'] ?? o['destination']}';
    final title = (ai?['title'] as String?)?.trim().isNotEmpty == true ? ai!['title'] as String : '$city, ${o['country'] ?? ''}';
    final text = (ai?['text'] as String?)?.trim().isNotEmpty == true
        ? ai!['text'] as String
        : 'Da ${airportCity[o['origin']] ?? o['origin']} a $city, ${_period(o)}.';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank <= 3 ? orange : navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: navy)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF3A3F5C))),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Tag('${'${o['country_code'] ?? ''}'.toUpperCase()} · $city'.replaceFirst(RegExp(r'^ · '), '')),
                  Tag(_period(o), color: green, bg: greenBg),
                  Tag('da ${airportCity[o['origin']] ?? o['origin']}', color: muted),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(euro(o['price'] as num),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: indigo)),
              const SizedBox(height: 14),
              const Icon(Icons.chevron_right, color: muted),
            ]),
          ]),
        ),
      ),
    );
  }
}
