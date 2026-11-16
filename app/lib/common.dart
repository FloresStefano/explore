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

const airportCity = {'VRN': 'Verona', 'BGY': 'Bergamo', 'TSF': 'Treviso'};

final _dayFmt = DateFormat('EEE d MMM', 'it');
final _monthFmt = DateFormat('MMMM yyyy', 'it');

DateTime day(String iso) => DateTime.parse(iso.substring(0, 10));
String fmtDay(String iso) => _dayFmt.format(day(iso));
String fmtMonth(DateTime d) {
  final s = _monthFmt.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String hm(String? iso) => iso == null || iso.length < 16 ? '–' : iso.substring(11, 16);
String num1(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
String euro(num v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',')} €';
String leaveLabel(num v) => v == 0 ? 'Senza ferie' : '${num1(v)} gg ferie';

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? indigo : chipBg,
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

Widget leaveTag(num leave) => leave == 0
    ? const Tag('Senza ferie', color: green, bg: greenBg)
    : Tag(leaveLabel(leave), color: indigo, bg: const Color(0xFFE8EAFB));

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
class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.header, required this.child, this.headerHeight = 190});
  final Widget header;
  final Widget child;
  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: pageBg,
      child: Stack(children: [
        Container(
          height: headerHeight + top,
          decoration: const BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: const CustomPaint(painter: _Dots(), size: Size.infinite),
        ),
        SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 14), child: header),
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
