import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'settings.dart';

/// Home: the idea behind the app in a few lines, with a plane flying around the world.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onExplore});

  /// Opens the Destinazioni section.
  final VoidCallback onExplore;

  /// Numbers in the text come from the job's settings, so the page stays true when they change.
  static num _value(Json? settings, String id, num fallback) {
    for (final e in ((settings?['settings'] as List?) ?? const []).cast<Json>()) {
      if (e['id'] == id && e['value'] is num) return e['value'] as num;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: pageBg,
      child: FutureBuilder(
        future: App.repo.settings(),
        builder: (context, snap) {
          final hours = _value(snap.data, 'SEL-08', 8);
          final maxPrice = _value(snap.data, 'JOB-09', 150);
          return SingleChildScrollView(
            child: Column(children: [
              // Hero: the drawing and the slogan on the navy background of the other sections.
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, top + 12, 20, 34),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [navy, Color(0xFF232678)],
                  ),
                  borderRadius: wide ? null : const BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(children: [
                  if (!wide)
                    Align(
                      alignment: Alignment.centerRight,
                      child: RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
                    ),
                  SizedBox(
                    width: wide ? 340 : 270,
                    height: wide ? 260 : 210,
                    child: const PlaneAroundTheWorld(),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      'Il mondo è troppo piccolo per non girarlo tutto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 36 : 27,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(children: [
                    _Line(
                      icon: Icons.event_available,
                      color: indigo,
                      bg: const Color(0xFFE8EAFB),
                      lead: 'Non hai ferie?',
                      text: 'Cerchiamo noi ogni sera per te: weekend, weekend lunghi o ponti per sfruttare '
                          'ogni ora al meglio, con almeno ${num1(hours)} ore sul posto.',
                    ),
                    _Line(
                      icon: Icons.flight_takeoff,
                      color: green,
                      bg: greenBg,
                      lead: 'Da Verona, Bergamo e Treviso.',
                      text: 'Solo voli convenienti, sotto i ${num1(maxPrice)} € andata e ritorno.',
                    ),
                    const _Line(
                      icon: Icons.local_fire_department,
                      color: orange,
                      bg: orangeBg,
                      lead: 'E per chi decide al volo,',
                      text: 'le Pazzie: weekend sotto i 50 €.',
                    ),
                    const SizedBox(height: 18),
                    const Text('Dove vai questo weekend?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: onExplore,
                      style: FilledButton.styleFrom(
                        backgroundColor: indigo,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.explore),
                      label: const Text('Scopri le destinazioni'),
                    ),
                    const SizedBox(height: 40),
                    // The closing line, slanted like a sticker.
                    Transform.rotate(
                      angle: -0.09,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          color: orange,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: orange.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: const Text('Non hai più scuse!',
                            style: TextStyle(
                                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.bg, required this.lead, required this.text});
  final IconData icon;
  final Color color, bg;
  final String lead, text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$lead ', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
              TextSpan(text: text),
            ]),
            style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF3A3F5C)),
          ),
        ),
      ]),
    );
  }
}

/// A small plane that keeps flying around a cartoon globe.
class PlaneAroundTheWorld extends StatefulWidget {
  const PlaneAroundTheWorld({super.key});

  @override
  State<PlaneAroundTheWorld> createState() => _PlaneAroundTheWorldState();
}

class _PlaneAroundTheWorldState extends State<PlaneAroundTheWorld> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _GlobePainter(_c.value), size: Size.infinite),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.t);
  final double t; // 0..1 along the orbit

  static const _tilt = -0.32;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.33;
    final a = r * 1.55, b = r * 0.42; // orbit radii
    final theta = t * 2 * math.pi;
    final behind = math.sin(theta) < 0; // upper half of the ellipse is the far side

    Offset orbit(double th) {
      final x = a * math.cos(th), y = b * math.sin(th);
      return c + Offset(x * math.cos(_tilt) - y * math.sin(_tilt), x * math.sin(_tilt) + y * math.cos(_tilt));
    }

    Path orbitPath(double from, double to) {
      final p = Path();
      const n = 60;
      for (var i = 0; i <= n; i++) {
        final o = orbit(from + (to - from) * i / n);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35);

    _stars(canvas, size);
    // Far half of the orbit, then the plane if it is behind the globe.
    _dashed(canvas, orbitPath(math.pi, 2 * math.pi), orbitPaint);
    if (behind) _plane(canvas, orbit, theta, a, b, 0.75);
    _globe(canvas, c, r);
    _dashed(canvas, orbitPath(0, math.pi), orbitPaint..color = Colors.white.withValues(alpha: 0.6));
    if (!behind) _plane(canvas, orbit, theta, a, b, 1);
  }

  void _stars(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.5);
    const spots = [(0.08, 0.15), (0.9, 0.12), (0.15, 0.85), (0.86, 0.8), (0.5, 0.04), (0.97, 0.5), (0.03, 0.5)];
    for (final (i, (x, y)) in spots.indexed) {
      final twinkle = 0.6 + 0.4 * math.sin(t * 2 * math.pi * 2 + i);
      canvas.drawCircle(Offset(x * size.width, y * size.height), 1.6 + twinkle, p);
    }
  }

  void _globe(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    // Soft glow.
    canvas.drawCircle(c, r * 1.12, Paint()..color = const Color(0xFF5B8DEF).withValues(alpha: 0.18));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFF7FC4F5), Color(0xFF3A7BD5), Color(0xFF24489E)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    // Continents drift slowly: the world turns while the plane flies.
    final shift = (t * 2 * r) % (2 * r);
    final land = Paint()..color = const Color(0xFF6CC48A);
    for (final dx in [-2 * r, 0.0]) {
      canvas.save();
      canvas.translate(dx + shift, 0);
      _blob(canvas, c + Offset(-r * 0.45, -r * 0.35), r * 0.42, r * 0.3, land);
      _blob(canvas, c + Offset(-r * 0.25, r * 0.25), r * 0.22, r * 0.4, land);
      _blob(canvas, c + Offset(r * 0.4, -r * 0.2), r * 0.35, r * 0.24, land);
      _blob(canvas, c + Offset(r * 0.55, r * 0.45), r * 0.24, r * 0.16, land);
      _blob(canvas, c + Offset(r * 0.95, -r * 0.55), r * 0.2, r * 0.14, land);
      canvas.restore();
    }
    // Parallels and a meridian, then a light from the top left.
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.18);
    for (final k in [-0.5, 0.0, 0.5]) {
      canvas.drawOval(Rect.fromCenter(center: c + Offset(0, k * r), width: 2 * r, height: r * 0.35), grid);
    }
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 0.9, height: 2 * r), grid);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.6, 0.7),
          radius: 1.1,
          colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _blob(Canvas canvas, Offset center, double w, double h, Paint p) {
    canvas.drawOval(Rect.fromCenter(center: center, width: w * 2, height: h * 2), p);
    canvas.drawOval(Rect.fromCenter(center: center + Offset(w * 0.6, h * 0.5), width: w * 1.1, height: h * 1.1), p);
  }

  void _plane(Canvas canvas, Offset Function(double) orbit, double theta, double a, double b, double scale) {
    final pos = orbit(theta);
    final dx = -a * math.sin(theta), dy = b * math.cos(theta);
    final dir = math.atan2(dx * math.sin(_tilt) + dy * math.cos(_tilt), dx * math.cos(_tilt) - dy * math.sin(_tilt));
    final icon = Icons.flight;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 30 * scale,
          color: Color.lerp(const Color(0xFFFFB45C), Colors.white, scale == 1 ? 0 : 0.3),
          shadows: const [Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(dir - math.pi / 2); // nose along the direction of flight
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GlobePainter old) => old.t != t;
}
