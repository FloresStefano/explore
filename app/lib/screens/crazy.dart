import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Price limit and length of the "Pazzie" ranking.
const crazyMaxPrice = 50;
const crazyCount = 30;

/// Version of the texts in crazy.json (job/crazy.py VERSION): older texts are not used.
const crazyTextVersion = 3;

/// The three tabs, same rules and one trip kind each: piccole = weekend, medie = weekend+, grandi = ponti.
const crazyKinds = [
  (kind: 'weekend', label: 'Piccole', icon: Icons.local_fire_department_outlined, what: 'weekend'),
  (kind: 'weekend+', label: 'Medie', icon: Icons.whatshot_outlined, what: 'weekend+'),
  (kind: 'ponte', label: 'Grandi', icon: Icons.celebration_outlined, what: 'ponti'),
];

String offerId(Json o) => '${o['origin']}-${o['destination']}-${o['out_date']}-${o['ret_date']}';

/// Net hours at the destination, rounded as the AI text says them (0 when unknown).
int netHours(Json o) => ((o['useful_hours'] as num?) ?? 0).round();

/// Local "HH:MM" of a leg's departure or arrival.
String legTime(Object? leg, String key) {
  final t = '${(leg as Json?)?[key] ?? ''}';
  return t.length >= 16 ? t.substring(11, 16) : '';
}

/// What the Worker needs for one entry (same fields as job/crazy.py request_item).
Json crazyRequest(Json o) => {
  'id': offerId(o),
  'city': o['city'] ?? o['destination'],
  'country': o['country'] ?? '',
  'from': airportCity[o['origin']] ?? o['origin'],
  'out': o['out_date'],
  'ret': o['ret_date'],
  'price': o['price'],
  'hours': o['useful_hours'],
  'dep': legTime(o['outbound'], 'departure'),
  'arr': legTime(o['inbound'], 'arrival'),
  'kind': o['type'] ?? 'weekend',
  'leave': o['leave_days'] ?? 0,
  'holidays': ((o['holidays'] as List?) ?? const []).join(', '),
};

/// Trips of one kind under 50 euro, from the nearest to the furthest, at most 30.
List<Json> crazyOffers(List<Json> catalog, [String kind = 'weekend']) {
  final list = catalog.where((o) => o['type'] == kind && (o['price'] as num) < crazyMaxPrice).toList()
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
  }).toList()..sort((x, y) => (x['price'] as num).compareTo(y['price'] as num));
}

/// What opens when a pazzia is tapped. Piccole: the weekend plus the weekend+ that stretch it.
/// Medie and grandi: the same trip (kind, place, dates) from every airport, nothing wider.
List<Json> crazyDetail(List<Json> catalog, Json sel) {
  if (sel['type'] == 'weekend') return crazyExtensions(catalog, sel);
  return catalog
      .where(
        (o) =>
            o['type'] == sel['type'] &&
            o['destination'] == sel['destination'] &&
            o['out_date'] == sel['out_date'] &&
            o['ret_date'] == sel['ret_date'],
      )
      .toList()
    ..sort((x, y) => (x['price'] as num).compareTo(y['price'] as num));
}

String _period(Json o) {
  final a = DateTime.parse(o['out_date'] as String), b = DateTime.parse(o['ret_date'] as String);
  final dm = DateFormat('d MMMM', 'it');
  return a.month == b.month ? '${a.day}–${dm.format(b)}' : '${dm.format(a)} – ${dm.format(b)}';
}

/// Area 4: "Pazzie", the cheapest trips told by the AI as a ranking, one tab per trip kind.
class CrazyScreen extends StatefulWidget {
  const CrazyScreen({super.key});

  @override
  State<CrazyScreen> createState() => _CrazyScreenState();
}

class _CrazyScreenState extends State<CrazyScreen> {
  static int _tab = 0; // kept while the app is open

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.prefs,
      builder: (context, _) => PageShell(
        // Only the tabs sit on the band: it ends halfway down them.
        headerHeight: 92,
        header: HeaderTitle(
          kicker: 'Le top $crazyCount',
          title: 'Pazzie',
          action: isWide(context)
              ? null
              : const HeaderActions(),
        ),
        child: FutureBuilder(
          key: ValueKey(App.prefs.scope),
          future: Future.wait([App.repo.catalog(App.prefs.airports), App.repo.get('crazy.json')]),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final catalog = (snap.data?[0] as List<Json>?) ?? const <Json>[];
            // Texts written ahead by the daily job: usually nothing to wait for.
            final file = snap.data?[1] as Json?;
            final ready =
                (file?['version'] == crazyTextVersion ? file!['items'] as Json? : null) ?? const <String, dynamic>{};
            final kind = crazyKinds[_tab];
            final list = crazyOffers(catalog, kind.kind);
            final tabs = SegmentTabs(
              bg: Colors.white,
              tabs: [for (final k in crazyKinds) (k.icon, k.label)],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            );
            if (list.isEmpty) {
              return ResponsiveList(
                header: [
                  tabs,
                  const SizedBox(height: 12),
                  EmptyNote(
                    'Nessuna offerta ${kind.what} sotto i $crazyMaxPrice € al momento.',
                    icon: Icons.local_fire_department_outlined,
                  ),
                ],
                itemCount: 0,
                itemBuilder: (_, _) => const SizedBox(),
              );
            }
            final allReady = list.every((o) => ready.containsKey(offerId(o)));
            return FutureBuilder(
              key: ValueKey(_tab),
              // Only when the job has not written some text yet (e.g. new offers) ask the Worker.
              future: allReady
                  ? Future.value(<String, dynamic>{})
                  : App.ai.crazy([for (final o in list) crazyRequest(o)]),
              builder: (context, ai) {
                final texts = <String, Json>{
                  for (final e in ready.entries) e.key: e.value as Json,
                  for (final x in ((ai.data?['items'] as List?) ?? const []).cast<Json>()) '${x['id']}': x,
                };
                final writing = !allReady && ai.connectionState != ConnectionState.done;
                final failed = !allReady && !writing && (ai.data == null || ai.data!.containsKey('error'));
                return ResponsiveList(
                  minItemWidth: 420,
                  header: [
                    tabs,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CountLine(
                            'Top ${list.length} pazzie ${kind.label.toLowerCase()} · ${kind.what} '
                            'sotto i $crazyMaxPrice €, dal più vicino al più lontano',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Tag('AI', color: violet, bg: violetBg),
                        ),
                      ],
                    ),
                    if (writing)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: violet),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'L\'AI sta scrivendo la classifica…',
                              style: TextStyle(fontSize: Fs.small, color: muted),
                            ),
                          ],
                        ),
                      )
                    else if (failed)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Testi AI non disponibili: ecco la classifica in breve.',
                          style: TextStyle(fontSize: Fs.small, color: muted),
                        ),
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
                          section: 'Pazzie ${kind.label.toLowerCase()}',
                          path: ['${list[i]['city'] ?? list[i]['destination']}', _period(list[i])],
                          offers: crazyDetail(catalog, list[i]),
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
    final title = (ai?['title'] as String?)?.trim().isNotEmpty == true
        ? ai!['title'] as String
        : '$city, ${o['country'] ?? ''}';
    final hours = netHours(o);
    final leave = (o['leave_days'] as num?) ?? 0;
    final holidays = ((o['holidays'] as List?) ?? const []).join(', ');
    final dep = legTime(o['outbound'], 'departure'), arr = legTime(o['inbound'], 'arrival');
    final text = (ai?['text'] as String?)?.trim().isNotEmpty == true
        ? ai!['text'] as String
        : 'Da ${airportCity[o['origin']] ?? o['origin']} a $city, ${_period(o)}'
              '${dep.isNotEmpty ? ': partenza alle $dep' : ''}'
              '${arr.isNotEmpty ? ', a casa alle $arr' : ''}'
              '${hours > 0 ? ', $hours ore nette sul posto' : ''}.';
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(Sp.lg - 2, Sp.lg - 2, Sp.md, Sp.lg - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: rank <= 3 ? orange : navy, borderRadius: BorderRadius.circular(Rd.md)),
            child: Text(
              '$rank',
              style: const TextStyle(color: Colors.white, fontSize: Fs.title, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w700, color: navy),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(fontSize: Fs.body, height: 1.4, color: Color(0xFF3A3F5C)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tag('${'${o['country_code'] ?? ''}'.toUpperCase()} · $city'.replaceFirst(RegExp(r'^ · '), '')),
                    Tag(_period(o), color: green, bg: greenBg),
                    if (hours > 0) Tag('$hours ore nette', color: violet, bg: violetBg),
                    if (leave > 0) leaveTag(leave),
                    if (holidays.isNotEmpty) Tag(holidays, color: orange, bg: orangeBg),
                    Tag('da ${airportCity[o['origin']] ?? o['origin']}', color: muted),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                euro(o['price'] as num),
                style: const TextStyle(
                  fontSize: Fs.titleLg,
                  fontWeight: FontWeight.w800,
                  color: indigo,
                  fontFeatures: tabular,
                ),
              ),
              const SizedBox(height: Sp.sm),
              KpiChips(o),
            ],
          ),
        ],
      ),
    );
  }
}

/// The three indicators the job computes for every offer: costo chilometrico, costo orario,
/// ore di sole. Small value-and-unit chips; a tap explains what the number means.
class KpiChips extends StatelessWidget {
  const KpiChips(this.o, {super.key});
  final Json o;

  static String _n(num v, int digits) => v.toStringAsFixed(digits).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final k = o['kpi'] as Json?;
    if (k == null) return const SizedBox.shrink();
    final city = '${o['city'] ?? o['destination']}';
    final from = airportCity[o['origin']] ?? '${o['origin']}';
    final hours = num1((o['useful_hours'] as num?) ?? 0);
    final items = [
      if (k['eur_km'] != null)
        (
          _n(k['eur_km'] as num, 2),
          '€/km',
          'Costo chilometrico',
          '${_n(k['eur_km'] as num, 3)} € per ogni km',
          'Il prezzo del biglietto diviso i km in linea d\'aria tra $from e $city '
              '(${k['km']} km). Più è basso, più strada fai con ogni euro.',
          Icons.straighten_rounded,
        ),
      if (k['eur_h'] != null)
        (
          _n(k['eur_h'] as num, 2),
          '€/ora',
          'Costo orario',
          '${_n(k['eur_h'] as num, 2)} € per ogni ora sul posto',
          'Il prezzo diviso le $hours ore nette che passi a $city: dall\'atterraggio al decollo del '
              'ritorno, contando solo le ore tra le 8 e le 22. Più è basso, più vale il viaggio.',
          Icons.schedule_rounded,
        ),
      if (k['sun'] != null)
        (
          '${k['sun']}%',
          'sole',
          'Ore di sole',
          '${k['sun']}% del soggiorno con il sole',
          'La parte del tuo soggiorno a $city, dall\'atterraggio al decollo del ritorno, in cui il sole è '
              'sopra l\'orizzonte in quelle date. Più è alta, più giornata ti godi.',
          Icons.wb_sunny_rounded,
        ),
    ];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final (value, unit, name, headline, text, icon) in items)
        Padding(
          padding: const EdgeInsets.only(top: Sp.xs),
          child: Tooltip(
            message: name,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _explain(context, name, headline, text, icon),
              child: Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(Rd.xs)),
                child: Column(children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: Fs.label, fontWeight: FontWeight.w800, color: ink, fontFeatures: tabular, height: 1.2)),
                  Text(unit, style: const TextStyle(fontSize: Fs.caption - 1, color: muted, height: 1.2)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  static void _explain(BuildContext context, String name, String headline, String text, IconData icon) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xl))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(Rd.md)),
              child: Icon(icon, color: indigo, size: 20),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: Fs.titleLg, fontWeight: FontWeight.w700, color: ink)),
            ),
          ]),
          const SizedBox(height: Sp.md),
          Text(headline,
              style: const TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w700, color: indigo, fontFeatures: tabular)),
          const SizedBox(height: Sp.sm),
          Text(text, style: const TextStyle(fontSize: Fs.body, height: 1.5, color: muted)),
        ]),
      ),
    );
  }
}
