import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

/// Area 2: weekends and bridges month by month, with their cost in leave days.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<(List<Json>, Json)> _data = _load();
  DateTime? _month;
  DateTime? _day;
  int? _leave; // null = all

  Future<(List<Json>, Json)> _load() async => (await App.repo.windows(), await App.repo.patrons());

  /// The local patron day is added on the device, with the same calendar logic
  /// as the job: a working day off lowers the leave cost of the windows over it.
  List<Json> _withPatron(List<Json> windows, Json patrons) {
    final p = patrons[App.prefs.comune] as Json?;
    final md = p?['patron'] as String?;
    if (md == null) return windows;
    return [
      for (final w in windows)
        () {
          final out = day(w['out']), ret = day(w['ret']);
          var leave = (w['leave_days'] as num).toInt();
          var hit = false;
          for (var d = out.add(const Duration(days: 1)); !d.isAfter(ret); d = d.add(const Duration(days: 1))) {
            final same = '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' == md;
            if (same && d.weekday <= 5 && leave > 0) {
              leave--;
              hit = true;
            }
          }
          if (!hit) return w;
          return {
            ...w,
            'leave_days': leave,
            'reason': 'patrono',
            'holidays': [...(w['holidays'] as List? ?? const []), p?['saint'] ?? 'Patrono'],
          };
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.prefs,
      builder: (context, _) => PageShell(
        header: HeaderTitle(
          kicker: 'Weekend e ponti',
          title: 'Calendario',
          action: RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
        ),
        child: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            final raw = snap.data?.$1 ?? const <Json>[];
            if (raw.isEmpty) {
              return ListView(padding: const EdgeInsets.all(16), children: [
                const EmptyNote('Calendario non disponibile al momento.'),
                TextButton(onPressed: () => setState(() => _data = _load()), child: const Text('Riprova')),
              ]);
            }
            final windows = _withPatron(raw, snap.data!.$2);
            final months = <DateTime>{for (final w in windows) DateTime(day(w['out']).year, day(w['out']).month)}.toList()
              ..sort();
            final month = _month ?? months.first;
            final inMonth = windows.where((w) {
              final o = day(w['out']);
              return o.year == month.year && o.month == month.month;
            }).toList();
            final shown = inMonth.where((w) {
              if (_leave != null && w['leave_days'] != _leave) return false;
              if (_day != null && day(w['out']) != _day) return false;
              return true;
            }).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                WhiteCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final m in months)
                          Pill(fmtMonth(m).split(' ').first,
                              selected: m == month,
                              onTap: () => setState(() {
                                    _month = m;
                                    _day = null;
                                  })),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Text(fmtMonth(month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _MonthGrid(
                      month: month,
                      windows: inMonth,
                      selected: _day,
                      onTap: (d) => setState(() => _day = _day == d ? null : d),
                    ),
                    const SizedBox(height: 10),
                    const Row(children: [
                      _Legend(Color(0xFFDDE0F7), 'Break senza ferie'),
                      SizedBox(width: 14),
                      _Legend(indigo, 'Partenze possibili', dot: true),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final (v, label) in const [(null, 'Tutte'), (0, 'Senza ferie'), (1, '1 giorno'), (2, '2 giorni')])
                      _LightPill(label, selected: _leave == v, onTap: () => setState(() => _leave = v)),
                  ]),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  const EmptyNote('Nessuna finestra con questi filtri.', icon: Icons.event_busy_outlined)
                else
                  for (final w in shown) _WindowTile(w),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LightPill extends StatelessWidget {
  const _LightPill(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? indigo : Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : ink)),
            ),
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label, {this.dot = false});
  final Color color;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: dot ? 6 : 14,
          height: dot ? 6 : 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(dot ? 3 : 4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: muted)),
      ]);
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.windows, required this.selected, required this.onTap});
  final DateTime month;
  final List<Json> windows;
  final DateTime? selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final free = <DateTime>{};
    final starts = <DateTime>{};
    for (final w in windows) {
      final out = day(w['out']);
      starts.add(out);
      if (w['leave_days'] == 0) {
        for (var i = 0; i <= (w['nights'] as int); i++) {
          free.add(out.add(Duration(days: i)));
        }
      }
    }
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = <Widget>[
      for (final l in const ['L', 'M', 'M', 'G', 'V', 'S', 'D'])
        Center(child: Text(l, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600))),
      for (var i = 1; i < first.weekday; i++) const SizedBox(),
      for (var d = 1; d <= days; d++)
        () {
          final date = DateTime(month.year, month.month, d);
          final sel = date == selected;
          final start = starts.contains(date);
          return InkResponse(
            onTap: start ? () => onTap(date) : null,
            radius: 20,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: sel ? indigo : (free.contains(date) ? const Color(0xFFDDE0F7) : null),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$d',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: start ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? Colors.white : (start ? ink : muted))),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: start ? (sel ? Colors.white : indigo) : Colors.transparent),
                ),
              ]),
            ),
          );
        }(),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: cells,
    );
  }
}

class _WindowTile extends StatelessWidget {
  const _WindowTile(this.w);
  final Json w;

  @override
  Widget build(BuildContext context) {
    final holidays = (w['holidays'] as List?)?.join(', ') ?? '';
    final out = day(w['out']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OffersScreen.window(w))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(fmtDay(w['out']).split(' ').first.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
                  Text('${out.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.1)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${fmtDay(w['out'])} – ${fmtDay(w['ret'])}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${w['nights']} notti${holidays.isEmpty ? '' : ' · $holidays'}'
                    '${w['needs_parent_leave'] == true ? ' · richiede ferie dei genitori' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ]),
              ),
              leaveTag(w['leave_days'] as num),
              const Icon(Icons.chevron_right, color: muted),
            ]),
          ),
        ),
      ),
    );
  }
}
