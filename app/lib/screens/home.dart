import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../common.dart';
import '../data.dart';
import 'home_bits.dart';
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

  /// "stasera alle 21:23", "ieri alle 21:23" or "il 16 novembre": when the offers were collected.
  static String _when(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    final hm = DateFormat('HH:mm').format(t);
    if (days == 0) return t.hour >= 18 ? 'stasera alle $hm' : 'oggi alle $hm';
    if (days == 1) return 'ieri alle $hm';
    return 'il ${DateFormat('d MMMM', 'it').format(t)}';
  }

  /// Destinations in the catalog, the most served first: (country code, city).
  static List<(String, String)> _places(List<Json> catalog) {
    final count = <String, int>{};
    final info = <String, (String, String)>{};
    for (final o in catalog) {
      // "Paris (Orly, Val-de-Marne)" -> "Paris": one chip per city.
      final city = '${o['city'] ?? o['destination']}'.split(' (').first.trim();
      count[city] = (count[city] ?? 0) + 1;
      info[city] = ('${o['country_code'] ?? ''}', city);
    }
    final cities = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    return [for (final c in cities) info[c]!];
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: pageBg,
      child: FutureBuilder(
        future: Future.wait([App.repo.settings(), App.repo.get('summary.json'), App.repo.catalog(App.prefs.airports)]),
        builder: (context, snap) {
          final settings = snap.data?[0] as Json?;
          final summary = snap.data?[1] as Json?;
          final places = _places((snap.data?[2] as List<Json>?) ?? const []);
          final hours = _value(settings, 'SEL-08', 8);
          final maxPrice = _value(settings, 'JOB-09', 150);
          final n = NumberFormat.decimalPattern('it');
          final when = _when(summary?['run_at'] as String?);
          return SingleChildScrollView(
            child: Column(children: [
              // Hero: brand bar, the drawing, the slogan and three live figures.
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(Sp.lg + 4, top + Sp.md, Sp.lg + 4, Sp.xxl),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [navy, navySoft],
                  ),
                  borderRadius: wide ? null : const BorderRadius.vertical(bottom: Radius.circular(Rd.xxl)),
                ),
                child: Column(children: [
                  if (!wide)
                    Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: indigo, borderRadius: BorderRadius.circular(Rd.sm + 2)),
                        child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: Sp.sm + 2),
                      const Expanded(
                        child: Text('Weekend Break',
                            style: TextStyle(color: Colors.white, fontSize: Fs.title, fontWeight: FontWeight.w700)),
                      ),
                      RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
                    ]),
                  SizedBox(
                    width: wide ? 340 : 280,
                    height: wide ? 250 : 210,
                    child: const PlaneAroundTheWorld(),
                  ),
                  const SizedBox(height: Sp.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      'Il mondo è troppo piccolo per non girarlo tutto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 38 : Fs.display - 2,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: Sp.lg + 4),
                    Wrap(alignment: WrapAlignment.center, spacing: Sp.sm, runSpacing: Sp.sm, children: [
                      _Stat('${n.format(summary['offers'] ?? 0)} offerte'),
                      _Stat('${places.isNotEmpty ? places.length : summary['destinations'] ?? 0} mete'),
                      if (when.isNotEmpty) _Stat('aggiornate $when', icon: Icons.schedule),
                    ]),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xl, Sp.lg, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Reveal(
                      key: const ValueKey('line1'),
                      child: _Line(
                        icon: Icons.event_available_rounded,
                        color: indigo,
                        bg: const Color(0xFFE8ECFB),
                        lead: 'Non hai ferie?',
                        text: 'Cerchiamo noi ogni sera per te: weekend, weekend lunghi o ponti per sfruttare '
                            'ogni ora al meglio, con almeno ${num1(hours)} ore sul posto.',
                      ),
                    ),
                    Reveal(
                      key: const ValueKey('line2'),
                      delay: const Duration(milliseconds: 90),
                      child: _Line(
                        icon: Icons.flight_takeoff_rounded,
                        color: green,
                        bg: greenBg,
                        lead: 'Da Verona, Bergamo e Treviso.',
                        text: 'Solo voli convenienti, sotto i ${num1(maxPrice)} € andata e ritorno.',
                      ),
                    ),
                    const Reveal(
                      key: ValueKey('line3'),
                      delay: Duration(milliseconds: 180),
                      child: _Line(
                        icon: Icons.local_fire_department_rounded,
                        color: orange,
                        bg: orangeBg,
                        lead: 'E per chi decide al volo,',
                        text: 'le Pazzie: weekend sotto i 50 €.',
                      ),
                    ),
                    const SizedBox(height: Sp.md),
                    const Reveal(
                      key: ValueKey('countdown'),
                      delay: Duration(milliseconds: 270),
                      child: WeekendCountdown(),
                    ),
                  ]),
                ),
              ),
              // The destinations within reach, on two bands sliding in opposite directions.
              Reveal(
                key: const ValueKey('places'),
                delay: const Duration(milliseconds: 360),
                child: places.length < 6
                    ? const SizedBox(height: Sp.xl)
                    : Padding(
                        padding: const EdgeInsets.only(top: Sp.xxl),
                        child: Column(children: [
                          Text('${places.length} mete a portata di weekend',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w700, color: ink)),
                          const SizedBox(height: Sp.xs),
                          const Text('da Verona, Bergamo e Treviso',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: Fs.small, color: muted)),
                          const SizedBox(height: Sp.md),
                          Marquee(children: [
                            for (final (code, city) in places.take((places.length / 2).ceil()))
                              PlaceChip(code: code, city: city),
                          ]),
                          const SizedBox(height: Sp.sm),
                          Marquee(reverse: true, speed: 22, children: [
                            for (final (code, city) in places.skip((places.length / 2).ceil()))
                              PlaceChip(code: code, city: city),
                          ]),
                        ]),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xxl, Sp.lg, Sp.xxl + Sp.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Dove vai questo weekend?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: Fs.headline, fontWeight: FontWeight.w800, color: navy, letterSpacing: -0.3)),
                    const SizedBox(height: Sp.lg),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onExplore,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.lg)),
                              textStyle: const TextStyle(
                                  fontFamily: 'Jakarta', fontSize: Fs.title, fontWeight: FontWeight.w700),
                            ),
                            icon: const Icon(Icons.explore_rounded),
                            label: const Text('Scopri le destinazioni'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Sp.xxl + Sp.sm),
                    // The closing line, slanted like a sticker, with a little wobble now and then.
                    const Center(child: _Sticker()),
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

/// "Non hai più scuse!": a slanted sticker that gives a small wobble every few seconds.
class _Sticker extends StatefulWidget {
  const _Sticker();

  @override
  State<_Sticker> createState() => _StickerState();
}

class _StickerState extends State<_Sticker> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // Still most of the time; a short damped swing in the last 15% of each cycle.
          final t = ((_c.value - 0.85) / 0.15).clamp(0.0, 1.0);
          final swing = math.sin(t * math.pi * 4) * (1 - t) * 0.05;
          return Transform.rotate(angle: -0.07 + swing, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.sm + 2),
          decoration: BoxDecoration(
            color: orange,
            borderRadius: BorderRadius.circular(Rd.sm),
            boxShadow: [BoxShadow(color: orange.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Text('Non hai più scuse!',
              style: TextStyle(
                  color: Colors.white, fontSize: Fs.headline, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        ),
      );
}

/// A live figure under the slogan, on a translucent pill.
class _Stat extends StatelessWidget {
  const _Stat(this.text, {this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: Colors.white70), const SizedBox(width: 6)],
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: Fs.label, fontWeight: FontWeight.w600, fontFeatures: tabular)),
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.bg, required this.lead, required this.text});
  final IconData icon;
  final Color color, bg;
  final String lead, text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: WhiteCard(
        padding: const EdgeInsets.all(Sp.lg + 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rd.md)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: Sp.lg),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$lead ', style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                TextSpan(text: text),
              ]),
              style: const TextStyle(fontSize: Fs.body + 1, height: 1.5, color: muted),
            ),
          ),
        ]),
      ),
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
    // A far cloud drifts behind the globe, a near one passes in front, slower.
    _cloud(canvas, size, speed: 1, y: 0.22, scale: 0.75, alpha: 0.35);
    // Far half of the orbit, then the plane if it is behind the globe.
    _dashed(canvas, orbitPath(math.pi, 2 * math.pi), orbitPaint);
    if (behind) _plane(canvas, orbit, theta, a, b, 0.75);
    _globe(canvas, c, r);
    _dashed(canvas, orbitPath(0, math.pi), orbitPaint..color = Colors.white.withValues(alpha: 0.6));
    if (!behind) _plane(canvas, orbit, theta, a, b, 1);
    _cloud(canvas, size, speed: -1, y: 0.8, scale: 1, alpha: 0.9, phase: 0.4);
  }

  /// A soft cartoon cloud crossing the drawing once per orbit (speed ±1), wrapping around.
  void _cloud(Canvas canvas, Size size,
      {required double speed, required double y, required double scale, required double alpha, double phase = 0}) {
    final w = 54 * scale, span = size.width + 2 * w;
    final x = ((t * speed + phase) % 1) * span - w;
    final base = Offset(x, size.height * y);
    final p = Paint()..color = Colors.white.withValues(alpha: alpha);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(base.dx, base.dy, w, 14 * scale), Radius.circular(7 * scale)), p);
    canvas.drawCircle(base + Offset(w * 0.32, 2 * scale), 11 * scale, p);
    canvas.drawCircle(base + Offset(w * 0.6, 0), 14 * scale, p);
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
          fontSize: Fs.display * scale,
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
