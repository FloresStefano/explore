import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';

/// Offers whose departure is within [flex] days of [out] and whose return is within [flex] days of [ret].
List<Json> intervalMatches(List<Json> offers, DateTime out, DateTime ret, int flex) {
  bool near(String iso, DateTime d) => DateTime.parse(iso).difference(d).inDays.abs() <= flex;
  return [
    for (final o in offers)
      if (near(o['out_date'] as String, out) && near(o['ret_date'] as String, ret)) o,
  ]..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
}

/// The first Friday after [today] (today itself if it is a Friday before the weekend starts).
DateTime _nextFriday(DateTime today) {
  final d = DateTime(today.year, today.month, today.day + 1);
  return d.add(Duration(days: (DateTime.friday - d.weekday) % 7));
}

/// "Intervalli": pick a departure and a return date, plus 0-2 days of flexibility on each,
/// and see which of the collected offers fit.
class IntervalCard extends StatefulWidget {
  const IntervalCard({super.key, required this.offers, this.today});
  final List<Json> offers; // the whole catalog: the shared filters are applied here, except the month
  final DateTime? today;

  @override
  State<IntervalCard> createState() => _IntervalCardState();
}

class _IntervalCardState extends State<IntervalCard> {
  // Kept while the app is open, like the selected tab.
  static DateTime? _out, _ret;
  static int _flex = 1;

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void initState() {
    super.initState();
    if (_out == null || _out!.isBefore(_today)) {
      _out = _nextFriday(_today);
      _ret = _out!.add(const Duration(days: 2));
    }
  }

  Future<void> _pick({required bool out}) async {
    final first = out ? _today.add(const Duration(days: 1)) : _out!.add(const Duration(days: 1));
    final last = _today.add(const Duration(days: 365));
    var initial = out ? _out! : _ret!;
    if (initial.isBefore(first)) initial = first;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: out ? 'Data di andata' : 'Data di ritorno',
    );
    if (d == null || !mounted) return;
    setState(() {
      if (out) {
        final nights = _ret!.difference(_out!).inDays;
        _out = d;
        // Moving the departure keeps the trip length.
        _ret = d.add(Duration(days: nights < 1 ? 2 : nights));
      } else {
        _ret = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = App.filter;
    final pool = OfferFilter(type: f.type, price: f.price, airline: f.airline).apply(widget.offers);
    final found = intervalMatches(pool, _out!, _ret!, _flex);
    final wider = _flex < 2 && found.isEmpty ? intervalMatches(pool, _out!, _ret!, 2) : const <Json>[];
    final nights = _ret!.difference(_out!).inDays;
    final label = '${fmtDate(_out!)} → ${fmtDate(_ret!)}${_flex > 0 ? ' ± $_flex' : ''}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 8),
        child: Text('Scegli andata e ritorno: cerco tra le offerte già raccolte',
            style: TextStyle(fontSize: Fs.label, color: muted)),
      ),
      Row(children: [
        Expanded(child: _DateField(label: 'Andata', date: _out!, onTap: () => _pick(out: true))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 18, color: muted),
        ),
        Expanded(child: _DateField(label: 'Ritorno', date: _ret!, onTap: () => _pick(out: false))),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 2, top: 4),
        child: Text(nights == 1 ? '1 notte' : '$nights notti',
            style: const TextStyle(fontSize: Fs.caption, color: muted)),
      ),
      const SizedBox(height: 12),
      const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 6),
        child: Text('Flessibilità su ogni data',
            style: TextStyle(fontSize: Fs.label, fontWeight: FontWeight.w700, color: ink)),
      ),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('Esatte')),
            ButtonSegment(value: 1, label: Text('± 1 giorno')),
            ButtonSegment(value: 2, label: Text('± 2 giorni')),
          ],
          selected: {_flex},
          onSelectionChanged: (s) => setState(() => _flex = s.first),
        ),
      ),
      const SizedBox(height: 14),
      if (found.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nessuna offerta per queste date.', style: TextStyle(color: muted)),
            if (wider.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => setState(() => _flex = 2),
                child: Text('Con ± 2 giorni ce ne sono ${wider.length}: allarga'),
              ),
          ]),
        )
      else
        _ResultRow(label: label, offers: found),
    ]);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Rd.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rd.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rd.md),
              border: Border.all(color: const Color(0xFFDDE0F7)),
            ),
            child: Row(children: [
              const Icon(Icons.event_outlined, size: 18, color: indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: Fs.caption, color: muted)),
                  Text(fmtDate(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w700, color: navy)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// What was found: how many offers, from which price, the cheapest cities; tap to open the list.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.offers});
  final String label;
  final List<Json> offers;

  @override
  Widget build(BuildContext context) {
    final cities = <String>[];
    for (final o in offers) {
      final c = '${o['city'] ?? o['destination']}'.split(' (').first;
      if (!cities.contains(c)) cities.add(c);
      if (cities.length == 3) break;
    }
    final more = {for (final o in offers) o['destination']}.length - cities.length;
    return Material(
      color: const Color(0xFFF7F8FD),
      borderRadius: BorderRadius.circular(Rd.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.md),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OffersScreen(section: 'Calendario', path: ['Intervalli', label], offers: offers),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rd.md),
            border: Border.all(color: const Color(0xFFDDE0F7)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(offers.length == 1 ? '1 offerta' : '${offers.length} offerte',
                    style: const TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w700, color: navy)),
                const SizedBox(height: 2),
                Text('${cities.join(', ')}${more > 0 ? ' e altre $more' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Fs.label, color: muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: orangeBg, borderRadius: BorderRadius.circular(Rd.sm)),
              child: Text('da ${euro(offers.first['price'] as num)}',
                  style: const TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w800, color: orange)),
            ),
            const Icon(Icons.chevron_right, color: muted, size: 20),
          ]),
        ),
      ),
    );
  }
}
