import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common.dart';
import 'home_hero.dart';

/// The three small illustrations of the Home lines, in the paper-cut style of the hero.
enum LineArt { calendar, routes, ticket }

/// A 52x52 paper tile with its illustration.
class LineArtTile extends StatelessWidget {
  const LineArtTile(this.art, {super.key, this.size = 52});
  final LineArt art;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ArtPainter(art)),
      );
}

/// Barely-there background of the Home blocks: a field of blue with a white trail sweeping in
/// from the left and ending at the tail of a white plane flying up to the right. Everything is
/// measured on the card height and anchored to the right edge, so it never stretches.
class SwooshPainter extends CustomPainter {
  const SwooshPainter({this.color = const Color(0xFF4F8CCB), this.opacity = 0.085});
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final len = h * 0.95; // plane length
    const angle = 0.95; // nose up and to the right
    final nose = Offset(math.sin(angle), -math.cos(angle));
    final plane = Offset(w - h * 0.5, h * 0.44);
    final tail = plane - nose * (len * 0.44);
    final field = Path()
      ..moveTo(tail.dx - h * 1.25, -2)
      ..cubicTo(tail.dx - h * 1.05, h * 0.55, tail.dx - h * 0.45, tail.dy + 2, tail.dx, tail.dy)
      ..cubicTo(tail.dx - h * 0.12, tail.dy + h * 0.18, tail.dx - h * 0.32, h * 0.9, tail.dx - h * 0.48, h + 2)
      ..lineTo(w + 2, h + 2)
      ..lineTo(w + 2, -2)
      ..close();
    canvas.drawPath(field, Paint()..color = color.withValues(alpha: opacity));
    // The plane is the card's own white, cut out of the blue.
    canvas.save();
    canvas.translate(plane.dx, plane.dy);
    canvas.rotate(angle);
    canvas.scale(len / 230);
    canvas.translate(-100, -115);
    canvas.drawPath(PlaneArt.silhouette, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SwooshPainter old) => old.color != color || old.opacity != opacity;
}

final _soft = Paint()
  ..color = const Color(0xFF0B1E45).withValues(alpha: 0.16)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

class _ArtPainter extends CustomPainter {
  const _ArtPainter(this.art);
  final LineArt art;

  // Tile tints per illustration: light top, deeper bottom, and a hill of paper.
  static const _tints = {
    LineArt.calendar: (Color(0xFFEAF0FD), Color(0xFFD3DEFA), Color(0xFFBCCDF6)),
    LineArt.routes: (Color(0xFFE6F6EE), Color(0xFFCDEBDB), Color(0xFFB2DFC6)),
    LineArt.ticket: (Color(0xFFFFF3E5), Color(0xFFFFE2C2), Color(0xFFFFCF9C)),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.scale(s / 52);
    final tile = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 52, 52), const Radius.circular(15));
    final (top, bottom, hill) = _tints[art]!;
    canvas.drawRRect(
        tile,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom])
              .createShader(const Rect.fromLTWH(0, 0, 52, 52)));
    canvas.save();
    canvas.clipRRect(tile);
    // A hill of paper across the bottom, with its shadow: the hero's landscape in miniature.
    final hillPath = Path()
      ..moveTo(0, 40)
      ..cubicTo(12, 32, 22, 44, 34, 38)
      ..cubicTo(42, 34, 48, 36, 52, 38)
      ..lineTo(52, 52)
      ..lineTo(0, 52)
      ..close();
    canvas.drawPath(hillPath.shift(const Offset(0, -1.5)), _soft);
    canvas.drawPath(hillPath, Paint()..color = hill);
    switch (art) {
      case LineArt.calendar:
        _calendar(canvas);
      case LineArt.routes:
        _routes(canvas);
      case LineArt.ticket:
        _ticket(canvas);
    }
    canvas.restore();
  }

  /// A desk calendar: the weekend columns (Fri, Sat, Sun) stand out.
  void _calendar(Canvas canvas) {
    const page = Rect.fromLTWH(11, 12, 30, 29);
    final rr = RRect.fromRectAndRadius(page, const Radius.circular(5));
    canvas.drawRRect(rr.shift(const Offset(1.5, 2.5)), _soft);
    canvas.drawRRect(rr, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(const Rect.fromLTWH(11, 12, 30, 7), Paint()..color = indigo);
    canvas.restore();
    final ring = Paint()..color = navy;
    for (final x in [18.0, 34.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.2, 9.5, 2.4, 6), const Radius.circular(1.2)), ring);
    }
    // 3 weeks x 5 days (Wed..Sun): the last three days are the weekend.
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 5; col++) {
        final cell = Rect.fromLTWH(14.0 + col * 5, 22.5 + row * 5.6, 3.6, 3.6);
        final Color c = switch (col) {
          2 => const Color(0xFFB9C8F5), // Friday evening
          3 || 4 => indigo,
          _ => const Color(0xFFDCE2EE),
        };
        canvas.drawRRect(RRect.fromRectAndRadius(cell, const Radius.circular(1)), Paint()..color = c);
      }
    }
  }

  /// Three departure points; dotted routes meet at a plane flying away.
  void _routes(Canvas canvas) {
    const origins = [Offset(10, 38), Offset(19, 43), Offset(28, 39)];
    const plane = Offset(37, 15);
    final dot = Paint()..color = green;
    for (final o in origins) {
      final path = Path()
        ..moveTo(o.dx, o.dy)
        ..quadraticBezierTo(o.dx + 2, plane.dy + 6, plane.dx - 4, plane.dy + 5);
      for (final m in path.computeMetrics()) {
        for (double d = 3; d < m.length - 2; d += 3.4) {
          canvas.drawCircle(m.getTangentForOffset(d)!.position, 0.75, dot);
        }
      }
    }
    for (final o in origins) {
      canvas.drawCircle(o + const Offset(0.6, 1), 3.4, _soft);
      canvas.drawCircle(o, 3.4, Paint()..color = Colors.white);
      canvas.drawCircle(o, 1.6, Paint()..color = green);
    }
    // The hero's plane, small, heading up and to the right, with its shadow on the paper.
    const k = 0.13;
    canvas.save();
    canvas.translate(plane.dx + 2.5, plane.dy + 3.5);
    canvas.rotate(math.pi / 4);
    canvas.scale(k);
    canvas.translate(-100, -115);
    canvas.drawPath(
        PlaneArt.silhouette,
        Paint()
          ..color = const Color(0xFF0B3A24).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.restore();
    canvas.save();
    canvas.translate(plane.dx, plane.dy);
    canvas.rotate(math.pi / 4);
    canvas.scale(k);
    canvas.translate(-100, -115);
    PlaneArt.paint(canvas);
    canvas.restore();
  }

  /// A cheap ticket: notches, a perforated stub and the price.
  void _ticket(Canvas canvas) {
    canvas.save();
    canvas.translate(26, 25);
    canvas.rotate(-0.22);
    const body = Rect.fromLTWH(-17, -10, 34, 20);
    final shape = Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(3.5))),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(6, -10), radius: 2.6))
        ..addOval(Rect.fromCircle(center: const Offset(6, 10), radius: 2.6)),
    );
    canvas.drawPath(shape.shift(const Offset(1.5, 2.5)), _soft);
    canvas.drawPath(shape, Paint()..color = Colors.white);
    // Stub colour and perforation.
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(const Rect.fromLTWH(6, -10, 11, 20), Paint()..color = orange);
    canvas.restore();
    final perf = Paint()..color = const Color(0xFFE5D3BF);
    for (double y = -6.5; y <= 6.5; y += 2.6) {
      canvas.drawCircle(Offset(6, y), 0.55, perf);
    }
    // Price on the ticket, a tiny plane mark on the stub.
    final tp = TextPainter(
      text: const TextSpan(
          text: '50€',
          style: TextStyle(fontFamily: 'Jakarta', fontSize: 10.5, fontWeight: FontWeight.w800, color: orange)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-5.5 - tp.width / 2, -tp.height / 2));
    canvas.save();
    canvas.translate(11.5, 0);
    canvas.rotate(math.pi / 2);
    canvas.scale(0.05);
    canvas.translate(-100, -115);
    canvas.drawPath(PlaneArt.silhouette, Paint()..color = Colors.white);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art;
}
