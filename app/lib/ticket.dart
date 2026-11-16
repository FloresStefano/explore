import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';
import 'data.dart';

const _stubHeight = 58.0;

/// Offer card shaped like a boarding pass: notches and a dashed tear line.
class TicketCard extends StatelessWidget {
  const TicketCard(this.o, {super.key});
  final Json o;

  @override
  Widget build(BuildContext context) {
    final airlines = (o['airlines'] as List?)?.join(', ') ?? '';
    final leave = (o['leave_days'] as num?) ?? 0;
    final hours = (o['useful_hours'] as num?) ?? 0;
    final discount = o['discount_pct'] as num?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PhysicalShape(
        clipper: const _TicketClipper(),
        color: Colors.white,
        elevation: 3,
        shadowColor: navy.withValues(alpha: 0.35),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(o['link'] as String?),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: indigo,
                    child: Text(airlines.isEmpty ? '?' : airlines[0],
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(airlines,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink)),
                  ),
                  if (o['unmissable'] == true) ...[
                    const Tag('Imperdibile', color: orange, bg: orangeBg),
                    const SizedBox(width: 6),
                  ],
                  if (discount != null) ...[
                    Tag('-${discount.round()}%', color: orange, bg: orangeBg),
                    const SizedBox(width: 6),
                  ],
                  leaveTag(leave),
                ]),
                const SizedBox(height: 14),
                _Leg(o['outbound'] as Json?, o['out_date'] as String, o['origin'], o['destination'],
                    airportCity[o['origin']] ?? o['origin'], o['city'] ?? o['destination']),
                const SizedBox(height: 12),
                _Leg(o['inbound'] as Json?, o['ret_date'] as String, o['destination'], o['origin'],
                    o['city'] ?? o['destination'], airportCity[o['origin']] ?? o['origin']),
              ]),
            ),
            const SizedBox(
              height: 1,
              width: double.infinity,
              child: CustomPaint(painter: _Dashes()),
            ),
            SizedBox(
              height: _stubHeight - 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.wb_sunny_outlined, size: 18, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${o['nights']} notti · ${num1(hours)} ore utili',
                            style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500)),
                        Text('Rilevato ${fmtDay(o['observed_at'] as String)} · senza bagaglio',
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: muted)),
                      ],
                    ),
                  ),
                  Text(euro(o['price'] as num),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: indigo)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static Future<void> _open(String? link) async {
    if (link == null || link.isEmpty) return;
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }
}

class _Leg extends StatelessWidget {
  const _Leg(this.leg, this.date, this.from, this.to, this.fromCity, this.toCity);
  final Json? leg;
  final String date;
  final String from, to, fromCity, toCity;

  @override
  Widget build(BuildContext context) {
    Widget side(String code, String city, String? time, CrossAxisAlignment align) => SizedBox(
          width: 86,
          child: Column(crossAxisAlignment: align, children: [
            Text(code, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink, height: 1.1)),
            Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: muted)),
            const SizedBox(height: 2),
            Text(hm(time), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink)),
          ]),
        );
    return Row(children: [
      side(from, fromCity, leg?['departure'], CrossAxisAlignment.start),
      Expanded(
        child: Column(children: [
          Text(fmtDay(date), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ink)),
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
          const Text('Diretto', style: TextStyle(fontSize: 10.5, color: muted)),
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
    final card = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
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
