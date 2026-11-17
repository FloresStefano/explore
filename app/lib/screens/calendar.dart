import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Area 2: the bridge calendar, then offers grouped by month, country, offer.
///
/// Tapping a day keeps the trips that contain it. "Scegli ferie" switches the grid to
/// range mode: two taps pick a period and only trips fully inside it remain.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // ?mese=2026-12 opens the grid on that month.
  DateTime _grid = _initialMonth();

  static DateTime _initialMonth() {
    final m = Uri.base.queryParameters['mese'];
    final d = m == null || !RegExp(r'^\d{4}-\d{2}$').hasMatch(m) ? null : DateTime.tryParse('$m-01');
    return d ?? DateTime(DateTime.now().year, DateTime.now().month);
  }
  bool _rangeMode = false;
  DateTime? _day, _from, _to;
  String? _type = 'ponte';
  String? _month;

  void _tap(DateTime d) => setState(() {
        if (!_rangeMode) {
          _day = _day == d ? null : d;
          return;
        }
        if (_from == null || _to != null) {
          _from = d;
          _to = null;
        } else if (d.isBefore(_from!)) {
          _to = _from;
          _from = d;
        } else {
          _to = d;
        }
      });

  void _clear() => setState(() {
        _day = null;
        _from = null;
        _to = null;
      });

  OfferFilter get _filter => OfferFilter(
        type: _type,
        month: _day == null && _from == null ? _month : null,
        day: _rangeMode ? null : _day,
        from: _rangeMode ? _from : null,
        to: _rangeMode ? (_to ?? _from) : null,
      );

  String get _filterLabel {
    if (!_rangeMode && _day != null) return 'Viaggi che contengono ${fmtDate(_day!)}';
    if (_rangeMode && _from != null) {
      return _to == null ? 'Dal ${fmtDate(_from!)}: tocca il giorno di fine' : 'Dal ${fmtDate(_from!)} al ${fmtDate(_to!)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.prefs,
      builder: (context, _) => PageShell(
        header: HeaderTitle(
          kicker: 'Weekend, weekend+ e ponti',
          title: 'Calendario',
          action: isWide(context) ? null : RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
        ),
        child: FutureBuilder(
          key: ValueKey(App.prefs.airports.join()),
          future: Future.wait([App.repo.catalog(App.prefs.airports), App.repo.calendar()]),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final all = (snap.data?[0] as List<Json>?) ?? const [];
            final cal = (snap.data?[1] as Json?) ?? const {};
            final offers = _filter.apply(all);
            final byMonth = groupOffers(offers, (o) => (o['out_date'] as String).substring(0, 7), byKey: true);
            final grid = _CalendarCard(
              month: _grid,
              cal: cal,
              rangeMode: _rangeMode,
              day: _day,
              from: _from,
              to: _to,
              onTap: _tap,
              onMonth: (m) => setState(() => _grid = m),
              onMode: (range) => setState(() {
                _rangeMode = range;
                _clear();
              }),
            );
            final filters = <Widget>[
              TypeFilter(value: _type, reversed: true, light: true, onChanged: (v) => setState(() => _type = v)),
              const SizedBox(height: 8),
              if (_filterLabel.isEmpty)
                MonthFilter(
                  months: monthsOf(all),
                  value: _month,
                  light: true,
                  onChanged: (v) => setState(() {
                    _month = v;
                    if (v != null) _grid = DateTime.parse('$v-01');
                  }),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(_filterLabel),
                    avatar: Icon(_rangeMode ? Icons.date_range : Icons.today, size: 18, color: indigo),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    onDeleted: _clear,
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('${byMonth.length} mesi · ${offers.length} offerte',
                    style: const TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w500)),
              ),
              if (offers.isEmpty)
                const EmptyNote('Nessuna offerta con questi filtri.\nLe offerte coprono i prossimi 90 giorni.',
                    icon: Icons.event_busy_outlined),
            ];
            final wide = MediaQuery.sizeOf(context).width >= 1100;
            final list = ResponsiveList(
              header: [if (!wide) ...[grid, const SizedBox(height: 14)], ...filters],
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
                        kicker: [if (_type != null) typePlural[_type], if (_filterLabel.isNotEmpty) _filterLabel]
                            .join(' · '),
                        title: fmtMonthKey(ym),
                        offers: items,
                      ),
                    ),
                  ),
                );
              },
            );
            if (!wide) return list;
            // Wide screens: calendar on the left, the hierarchy on the right.
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 420,
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 0, 24), child: grid),
              ),
              Expanded(child: list),
            ]);
          },
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.cal,
    required this.rangeMode,
    required this.day,
    required this.from,
    required this.to,
    required this.onTap,
    required this.onMonth,
    required this.onMode,
  });
  final DateTime month;
  final Json cal;
  final bool rangeMode;
  final DateTime? day, from, to;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<bool> onMode;

  @override
  Widget build(BuildContext context) {
    final marks = (cal['marks'] as Json?) ?? const {};
    final bridgeDays = <String>{};
    final leaveDays = <String>{};
    for (final b in ((cal['bridges'] as List?) ?? const []).cast<Json>()) {
      final a = day0(b['out'] as String), z = day0(b['ret'] as String);
      for (var d = a; !d.isAfter(z); d = d.add(const Duration(days: 1))) {
        bridgeDays.add(iso(d));
      }
      leaveDays.addAll(((b['leave_dates'] as List?) ?? const []).cast<String>());
    }
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final last = DateTime(now.year + 1, now.month);
    return WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(selectedBackgroundColor: indigo, selectedForegroundColor: Colors.white),
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.today, size: 18), label: Text('Un giorno')),
            ButtonSegment(value: true, icon: Icon(Icons.date_range, size: 18), label: Text('Scegli ferie')),
          ],
          selected: {rangeMode},
          onSelectionChanged: (s) => onMode(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          rangeMode
              ? 'Tocca il primo e l\'ultimo giorno: restano i viaggi interi in quel periodo.'
              : 'Tocca un giorno: restano i viaggi che lo comprendono.',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 10),
        Row(children: [
          IconButton(
            onPressed: month.isAfter(first) ? () => onMonth(DateTime(month.year, month.month - 1)) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(fmtMonth(month),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            onPressed: month.isBefore(last) ? () => onMonth(DateTime(month.year, month.month + 1)) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        _Grid(
          month: month,
          marks: marks,
          bridgeDays: bridgeDays,
          leaveDays: leaveDays,
          day: rangeMode ? null : day,
          from: rangeMode ? from : null,
          to: rangeMode ? to : null,
          onTap: onTap,
        ),
        const SizedBox(height: 10),
        const Wrap(spacing: 14, runSpacing: 6, children: [
          _Legend(color: orange, label: 'Festività', text: true),
          _Legend(color: violet, label: 'Chiusura scuole', dot: true),
          _Legend(color: orangeBg, label: 'Ponte possibile'),
          _Legend(color: orange, label: 'Giorno di ferie', outline: true),
        ]),
        const SizedBox(height: 8),
        ..._bridgesOfMonth(cal, month),
      ]),
    );
  }

  List<Widget> _bridgesOfMonth(Json cal, DateTime month) {
    final items = ((cal['bridges'] as List?) ?? const []).cast<Json>().where((b) {
      final o = day0(b['out'] as String);
      return o.year == month.year && o.month == month.month;
    }).toList();
    if (items.isEmpty) return const [];
    return [
      const Divider(height: 18),
      for (final b in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            const Icon(Icons.celebration_outlined, size: 16, color: orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${fmtDay(b['out'])} – ${fmtDay(b['ret'])} · ${(b['holidays'] as List).join(', ')}',
                  style: const TextStyle(fontSize: 12.5)),
            ),
            leaveTag(b['leave_days'] as num),
          ]),
        ),
    ];
  }
}

DateTime day0(String s) => DateTime.parse(s.substring(0, 10));
String iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _Grid extends StatelessWidget {
  const _Grid({
    required this.month,
    required this.marks,
    required this.bridgeDays,
    required this.leaveDays,
    required this.day,
    required this.from,
    required this.to,
    required this.onTap,
  });
  final DateTime month;
  final Json marks;
  final Set<String> bridgeDays, leaveDays;
  final DateTime? day, from, to;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final today = DateUtils.dateOnly(DateTime.now());
    bool inRange(DateTime d) => from != null && !d.isBefore(from!) && !d.isAfter(to ?? from!);
    final cells = <Widget>[
      for (final l in const ['L', 'M', 'M', 'G', 'V', 'S', 'D'])
        Center(child: Text(l, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600))),
      for (var i = 1; i < first.weekday; i++) const SizedBox(),
      for (var n = 1; n <= days; n++)
        () {
          final d = DateTime(month.year, month.month, n);
          final key = iso(d);
          final mark = marks[key] as Json?;
          final holiday = mark?['kind'] == 'festivita';
          final school = mark?['kind'] == 'scuola';
          final selected = d == day || d == from || d == to;
          final ranged = inRange(d);
          final past = d.isBefore(today);
          Color? bg;
          if (selected) {
            bg = indigo;
          } else if (ranged) {
            bg = const Color(0xFFDDE0F7);
          } else if (bridgeDays.contains(key)) {
            bg = orangeBg;
          }
          return Tooltip(
            message: mark?['name'] as String? ?? '',
            child: InkResponse(
              onTap: past ? null : () => onTap(d),
              radius: 20,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: leaveDays.contains(key) && !selected ? Border.all(color: orange, width: 1.4) : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$n',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: holiday || selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : past
                                ? muted.withValues(alpha: 0.5)
                                : holiday || d.weekday == DateTime.sunday
                                    ? orange
                                    : ink,
                      )),
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: school ? (selected ? Colors.white : violet) : Colors.transparent),
                  ),
                ]),
              ),
            ),
          );
        }(),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.12,
      children: cells,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dot = false, this.outline = false, this.text = false});
  final Color color;
  final String label;
  final bool dot, outline, text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (text)
          Text('8', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))
        else
          Container(
            width: dot ? 6 : 14,
            height: dot ? 6 : 14,
            decoration: BoxDecoration(
              color: outline ? null : color,
              border: outline ? Border.all(color: color, width: 1.4) : null,
              borderRadius: BorderRadius.circular(dot ? 3 : 4),
            ),
          ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: muted)),
      ]);
}
