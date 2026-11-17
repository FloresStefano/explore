import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Area 2: the main bridges of the year, then offers grouped by month, country, offer.
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
          future: Future.wait([App.repo.catalog(App.prefs.airports), App.repo.calendar()]),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final all = (snap.data?[0] as List<Json>?) ?? const <Json>[];
            final cal = (snap.data?[1] as Json?) ?? const <String, dynamic>{};
            final offers = OfferFilter.shared().apply(all);
            final byMonth = groupOffers(offers, (o) => (o['out_date'] as String).substring(0, 7), byKey: true);
            final filters = [
              FilterBar(months: monthsOf(all), airlines: airlinesOf(all), reversed: true),
              const SizedBox(height: 12),
              CountLine('${byMonth.length} mesi · ${offers.length} offerte'),
            ];
            final bridges = BridgesCard(cal: cal, offers: all);
            Widget monthCard(BuildContext context, int i) {
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
            }

            const empty = EmptyNote('Nessuna offerta con questi filtri.', icon: Icons.event_busy_outlined);
            if (MediaQuery.sizeOf(context).width >= 1100) {
              // Wide screens, like the Map: the bridges on the left, the months on the right.
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: filters)),
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 400,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 0, 24), children: [bridges]),
                    ),
                    Expanded(
                      child: ResponsiveList(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        header: [if (offers.isEmpty) empty],
                        itemCount: byMonth.length,
                        itemBuilder: monthCard,
                      ),
                    ),
                  ]),
                ),
              ]);
            }
            return ResponsiveList(
              header: [...filters, bridges, const SizedBox(height: 14), if (offers.isEmpty) empty],
              itemCount: byMonth.length,
              itemBuilder: monthCard,
            );
          },
        ),
      ),
    );
  }
}

/// One main bridge: the best way (fewest leave days, then longest) around a holiday.
class Bridge {
  Bridge(this.json, this.name);
  final Json json;
  final String name;

  DateTime get out => DateTime.parse(json['out'] as String);
  DateTime get ret => DateTime.parse(json['ret'] as String);
  int get days => ret.difference(out).inDays + 1;
  num get leave => (json['leave_days'] as num?) ?? 0;
  bool get parentLeave => json['needs_parent_leave'] == true;

  /// Offers falling around this period (a day of margin each side) that include
  /// at least one of its holidays or school closures.
  List<Json> offersIn(List<Json> offers, Json marks) {
    final from = out.subtract(const Duration(days: 1)), to = ret.add(const Duration(days: 1));
    final special = [
      for (final k in marks.keys)
        if (!DateTime.parse(k).isBefore(out) && !DateTime.parse(k).isAfter(ret)) DateTime.parse(k),
    ];
    return offers.where((o) {
      final a = DateTime.parse(o['out_date'] as String), b = DateTime.parse(o['ret_date'] as String);
      if (a.isBefore(from) || b.isAfter(to)) return false;
      return special.any((d) => !d.isBefore(a) && !d.isAfter(b));
    }).toList();
  }

  String get period {
    final sameMonth = out.month == ret.month;
    final d = DateFormat('d', 'it'), dm = DateFormat('d MMMM', 'it');
    return sameMonth ? '${d.format(out)} – ${dm.format(ret)}' : '${dm.format(out)} – ${dm.format(ret)}';
  }

  /// The bridges computed by the job, one per holiday.
  static List<Bridge> main(Json cal) {
    final best = <String, Bridge>{};
    for (final b in ((cal['bridges'] as List?) ?? const []).cast<Json>()) {
      final names = ((b['holidays'] as List?) ?? const []).cast<String>();
      if (names.isEmpty) continue;
      // Name it after the real holiday; school-only bridges after the closure.
      final name = names.firstWhere((n) => !n.contains('(scuole)'), orElse: () => names.first);
      final cand = Bridge(b, name.replaceAll(' (scuole)', ''));
      final cur = best[cand.name];
      if (cur == null || (cand.leave, -cand.days).compareTo((cur.leave, -cur.days)) < 0) best[cand.name] = cand;
    }
    return best.values.toList()..sort((a, b) => a.out.compareTo(b.out));
  }
}

extension on (num, int) {
  int compareTo((num, int) o) => $1 != o.$1 ? $1.compareTo(o.$1) : $2.compareTo(o.$2);
}

/// "I ponti dell'anno": a small list of the main bridges; tapping one opens its offers.
class BridgesCard extends StatelessWidget {
  const BridgesCard({super.key, required this.cal, required this.offers});
  final Json cal;
  final List<Json> offers; // the whole catalog: the shared filters are applied here, except the month

  @override
  Widget build(BuildContext context) {
    final bridges = Bridge.main(cal);
    final marks = (cal['marks'] as Json?) ?? const <String, dynamic>{};
    final f = App.filter;
    final pool = OfferFilter(type: f.type, price: f.price, airline: f.airline).apply(offers);
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: orangeBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.celebration_outlined, color: orange, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('I ponti dell\'anno', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Comune di ${(cal['context'] as Json?)?['comune'] ?? 'Verona'} · tocca un ponte per le offerte',
                  style: const TextStyle(fontSize: 11.5, color: muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        if (bridges.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Nessun ponte nei prossimi mesi.', style: TextStyle(color: muted)),
          ),
        for (final b in bridges) _BridgeRow(bridge: b, offers: b.offersIn(pool, marks)),
      ]),
    );
  }
}

class _BridgeRow extends StatelessWidget {
  const _BridgeRow({required this.bridge, required this.offers});
  final Bridge bridge;
  final List<Json> offers;

  @override
  Widget build(BuildContext context) {
    final b = bridge;
    final has = offers.isNotEmpty;
    final stats = Stats(offers);
    final leave = b.leave == 0 ? 'senza ferie' : b.leave == 1 ? '1 giorno di ferie' : '${num1(b.leave)} giorni di ferie';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: has ? const Color(0xFFF7F8FD) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: has
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OffersScreen(
                        section: 'Calendario',
                        path: ['Ponti', '${b.name} · ${b.period}'],
                        offers: offers,
                      ),
                    ),
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: has ? const Color(0xFFDDE0F7) : const Color(0xFFEDEEF4)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.period,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: has ? navy : muted)),
                  const SizedBox(height: 2),
                  Text('${b.name} · $leave${b.parentLeave ? ' (genitori)' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: muted)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: has ? orangeBg : chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${b.days} giorni',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: has ? orange : muted)),
                ),
                const SizedBox(height: 3),
                Text(has ? 'da ${euro(stats.minPrice!)} · ${offers.length}' : 'offerte non ancora raccolte',
                    style: TextStyle(fontSize: 11, color: has ? indigo : muted, fontWeight: FontWeight.w600)),
              ]),
              if (has) const Icon(Icons.chevron_right, color: muted, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
