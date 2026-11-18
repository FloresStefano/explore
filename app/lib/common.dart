import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data.dart';

// ---------- design tokens ----------
// One palette in tones of blue: deep navy headers, a clear blue for actions, a cool page
// background and white surfaces. Text colours pass WCAG AA (4.5:1) on white and on pageBg.
const navy = Color(0xFF0E1A47);
const navySoft = Color(0xFF1B2A63); // second stop of the header gradient
const indigo = Color(0xFF2F49C4); // primary: actions, prices, selection
const pageBg = Color(0xFFF1F4FA);
const chipBg = Color(0xFFE8ECF5);
const border = Color(0xFFE1E6F0);
const ink = Color(0xFF101736);
const muted = Color(0xFF5D6483); // secondary text: 5.8:1 on white
const faint = Color(0xFF9AA1BA); // decorative only (icons, chevrons), never body text
const green = Color(0xFF1F8A4C);
const greenBg = Color(0xFFE5F5EC);
const orange = Color(0xFFD9700F);
const orangeBg = Color(0xFFFFF0E0);
const violet = Color(0xFF5B3CC4);
const violetBg = Color(0xFFEEE9FB);

/// Spacing scale (4-point grid).
abstract final class Sp {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
}

/// Corner radii: tags, fields, buttons, cards, sheets.
abstract final class Rd {
  static const xs = 6.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 28.0;
}

/// Type scale: every text in the app uses one of these sizes.
abstract final class Fs {
  static const caption = 11.0, label = 12.0, small = 13.0, body = 14.0, title = 16.0, titleLg = 18.0,
      headline = 22.0, display = 30.0;
}

/// Prices and times line up in columns.
const tabular = [FontFeature.tabularFigures()];

/// Two elevations only: resting cards and floating elements.
final shadowSm = [BoxShadow(color: navy.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))];
final shadowMd = [BoxShadow(color: navy.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))];

/// Standard motion.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150), medium = Duration(milliseconds: 250),
      slow = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
}

/// Wide layout (side menu, multi-column lists) from this width on.
const wideBreakpoint = 900.0;
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;

const airportCity = {'VRN': 'Verona', 'BGY': 'Bergamo', 'TSF': 'Treviso'};

// ---------- kinds of break ----------

/// Weekend: no leave. Weekend+: one leave day (Friday or Monday). Ponte: around a holiday.
const breakTypes = ['weekend', 'weekend+', 'ponte'];
const typeLabel = {'weekend': 'Weekend', 'weekend+': 'Weekend+', 'ponte': 'Ponte'};
const typePlural = {'weekend': 'Weekend', 'weekend+': 'Weekend+', 'ponte': 'Ponti'};
const typeColor = {'weekend': green, 'weekend+': indigo, 'ponte': orange};
const typeBg = {'weekend': greenBg, 'weekend+': Color(0xFFE8EAFB), 'ponte': orangeBg};

// ---------- formatting ----------

final _dayFmt = DateFormat('EEE d MMM', 'it');
final _monthFmt = DateFormat('MMMM yyyy', 'it');
final _monthShort = DateFormat('MMM', 'it');
final _dateTimeFmt = DateFormat("EEE d MMM 'alle' HH:mm", 'it');

DateTime day(String iso) => DateTime.parse(iso.substring(0, 10));
String fmtDay(String iso) => _dayFmt.format(day(iso));
String fmtDate(DateTime d) => _dayFmt.format(d);
String fmtDateTime(DateTime d) => _dateTimeFmt.format(d);
extension IfEmpty on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String fmtMonth(DateTime d) => cap(_monthFmt.format(d));
String fmtMonthKey(String ym) => fmtMonth(DateTime.parse('$ym-01'));
String fmtMonthShort(String ym) => cap(_monthShort.format(DateTime.parse('$ym-01')));

String hm(String? iso) => iso == null || iso.length < 16 ? '–' : iso.substring(11, 16);
String num1(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
String euro(num v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',')}\u00A0€';
String leaveLabel(num v) => v == 0 ? 'Senza ferie' : v == 1 ? '1 giorno di ferie' : '${num1(v)} giorni di ferie';
String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes} min fa';
  if (d.inHours < 24) return '${d.inHours} ore fa';
  return '${d.inDays} giorni fa';
}

// ---------- aggregation ----------

/// Minimum price and counters by kind of break over a set of offers.
class Stats {
  Stats(Iterable<Map<String, dynamic>> offers) {
    final dests = <String>{};
    for (final o in offers) {
      n++;
      dests.add(o['destination'] as String);
      final p = o['price'] as num;
      if (minPrice == null || p < minPrice!) minPrice = p;
      if (maxPrice == null || p > maxPrice!) maxPrice = p;
      final t = o['type'] as String? ?? '';
      byType[t] = (byType[t] ?? 0) + 1;
    }
    destinations = dests.length;
  }

  int n = 0;
  int destinations = 0;
  num? minPrice;
  num? maxPrice;
  final byType = <String, int>{};
}

/// Head of a detail list: the choice just made, highlighted as a path
/// (e.g. Dicembre 2026 › Italia), the shared filters in force, then what the list holds.
class ChoiceRecap extends StatelessWidget {
  const ChoiceRecap({super.key, required this.path, required this.offers});
  final List<String> path;
  final List<Map<String, dynamic>> offers;

  @override
  Widget build(BuildContext context) {
    final stats = Stats(offers);
    final countries = {for (final o in offers) o['country']}.length;
    final filters = filterLabel('');
    String n(int v, String one, String many) => '$v ${v == 1 ? one : many}';
    final facts = [
      if (countries > 1) n(countries, 'paese', 'paesi'),
      n(stats.destinations, 'meta', 'mete'),
      n(stats.n, 'offerta', 'offerte'),
    ].join(' · ');
    final range = stats.minPrice == null
        ? '–'
        : stats.minPrice == stats.maxPrice
            ? euro(stats.minPrice!)
            : '${euro(stats.minPrice!)} – ${euro(stats.maxPrice!)}';
    return WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LA TUA SCELTA',
            style: TextStyle(fontSize: Fs.caption, letterSpacing: 0.8, color: muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < path.length; i++) ...[
            if (i > 0) const Icon(Icons.chevron_right, size: 18, color: muted),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: i == path.length - 1 ? indigo : const Color(0xFFE8EAFB),
                borderRadius: BorderRadius.circular(Rd.xl),
              ),
              child: Text(path[i],
                  style: TextStyle(
                      fontSize: Fs.title,
                      fontWeight: FontWeight.w700,
                      color: i == path.length - 1 ? Colors.white : indigo)),
            ),
          ],
        ]),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.filter_alt_outlined, size: 15, color: muted),
            const SizedBox(width: 4),
            Expanded(child: Text(filters, style: const TextStyle(fontSize: Fs.small, color: muted))),
          ]),
        ],
        const Divider(height: 22),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(facts, style: const TextStyle(fontSize: Fs.body, color: ink, fontWeight: FontWeight.w500))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('prezzi', style: TextStyle(fontSize: Fs.caption, color: muted)),
            Text(range, style: const TextStyle(fontSize: Fs.titleLg, fontWeight: FontWeight.w700, color: indigo)),
          ]),
        ]),
      ]),
    );
  }
}

// ---------- widgets ----------

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.selected, required this.onTap, this.light = false, this.color});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool light; // on the lavender page instead of inside a white card
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final on = color ?? indigo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? on : (light ? Colors.white : chipBg),
        borderRadius: BorderRadius.circular(Rd.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rd.xl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Text(label,
                style: TextStyle(
                    fontSize: Fs.small,
                    fontWeight: FontWeight.w600,
                    color: onTap == null ? muted : (selected ? Colors.white : ink))),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of pills that scrolls on narrow screens.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: children));
}

/// "Tutti, Weekend, Weekend+, Ponti" filter; `reversed` puts Ponti first (calendar).
class TypeFilter extends StatelessWidget {
  const TypeFilter({super.key, required this.value, required this.onChanged, this.reversed = false, this.light = false});
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool reversed;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final items = <(String?, String)>[(null, 'Tutti'), for (final t in breakTypes) (t, typePlural[t]!)];
    return PillRow(children: [
      for (final (v, label) in reversed ? items.reversed : items)
        Pill(label, selected: value == v, light: light, color: v == null ? null : typeColor[v], onTap: () => onChanged(v)),
    ]);
  }
}

/// Labelled drop-down (combo box) on a white rounded field.
class FilterBox<T> extends StatelessWidget {
  const FilterBox({super.key, required this.label, required this.icon, required this.value, required this.items, required this.onChanged});
  final String label;
  final IconData icon;
  final T? value;
  final List<(T?, String, Color?)> items;
  final ValueChanged<T?> onChanged;

  static Widget _entry(String text, Color? color, {bool bold = false}) => Row(children: [
        if (color != null) ...[
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Fs.body, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: ink)),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final current = items.firstWhere((e) => e.$1 == value, orElse: () => items.first);
    return LayoutBuilder(
      builder: (context, box) => PopupMenuButton<int>(
        tooltip: label,
        position: PopupMenuPosition.under,
        color: Colors.white,
        constraints: BoxConstraints(minWidth: box.maxWidth, maxWidth: box.maxWidth),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
        onSelected: (i) {
          HapticFeedback.selectionClick();
          onChanged(items[i].$1);
        },
        itemBuilder: (_) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem<int>(value: i, child: _entry(items[i].$2, items[i].$3, bold: items[i].$1 == value)),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.sm, Sp.sm),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Rd.md),
            border: Border.all(color: border),
            boxShadow: shadowSm,
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: indigo),
            const SizedBox(width: Sp.sm + 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Fs.caption, color: muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                _entry(current.$2, current.$3),
              ]),
            ),
            const Icon(Icons.expand_more_rounded, color: muted, size: 20),
          ]),
        ),
      ),
    );
  }
}

/// Kind of break as a combo box.
class TypeBox extends StatelessWidget {
  const TypeBox({super.key, required this.value, required this.onChanged, this.reversed = false});
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool reversed; // Ponti first (calendar)

  @override
  Widget build(BuildContext context) {
    final items = <(String?, String, Color?)>[
      (null, 'Tutti i tipi', null),
      for (final t in breakTypes) (t, typePlural[t]!, typeColor[t]),
    ];
    return FilterBox<String>(
      label: 'Tipo di viaggio',
      icon: Icons.luggage_outlined,
      value: value,
      items: reversed ? items.reversed.toList() : items,
      onChanged: onChanged,
    );
  }
}

/// Price band as a combo box.
class PriceBox extends StatelessWidget {
  const PriceBox({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => FilterBox<String>(
        label: 'Fascia di prezzo',
        icon: Icons.euro,
        value: value,
        items: [
          (null, 'Tutti i prezzi', null),
          for (final e in priceBands.entries) (e.key, '${e.value.$1 < 0 ? 0 : e.value.$1}–${e.value.$2}\u00A0€', null),
        ],
        onChanged: onChanged,
      );
}

/// Airline as a combo box.
class AirlineBox extends StatelessWidget {
  const AirlineBox({super.key, required this.airlines, required this.value, required this.onChanged});
  final List<String> airlines;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => FilterBox<String>(
        label: 'Compagnia',
        icon: Icons.airlines,
        // Keep a choice made elsewhere even if these offers do not have it.
        value: value,
        items: [
          (null, 'Tutte le compagnie', null),
          for (final a in {...airlines, ?value}.toList()..sort()) (a, a, null),
        ],
        onChanged: onChanged,
      );
}

/// The four combo boxes (kind of break, departure month, price band, airline). They
/// edit App.filter, so the choice is the same in Home, Calendar and Map.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.months, this.airlines = const [], this.reversed = false});
  final List<String> months;
  final List<String> airlines;
  final bool reversed;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: App.filter, builder: (context, _) => _bar());

  Widget _bar() {
    final f = App.filter;
    final type = TypeBox(value: f.type, reversed: reversed, onChanged: f.setType);
    final month = MonthBox(months: months, value: f.month, onChanged: f.setMonth);
    final price = PriceBox(value: f.price, onChanged: f.setPrice);
    final airline = AirlineBox(airlines: airlines, value: f.airline, onChanged: f.setAirline);
    const gap = SizedBox(width: 10, height: 10);
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 860
          ? Row(children: [
              Expanded(child: type), gap, Expanded(child: month), gap, Expanded(child: price), gap,
              Expanded(child: airline),
            ])
          // Narrower screens: two rows of two.
          : Column(children: [
              Row(children: [Expanded(child: type), gap, Expanded(child: month)]),
              gap,
              Row(children: [Expanded(child: price), gap, Expanded(child: airline)]),
            ]),
    );
  }
}

/// "Ponti · Dicembre 2026 · 50–100 €" for the shared filter, or [fallback].
String filterLabel([String fallback = 'Tutte le offerte']) {
  final f = App.filter;
  final band = priceBands[f.price];
  return [
    if (f.type != null) typePlural[f.type],
    if (f.month != null) fmtMonthKey(f.month!),
    if (band != null) '${band.$1 < 0 ? 0 : band.$1}–${band.$2}\u00A0€',
    ?f.airline,
  ].join(' · ').ifEmpty(fallback);
}

/// Departure month as a combo box.
class MonthBox extends StatelessWidget {
  const MonthBox({super.key, required this.months, required this.value, required this.onChanged});
  final List<String> months;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => FilterBox<String>(
        label: 'Mese di partenza',
        icon: Icons.event_outlined,
        value: months.contains(value) ? value : null,
        items: [(null, 'Tutti i mesi', null), for (final m in months) (m, fmtMonthKey(m), null)],
        onChanged: onChanged,
      );
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color = indigo, this.bg = chipBg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rd.xs)),
        child: Text(label,
            style: TextStyle(fontSize: Fs.caption, fontWeight: FontWeight.w600, color: color, height: 1.3)),
      );
}

Widget typeTag(String? type) =>
    Tag(typeLabel[type] ?? '?', color: typeColor[type] ?? muted, bg: typeBg[type] ?? chipBg);

Widget leaveTag(num leave) => leave == 0
    ? const Tag('Senza ferie', color: green, bg: greenBg)
    : Tag(leave == 1 ? '1 g ferie' : '${num1(leave)} gg ferie', color: ink, bg: chipBg);

/// The three counters (weekend, weekend+, ponti) shown on every aggregate card.
class TypeCounters extends StatelessWidget {
  const TypeCounters(this.stats, {super.key});
  final Stats stats;

  @override
  Widget build(BuildContext context) => Wrap(spacing: Sp.xs + 2, runSpacing: Sp.xs + 2, children: [
        for (final t in breakTypes)
          if ((stats.byType[t] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: typeBg[t], borderRadius: BorderRadius.circular(Rd.xs)),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${stats.byType[t]} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: typePlural[t]),
                ]),
                style: TextStyle(fontSize: Fs.caption, fontWeight: FontWeight.w600, color: typeColor[t], height: 1.3),
              ),
            ),
      ]);
}

/// The one card of the app: white surface, same radius, padding and press feedback everywhere.
/// When tappable it sinks slightly under the finger (scale 0.98) besides the ink ripple.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Sp.lg)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Rd.xl);
    return AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: Motion.fast,
      curve: Motion.curve,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: shadowSm),
        child: Material(
          color: Colors.white,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: widget.onTap == null ? null : (v) => setState(() => _down = v),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Price with "da" above it, figures in columns.
class PriceFrom extends StatelessWidget {
  const PriceFrom(this.price, {super.key, this.label = 'da'});
  final num? price;
  final String label;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: Fs.caption, color: muted, fontWeight: FontWeight.w500)),
        Text(price == null ? '–' : euro(price!),
            style: const TextStyle(
                fontSize: Fs.titleLg, fontWeight: FontWeight.w800, color: indigo, fontFeatures: tabular, height: 1.2)),
      ]);
}

/// Card of an aggregate (country, month, destination): name, counters, minimum price.
class AggregateCard extends StatelessWidget {
  const AggregateCard({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.onTap,
  });
  final String badge;
  final String title;
  final String subtitle;
  final Stats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Sp.lg - 2),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(Rd.md)),
            child: Text(badge,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: Fs.small, letterSpacing: .5)),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: Fs.label, color: muted)),
              const SizedBox(height: Sp.sm),
              TypeCounters(stats),
            ]),
          ),
          const SizedBox(width: Sp.sm),
          PriceFrom(stats.minPrice),
        ]),
      );
}

/// Lazy list that lays items out in 1, 2 or 3 columns depending on the width.
class ResponsiveList extends StatelessWidget {
  const ResponsiveList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.header = const [],
    this.minItemWidth = 360,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
    this.spacing = 12,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final List<Widget> header;
  final double minItemWidth;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth - padding.horizontal;
        final cols = (width / minItemWidth).floor().clamp(1, 3);
        final rows = (itemCount / cols).ceil();
        return ListView.builder(
          padding: padding,
          itemCount: header.length + rows,
          itemBuilder: (context, i) {
            if (i < header.length) return header[i];
            final r = i - header.length;
            return Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) SizedBox(width: spacing),
                  Expanded(child: r * cols + c < itemCount ? itemBuilder(context, r * cols + c) : const SizedBox()),
                ],
              ]),
            );
          },
        );
      });
}

class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child, this.padding = const EdgeInsets.all(Sp.lg)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Rd.xl), boxShadow: shadowSm),
        child: child,
      );
}

class RoundIcon extends StatelessWidget {
  const RoundIcon(this.icon, {super.key, this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
}

/// Night-blue header. The title sits in a fixed bar; below it a decorative band reaches
/// behind the first content (the filters) and scrolls away with it, so nothing ever floats
/// over an empty band. Once the band is gone the bar keeps a soft shadow over the content.
class PageShell extends StatefulWidget {
  const PageShell({
    super.key,
    required this.header,
    required this.child,
    this.headerHeight = 190,
    this.maxWidth = 1240,
  });
  final Widget header;
  final Widget child;
  final double headerHeight;
  final double maxWidth;

  @override
  State<PageShell> createState() => _PageShellState();
}

class _PageShellState extends State<PageShell> {
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool _onScroll(Notification n) {
    final metrics = switch (n) {
      ScrollNotification(:final metrics, :final depth) when depth == 0 => metrics,
      ScrollMetricsNotification(:final metrics, :final depth) when depth == 0 => metrics,
      _ => null,
    };
    if (metrics != null && metrics.axis == Axis.vertical) _offset.value = math.max(0, metrics.pixels);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final wide = isWide(context);
    final barInner = wide ? 76.0 : 64.0;
    final bar = top + barInner;
    final full = math.max(bar, (wide ? widget.headerHeight - 30 : widget.headerHeight) + top);
    return ColoredBox(
      color: pageBg,
      child: NotificationListener<Notification>(
        onNotification: _onScroll,
        child: Stack(children: [
          ValueListenableBuilder(
            valueListenable: _offset,
            builder: (context, off, _) {
              final h = math.max(bar, full - off);
              final docked = h <= bar + 0.5;
              return Container(
                height: h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [navy, navySoft],
                  ),
                  borderRadius: wide ? null : BorderRadius.vertical(bottom: Radius.circular(docked ? Rd.xl : Rd.xxl)),
                  boxShadow: docked ? shadowMd : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: const CustomPaint(painter: _Dots(), size: Size.infinite),
              );
            },
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: barInner,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? Sp.xl : Sp.lg + 4),
                      child: Align(alignment: Alignment.centerLeft, child: widget.header),
                    ),
                  ),
                  // Content scrolls under the bar, never over it.
                  Expanded(child: ClipRect(child: widget.child)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Dots extends CustomPainter {
  const _Dots();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (double y = 6; y < size.height; y += 9) {
      for (double x = (y ~/ 9).isEven ? 4 : 8.5; x < size.width; x += 9) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HeaderTitle extends StatelessWidget {
  const HeaderTitle({super.key, required this.kicker, required this.title, this.action, this.leading});
  final String kicker;
  final String title;
  final Widget? action;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: Sp.md)],
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kicker.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: Fs.caption,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: Fs.headline, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ]),
        ),
        ?action,
      ]);
}

/// Header height of Home, Calendar and Map: the navy band ends behind the filters.
const sectionHeaderHeight = 150.0;

/// "28 paesi · 1544 offerte" under the filters of Home, Calendar and Map.
class CountLine extends StatelessWidget {
  const CountLine(this.text, {super.key});
  final String text;

  // The numbers change with the filters: a short cross-fade instead of a jump.
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: Sp.xs, top: Sp.xs, bottom: Sp.md),
        child: AnimatedSwitcher(
          duration: Motion.medium,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
          child: Text(text,
              key: ValueKey(text),
              style: const TextStyle(
                  fontSize: Fs.small, color: muted, fontWeight: FontWeight.w600, fontFeatures: tabular)),
        ),
      );
}

/// Empty or error state: icon, a short title, a hint and, when useful, one action.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text,
      {super.key, this.icon = Icons.cloud_off_outlined, this.title, this.actionLabel, this.onAction});
  final String text;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// "No offer with these filters", with the button that clears them.
  factory EmptyNote.filtered({Key? key, String text = 'Prova ad allargare la ricerca o ad azzerare i filtri.'}) =>
      EmptyNote(text,
          key: key,
          icon: Icons.filter_alt_off_outlined,
          title: 'Nessuna offerta con questi filtri',
          actionLabel: App.filter.isActive ? 'Azzera filtri' : null,
          onAction: App.filter.isActive ? App.filter.clear : null);

  @override
  Widget build(BuildContext context) => WhiteCard(
        padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, Sp.xl),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: chipBg, shape: BoxShape.circle),
            child: Icon(icon, color: indigo, size: 24),
          ),
          const SizedBox(height: Sp.md),
          if (title != null) ...[
            Text(title!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: Sp.xs),
          ],
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: Fs.body, color: muted, height: 1.45)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Sp.lg),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      );
}

/// Loading placeholder shaped like the page that is coming: filters, a count line, cards.
/// A soft shimmer runs across it; much calmer than a spinner.
class Loading extends StatefulWidget {
  const Loading({super.key, this.onDark = true, this.filters = true});
  final bool onDark;
  final bool filters;

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h, {double r = Rd.xs}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final card = WhiteCard(
      child: Row(children: [
        _bar(44, 44, r: Rd.md),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(120, 14),
            const SizedBox(height: Sp.sm),
            _bar(90, 10),
            const SizedBox(height: Sp.md),
            Row(children: [_bar(64, 16), const SizedBox(width: 6), _bar(72, 16)]),
          ]),
        ),
        _bar(56, 20),
      ]),
    );
    final field = Container(
      height: 54,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(Rd.md), border: Border.all(color: border)),
    );
    return Semantics(
      label: 'Caricamento',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, -0.2),
            end: Alignment(-0.5 + 3 * _c.value, 0.2),
            colors: [Colors.transparent, Colors.white.withValues(alpha: 0.55), Colors.transparent],
          ).createShader(rect),
          child: child,
        ),
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.xl),
          children: [
            if (widget.filters) ...[
              wide
                  ? Row(children: [
                      for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: Sp.md), Expanded(child: field)]
                    ])
                  : Column(children: [
                      Row(children: [Expanded(child: field), const SizedBox(width: Sp.md), Expanded(child: field)]),
                      const SizedBox(height: Sp.md),
                      Row(children: [Expanded(child: field), const SizedBox(width: Sp.md), Expanded(child: field)]),
                    ]),
              const SizedBox(height: Sp.lg),
              Padding(padding: const EdgeInsets.only(left: Sp.xs), child: Align(alignment: Alignment.centerLeft, child: _bar(140, 12))),
              const SizedBox(height: Sp.md),
            ],
            for (var i = 0; i < 6; i++) ...[card, const SizedBox(height: Sp.md)],
          ],
        ),
      ),
    );
  }
}

/// Tabs drawn as a segmented control (Calendario: Giorni / Ponti; Pazzie: Piccole / Medie / Grandi).
class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.tabs, required this.selected, required this.onChanged, this.bg = chipBg});
  final List<(IconData, String)> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rd.md)),
      child: Row(children: [
        for (final (i, (icon, label)) in tabs.indexed)
          Expanded(
            child: Material(
              color: selected == i ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(Rd.sm),
              elevation: selected == i ? 1 : 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(Rd.sm),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, size: 17, color: selected == i ? indigo : muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: Fs.body,
                              fontWeight: selected == i ? FontWeight.w700 : FontWeight.w600,
                              color: selected == i ? indigo : muted)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
