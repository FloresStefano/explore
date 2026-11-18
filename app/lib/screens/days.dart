import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';

/// Horizontal day carousel (main tab of the Calendar): at least five days in view, each
/// with the lowest price of the trips that include it. Weekends and holidays stand out;
/// tapping a day opens the offers that include it.
class DayStrip extends StatefulWidget {
  const DayStrip({super.key, required this.cal, required this.offers});
  final Json cal;
  final List<Json> offers; // whole catalog: type, price and airline filters apply, the month only scrolls

  @override
  State<DayStrip> createState() => _DayStripState();
}

DateTime _d(String iso) => DateTime.parse(iso.substring(0, 10));
String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Lowest price per day among the offers whose trip includes that day.
Map<String, num> minPriceByDay(List<Json> offers) {
  final out = <String, num>{};
  for (final o in offers) {
    final p = o['price'] as num;
    final b = _d(o['ret_date'] as String);
    for (var d = _d(o['out_date'] as String); !d.isAfter(b); d = d.add(const Duration(days: 1))) {
      final k = _iso(d);
      if (out[k] == null || p < out[k]!) out[k] = p;
    }
  }
  return out;
}

/// Offers whose trip includes [day].
List<Json> offersOn(List<Json> offers, DateTime day) => offers
    .where((o) => !day.isBefore(_d(o['out_date'] as String)) && !day.isAfter(_d(o['ret_date'] as String)))
    .toList();

class _DayStripState extends State<DayStrip> {
  final _scroll = ScrollController();
  static String? _selected; // yyyy-mm-dd, kept while the app is open
  String? _jumpedTo;
  double _itemW = 64;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _page(int dir, int visible) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + dir * (visible - 1) * _itemW).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final f = App.filter;
    final pool = OfferFilter(type: f.type, price: f.price, airline: f.airline).apply(widget.offers);
    final prices = minPriceByDay(pool);
    final marks = (widget.cal['marks'] as Json?) ?? const <String, dynamic>{};
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final lastKey = widget.offers.isEmpty
        ? null
        : widget.offers.map((o) => o['ret_date'] as String).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    if (lastKey == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Nessuna offerta disponibile.', style: TextStyle(color: muted)),
      );
    }
    final count = _d(lastKey).difference(first).inDays + 1;
    final days = [for (var i = 0; i < count; i++) first.add(Duration(days: i))];

    return LayoutBuilder(builder: (context, box) {
      const arrowW = 26.0;
      final listW = box.maxWidth - 2 * arrowW;
      final visible = (listW / 78).floor().clamp(5, 9);
      _itemW = listW / visible;
      // The month combo box scrolls the carousel to that month.
      if (f.month != _jumpedTo) {
        _jumpedTo = f.month;
        final i = f.month == null ? 0 : days.indexWhere((d) => _iso(d).startsWith(f.month!));
        if (i >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.animateTo((i * _itemW).clamp(0.0, _scroll.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
            }
          });
        }
      }
      Widget arrow(IconData icon, int dir) => SizedBox(
            width: arrowW,
            child: InkResponse(
              radius: 18,
              onTap: () => _page(dir, visible),
              child: Icon(icon, color: indigo, size: 26),
            ),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 86,
          child: Row(children: [
            arrow(Icons.chevron_left, -1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemExtent: _itemW,
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final d = days[i];
                  final key = _iso(d);
                  final mark = marks[key] as Json?;
                  return _DayCell(
                    day: d,
                    price: prices[key],
                    holiday: mark?['kind'] == 'festivita' ? mark!['name'] as String? : null,
                    selected: _selected == key,
                    onTap: prices[key] == null
                        ? null
                        : () {
                            setState(() => _selected = key);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CountriesScreen(
                                  section: 'Calendario',
                                  path: ['Giorni', cap(DateFormat('EEEE d MMMM', 'it').format(d))],
                                  offers: offersOn(pool, d),
                                ),
                              ),
                            );
                          },
                  );
                },
              ),
            ),
            arrow(Icons.chevron_right, 1),
          ]),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Wrap(spacing: 14, runSpacing: 4, children: [
            _Legend(bg: _weekendBg, label: 'Sabato e domenica'),
            _Legend(bg: orangeBg, label: 'Festivo', dot: true),
            Text('Prezzo minimo dei viaggi che includono il giorno',
                style: TextStyle(fontSize: 11, color: muted)),
          ]),
        ),
      ]);
    });
  }
}

const _weekendBg = Color(0xFFF1F2FB);

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.price, required this.holiday, required this.selected, this.onTap});
  final DateTime day;
  final num? price;
  final String? holiday;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final weekend = day.weekday >= DateTime.saturday;
    final red = holiday != null || day.weekday == DateTime.sunday;
    final bg = holiday != null ? orangeBg : (weekend ? _weekendBg : Colors.transparent);
    final labelColor = selected ? indigo : (red ? orange : (price == null ? muted : ink));
    final cell = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Stack(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(DateFormat('EEE', 'it').format(day),
                style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w600)),
            Text(DateFormat('d MMM', 'it').format(day),
                style: TextStyle(fontSize: 13, color: labelColor, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (price == null)
              const Icon(Icons.airplanemode_inactive, size: 18, color: Color(0xFFC5C8D6))
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(euro(price!),
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: selected ? indigo : const Color(0xFF2B3480))),
              ),
          ]),
          if (holiday != null)
            Positioned(
              top: 5,
              right: 6,
              child: Container(
                  width: 6, height: 6, decoration: const BoxDecoration(color: orange, shape: BoxShape.circle)),
            ),
          // The selected day is underlined, as in airline date pickers.
          if (selected)
            Positioned(
              left: 6,
              right: 6,
              bottom: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]),
      ),
    );
    return holiday == null ? cell : Tooltip(message: holiday!, child: cell);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.bg, required this.label, this.dot = false});
  final Color bg;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          alignment: Alignment.topRight,
          child: dot
              ? Container(width: 5, height: 5, decoration: const BoxDecoration(color: orange, shape: BoxShape.circle))
              : null,
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      ]);
}
