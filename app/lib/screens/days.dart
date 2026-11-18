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
  double _itemW = 60;
  int _firstVisible = 0;

  @override
  void initState() {
    super.initState();
    // The month label follows the first day in view.
    _scroll.addListener(() {
      final i = (_scroll.offset / _itemW).round();
      if (i != _firstVisible) setState(() => _firstVisible = i);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _page(int dir, int visible) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + dir * (visible - 1) * _itemW).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final f = App.filter;
    final pool = OfferFilter(type: f.type, price: f.price, airline: f.airline).apply(widget.offers);
    final prices = minPriceByDay(pool);
    final cheapest = prices.isEmpty ? null : prices.values.reduce((a, b) => a < b ? a : b);
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
      const arrowW = 34.0;
      final listW = box.maxWidth - 2 * arrowW;
      final visible = (listW / 72).floor().clamp(5, 9);
      _itemW = listW / visible;
      // The month combo box scrolls the carousel to that month.
      if (f.month != _jumpedTo) {
        _jumpedTo = f.month;
        final i = f.month == null ? 0 : days.indexWhere((d) => _iso(d).startsWith(f.month!));
        if (i >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.animateTo((i * _itemW).clamp(0.0, _scroll.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
            }
          });
        }
      }
      final shownMonth = days[_firstVisible.clamp(0, days.length - 1)];
      Widget arrow(IconData icon, int dir) => SizedBox(
            width: arrowW,
            child: Center(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(side: BorderSide(color: Color(0xFFE3E5F0))),
                elevation: 1.5,
                shadowColor: navy.withValues(alpha: 0.25),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _page(dir, visible),
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, color: indigo, size: 20)),
                ),
              ),
            ),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(fmtMonth(shownMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w700, color: navy)),
        ),
        SizedBox(
          height: 96,
          child: Row(children: [
            arrow(Icons.chevron_left_rounded, -1),
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
                  final price = prices[key];
                  return _DayCell(
                    day: d,
                    price: price,
                    best: price != null && price == cheapest,
                    holiday: mark?['kind'] == 'festivita' ? mark!['name'] as String? : null,
                    selected: _selected == key,
                    onTap: price == null
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
            arrow(Icons.chevron_right_rounded, 1),
          ]),
        ),
        const SizedBox(height: 10),
        const Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 4, children: [
          _Legend(bg: _weekendBg, label: 'Weekend'),
          _Legend(bg: orangeBg, label: 'Festivo', dot: true),
          _Legend(bg: Colors.transparent, label: 'Prezzo più basso', text: green),
        ]),
        const SizedBox(height: 2),
      ]);
    });
  }
}

const _weekendBg = Color(0xFFF0F1FA);

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.price,
    required this.best,
    required this.holiday,
    required this.selected,
    this.onTap,
  });
  final DateTime day;
  final num? price;
  final bool best;
  final String? holiday;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final weekend = day.weekday >= DateTime.saturday;
    final festive = holiday != null || day.weekday == DateTime.sunday;
    final empty = price == null;
    final bg = selected
        ? indigo
        : holiday != null
            ? orangeBg
            : weekend
                ? _weekendBg
                : Colors.transparent;
    final dayColor = selected ? Colors.white : (empty ? const Color(0xFFB4B8CB) : (festive ? orange : navy));
    final small = selected ? Colors.white70 : (festive && !empty ? orange : muted);
    final priceColor = selected ? Colors.white : (best ? green : indigo);

    final content = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(DateFormat('EEE', 'it').format(day).toUpperCase(),
          style: TextStyle(fontSize: Fs.caption, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: small)),
      const SizedBox(height: 1),
      Text('${day.day}', style: TextStyle(fontSize: Fs.headline, height: 1.1, fontWeight: FontWeight.w800, color: dayColor)),
      Text(DateFormat('MMM', 'it').format(day), style: TextStyle(fontSize: Fs.caption, color: small)),
      const SizedBox(height: 5),
      SizedBox(
        height: 17,
        child: empty
            ? Icon(Icons.airplanemode_inactive_rounded,
                size: 15, color: selected ? Colors.white54 : const Color(0xFFC9CCDA))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(euro(price!),
                    style: TextStyle(fontSize: Fs.small, fontWeight: FontWeight.w800, color: priceColor)),
              ),
      ),
    ]);

    final cell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Rd.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Rd.md),
          child: Stack(fit: StackFit.expand, children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: content),
            if (holiday != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: selected ? Colors.white : orange, shape: BoxShape.circle),
                ),
              ),
          ]),
        ),
      ),
    );
    return holiday == null ? cell : Tooltip(message: holiday!, child: cell);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.bg, required this.label, this.dot = false, this.text});
  final Color bg;
  final String label;
  final bool dot;
  final Color? text; // a coloured price sample instead of a swatch

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (text != null)
          Text('€', style: TextStyle(fontSize: Fs.label, fontWeight: FontWeight.w800, color: text))
        else
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rd.xs)),
            alignment: Alignment.topRight,
            child: dot
                ? Container(width: 5, height: 5, decoration: const BoxDecoration(color: orange, shape: BoxShape.circle))
                : null,
          ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: Fs.caption, color: muted)),
      ]);
}
