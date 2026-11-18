import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';
import 'data.dart';
import 'guide.dart';

const _stubHeight = 104.0;

/// Offer card shaped like a boarding pass: notches and a dashed tear line.
/// Actions live in the stub: open the seller, send on WhatsApp, AI tourist card.
class TicketCard extends StatelessWidget {
  const TicketCard(this.o, {super.key});
  final Json o;

  @override
  Widget build(BuildContext context) {
    final airlines = (o['airlines'] as List?)?.join(', ') ?? '';
    final leave = (o['leave_days'] as num?) ?? 0;
    final hours = (o['useful_hours'] as num?) ?? 0;
    final discount = o['discount_pct'] as num?;
    final holidays = (o['holidays'] as List?)?.join(', ');
    return PhysicalShape(
      clipper: const _TicketClipper(),
      color: Colors.white,
      elevation: 2,
      shadowColor: navy.withValues(alpha: 0.22),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: indigo,
                child: Text(airlines.isEmpty ? '?' : airlines[0],
                    style: const TextStyle(color: Colors.white, fontSize: Fs.label, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(airlines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Fs.small, fontWeight: FontWeight.w600, color: ink)),
              ),
              if (o['unmissable'] == true) ...[
                const Tag('Imperdibile', color: orange, bg: orangeBg),
                const SizedBox(width: 6),
              ],
              if (discount != null) ...[
                Tag('-${discount.round()}%', color: orange, bg: orangeBg),
                const SizedBox(width: 6),
              ],
              typeTag(o['type'] as String?),
              const SizedBox(width: 6),
              leaveTag(leave),
            ]),
            const SizedBox(height: 14),
            _Leg(o['outbound'] as Json?, o['out_date'] as String, o['origin'], o['destination'],
                airportCity[o['origin']] ?? o['origin'], o['city'] ?? o['destination']),
            const SizedBox(height: 12),
            _Leg(o['inbound'] as Json?, o['ret_date'] as String, o['destination'], o['origin'],
                o['city'] ?? o['destination'], airportCity[o['origin']] ?? o['origin']),
            if (holidays != null && holidays.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.celebration_outlined, size: 15, color: orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    holidays + (o['needs_parent_leave'] == true ? ' · richiede ferie dei genitori' : ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Fs.label, color: ink),
                  ),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 1, width: double.infinity, child: CustomPaint(painter: _Dashes())),
        SizedBox(
          height: _stubHeight - 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 4),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${o['nights']} notti · ${num1(hours)} ore utili',
                        style: const TextStyle(fontSize: Fs.small, color: ink, fontWeight: FontWeight.w500)),
                    Text('Rilevato ${fmtDay(o['observed_at'] as String)} · ${_fare(o)}',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: Fs.caption, color: muted)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(euro(o['price'] as num),
                      style: const TextStyle(
                          fontSize: Fs.headline, fontWeight: FontWeight.w800, color: indigo, fontFeatures: tabular)),
                ),
              ]),
              const Spacer(),
              Row(children: [
                _Action(Icons.open_in_new, 'Prenota', () => _open(o['link'] as String?), primary: true),
                _Action(Icons.chat_outlined, 'WhatsApp', () => _whatsApp(o)),
                _Action(Icons.auto_awesome_outlined, 'Cosa vedere', () => showGuide(context, o)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  /// "senza bagaglio", or "prezzo indicativo" for sources that are not the airline's own.
  static String _fare(Json o) {
    final f = '${o['fare'] ?? ''}';
    return f.contains('indicativo') ? 'senza bagaglio, prezzo indicativo' : 'senza bagaglio';
  }

  static Future<void> _open(String? link) async {
    if (link == null || link.isEmpty) return;
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  static Future<void> _whatsApp(Json o) async {
    final from = airportCity[o['origin']] ?? o['origin'];
    final to = o['city'] ?? o['destination'];
    String leg(Json? l) => l == null ? '' : ' ${hm(l['departure'])} → ${hm(l['arrival'])}';
    final text = [
      '✈️ $from → $to (${o['country'] ?? ''})',
      'Andata ${fmtDay(o['out_date'])}${leg(o['outbound'])}',
      'Ritorno ${fmtDay(o['ret_date'])}${leg(o['inbound'])}',
      '${typeLabel[o['type']] ?? ''} · ${o['nights']} notti · ${leaveLabel(o['leave_days'] as num)}',
      '${euro(o['price'] as num)} a persona, ${(o['airlines'] as List).join(', ')} '
          '(tariffa base senza bagaglio, rilevata ${fmtDay(o['observed_at'])})',
      o['link'],
    ].join('\n');
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication);
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap, {this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: primary ? indigo : chipBg,
          borderRadius: BorderRadius.circular(Rd.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rd.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: primary ? Colors.white : indigo),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: Fs.label, fontWeight: FontWeight.w600, color: primary ? Colors.white : ink)),
              ]),
            ),
          ),
        ),
      );
}

class _Leg extends StatelessWidget {
  const _Leg(this.leg, this.date, this.from, this.to, this.fromCity, this.toCity);
  final Json? leg;
  final String date;
  final String from, to, fromCity, toCity;

  @override
  Widget build(BuildContext context) {
    Widget side(String code, String city, String? time, CrossAxisAlignment align) => SizedBox(
          width: 92,
          child: Column(crossAxisAlignment: align, children: [
            Text(code, style: const TextStyle(fontSize: Fs.titleLg, fontWeight: FontWeight.w700, color: ink, height: 1.1)),
            Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: Fs.caption, color: muted)),
            const SizedBox(height: 2),
            Text(hm(time), style: const TextStyle(fontSize: Fs.small, fontWeight: FontWeight.w600, color: ink)),
          ]),
        );
    return Row(children: [
      side(from, fromCity, leg?['departure'], CrossAxisAlignment.start),
      Expanded(
        child: Column(children: [
          Text(fmtDay(date), style: const TextStyle(fontSize: Fs.label, fontWeight: FontWeight.w600, color: ink)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.flight, size: 15, color: indigo),
            const Expanded(child: SizedBox(height: 1, child: CustomPaint(painter: _Dashes(color: Color(0xFFB9BDD6))))),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFB9BDD6))),
            ),
          ]),
          const SizedBox(height: 2),
          Text(leg?['flight'] is String && (leg!['flight'] as String).isNotEmpty ? leg!['flight'] : 'Diretto',
              style: const TextStyle(fontSize: Fs.caption, color: muted)),
        ]),
      ),
      side(to, toCity, leg?['arrival'], CrossAxisAlignment.end),
    ]);
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();
  @override
  Path getClip(Size size) {
    final card = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Rd.lg)));
    final y = size.height - _stubHeight;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: 7))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: 7));
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Dashes extends CustomPainter {
  const _Dashes({this.color = const Color(0xFFD5D8E6)});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 10; x < size.width - 10; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3.5, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
