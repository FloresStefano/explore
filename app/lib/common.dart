import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Palette taken from the reference template: night-blue header, indigo actions,
// lavender page, white cards.
const navy = Color(0xFF15164A);
const indigo = Color(0xFF2E3AA1);
const pageBg = Color(0xFFEDEFFA);
const chipBg = Color(0xFFEEF0F6);
const ink = Color(0xFF14163C);
const muted = Color(0xFF8A8FA8);
const green = Color(0xFF2E9B5B);
const greenBg = Color(0xFFE6F6EC);
const orange = Color(0xFFE08A2B);
const orangeBg = Color(0xFFFFF1E2);
const violet = Color(0xFF6A3FC4);
const violetBg = Color(0xFFEFE8FB);

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
String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String fmtMonth(DateTime d) => cap(_monthFmt.format(d));
String fmtMonthKey(String ym) => fmtMonth(DateTime.parse('$ym-01'));
String fmtMonthShort(String ym) => cap(_monthShort.format(DateTime.parse('$ym-01')));

String hm(String? iso) => iso == null || iso.length < 16 ? '–' : iso.substring(11, 16);
String num1(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
String euro(num v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',')} €';
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
      final t = o['type'] as String? ?? '';
      byType[t] = (byType[t] ?? 0) + 1;
    }
    destinations = dests.length;
  }

  int n = 0;
  int destinations = 0;
  num? minPrice;
  final byType = <String, int>{};
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
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
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

class MonthFilter extends StatelessWidget {
  const MonthFilter({super.key, required this.months, required this.value, required this.onChanged, this.light = false});
  final List<String> months; // yyyy-mm
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool light;

  @override
  Widget build(BuildContext context) => PillRow(children: [
        Pill('Tutti i mesi', selected: value == null, light: light, onTap: () => onChanged(null)),
        for (final m in months) Pill(fmtMonthKey(m), selected: value == m, light: light, onTap: () => onChanged(m)),
      ]);
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
              style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: ink)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (i) => onChanged(items[i].$1),
        itemBuilder: (_) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem<int>(value: i, child: _entry(items[i].$2, items[i].$3, bold: items[i].$1 == value)),
        ],
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, size: 20, color: indigo),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                _entry(current.$2, current.$3),
              ]),
            ),
            const Icon(Icons.expand_more, color: indigo),
          ]),
        ),
      ),
    );
  }
}

/// Kind of break as a combo box.
class TypeBox extends StatelessWidget {
  const TypeBox({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => FilterBox<String>(
        label: 'Tipo di viaggio',
        icon: Icons.luggage_outlined,
        value: value,
        items: [(null, 'Tutti i tipi', null), for (final t in breakTypes) (t, typePlural[t]!, typeColor[t])],
        onChanged: onChanged,
      );
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in breakTypes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (stats.byType[t] ?? 0) > 0 ? typeBg[t] : chipBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${typePlural[t]} ${stats.byType[t] ?? 0}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (stats.byType[t] ?? 0) > 0 ? typeColor[t] : muted)),
          ),
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
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(14)),
                child: Text(badge,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: .5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 7),
                  TypeCounters(stats),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('da', style: TextStyle(fontSize: 11, color: muted)),
                Text(stats.minPrice == null ? '–' : euro(stats.minPrice!),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: indigo)),
                const Icon(Icons.chevron_right, color: muted, size: 20),
              ]),
            ]),
          ),
        ),
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
  const WhiteCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: navy.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6))],
        ),
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

/// Night-blue dotted header with the page content sliding over its lower edge.
/// On wide screens the content uses up to [maxWidth].
class PageShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final wide = isWide(context);
    return ColoredBox(
      color: pageBg,
      child: Stack(children: [
        Container(
          height: (wide ? headerHeight - 30 : headerHeight) + top,
          decoration: BoxDecoration(
            color: navy,
            borderRadius: wide ? null : const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: const CustomPaint(painter: _Dots(), size: Size.infinite),
        ),
        SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(padding: EdgeInsets.fromLTRB(wide ? 24 : 20, wide ? 20 : 14, wide ? 24 : 20, 14), child: header),
                Expanded(child: child),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Dots extends CustomPainter {
  const _Dots();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.07);
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
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kicker, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
            const SizedBox(height: 2),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
          ]),
        ),
        ?action,
      ]);
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon = Icons.cloud_off_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => WhiteCard(
        child: Column(children: [
          Icon(icon, color: muted, size: 32),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        ]),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key, this.onDark = true});
  final bool onDark;

  @override
  Widget build(BuildContext context) =>
      Center(child: CircularProgressIndicator(color: onDark ? Colors.white : indigo));
}
