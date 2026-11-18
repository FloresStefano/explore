import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../common.dart';

/// Blues of the paper-cut scene, back to front.
const _sceneBase = Color(0xFF214A8C);
const _layerColors = [Color(0xFF285597), Color(0xFF2F61A6), Color(0xFF3A6FB7)];
const _cloudColor = Color(0xFF6595D6);

/// Length of one flight cycle: cruise, fly away, come back.
const _cycle = Duration(seconds: 14);

/// Home hero: a plane seen from above, flying over a paper-cut landscape in tones of blue.
/// The landscape slides down in layers at different speeds, clouds pass closer and faster,
/// and every cycle the plane speeds off the top and comes back rising from behind the hill.
class HomeHero extends StatefulWidget {
  const HomeHero({super.key, required this.height, this.top, this.hill = pageBg});
  final double height;

  /// Brand bar drawn over the sky (phones).
  final Widget? top;

  /// Colour of the hill at the bottom: the page background below the hero.
  final Color hill;

  @override
  State<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<HomeHero> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: _cycle)..repeat();
  final _scene = _SceneCache();

  @override
  void dispose() {
    _c.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _HeroPainter(_c, _scene, widget.hill)),
            ),
          ),
          if (widget.top != null) Positioned(left: 0, right: 0, top: 0, child: widget.top!),
        ]),
      );
}

/// The landscape layers are drawn once per size into pictures; every frame only moves them.
class _SceneCache {
  Size? _size;
  final pictures = <ui.Picture>[];

  void ensure(Size size) {
    if (_size == size && pictures.isNotEmpty) return;
    dispose();
    _size = size;
    for (var i = 0; i < _layerColors.length; i++) {
      pictures.add(_record(size, (c) => _paintLayer(c, size, i)));
    }
    pictures.add(_record(size, (c) => _paintClouds(c, size)));
  }

  void dispose() {
    for (final p in pictures) {
      p.dispose();
    }
    pictures.clear();
  }

  static ui.Picture _record(Size size, void Function(Canvas) draw) {
    final rec = ui.PictureRecorder();
    draw(Canvas(rec, Offset.zero & size));
    return rec.endRecording();
  }
}

/// A smooth closed shape through points around a centre (Catmull-Rom turned into cubics).
Path _blob(Offset c, double rx, double ry, math.Random r, {int n = 9, double jitter = 0.22}) {
  final pts = [
    for (var i = 0; i < n; i++)
      () {
        final a = 2 * math.pi * i / n + r.nextDouble() * 0.25;
        final k = 1 - jitter + r.nextDouble() * 2 * jitter;
        return c + Offset(math.cos(a) * rx * k, math.sin(a) * ry * k);
      }(),
  ];
  return _smooth(pts, closed: true);
}

Path _smooth(List<Offset> p, {bool closed = false}) {
  final path = Path()..moveTo(p.first.dx, p.first.dy);
  final n = p.length;
  final last = closed ? n : n - 1;
  for (var i = 0; i < last; i++) {
    Offset at(int k) => closed ? p[(k + n) % n] : p[k.clamp(0, n - 1)];
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  if (closed) path.close();
  return path;
}

final _shadow = Paint()
  ..color = Colors.black.withValues(alpha: 0.2)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

/// One layer of paper: elongated organic shapes, each casting a soft shadow on the layer below.
/// Shapes may cross the tile edges: the tile is drawn three times stacked, so it loops seamlessly.
void _paintLayer(Canvas canvas, Size s, int i) {
  final r = math.Random(17 + i * 31);
  final fill = Paint()..color = _layerColors[i];
  final shapes = <Path>[];
  // Same size of shapes on any screen: wide screens get more of them, not bigger ones.
  final unit = math.min(s.width, 440.0);
  final count = ((4 + i) * s.width / unit).round();
  for (var k = 0; k < count; k++) {
    final cx = s.width * (-0.15 + 1.3 * r.nextDouble());
    final cy = s.height * (k + r.nextDouble()) / count;
    final rx = unit * (0.12 + 0.16 * r.nextDouble()) * (1 - i * 0.12);
    final ry = rx * (1.5 + r.nextDouble());
    shapes.add(_blob(Offset(cx, cy), rx, ry, r));
  }
  for (final p in shapes) {
    canvas.drawPath(p.shift(const Offset(3, 5)), _shadow);
  }
  for (final p in shapes) {
    canvas.drawPath(p, fill);
  }
  if (i == 1) {
    // Dotted flight trails across the land.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var k = 0; k < 2; k++) {
      final x0 = s.width * (k == 0 ? 0.12 : 0.82);
      final pts = [
        for (var j = 0; j < 6; j++)
          Offset(x0 + (r.nextDouble() - 0.5) * s.width * 0.35, s.height * (j / 5) * 1.05 - s.height * 0.02),
      ];
      for (final m in _smooth(pts).computeMetrics()) {
        for (double d = 0; d < m.length; d += 8) {
          canvas.drawCircle(m.getTangentForOffset(d)!.position, 1.5, dot);
        }
      }
    }
  }
}

/// Cartoon clouds near the edges, so they never hide the plane.
void _paintClouds(Canvas canvas, Size s) {
  final r = math.Random(5);
  final fill = Paint()..color = _cloudColor;
  for (var k = 0; k < 4; k++) {
    final left = k.isEven;
    final c = Offset(
      left ? s.width * (0.02 + 0.12 * r.nextDouble()) : s.width * (0.86 + 0.12 * r.nextDouble()),
      s.height * (k + 0.5) / 4,
    );
    final u = 22 + 14 * r.nextDouble();
    final puffs = [
      (c, u),
      (c + Offset(-u * 0.9, u * 0.35), u * 0.75),
      (c + Offset(u * 0.95, u * 0.3), u * 0.8),
      (c + Offset(-u * 0.2, -u * 0.55), u * 0.7),
      (c + Offset(u * 0.1, u * 0.75), u * 0.7),
    ];
    for (final (o, rad) in puffs) {
      canvas.drawCircle(o + const Offset(4, 7), rad, _shadow);
    }
    for (final (o, rad) in puffs) {
      canvas.drawCircle(o, rad, fill);
    }
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.anim, this.scene, this.hill) : super(repaint: anim);
  final Animation<double> anim;
  final _SceneCache scene;
  final Color hill;

  /// Tiles per cycle for each layer (back to front, clouds last): whole numbers keep the loop seamless.
  static const _speeds = [1, 2, 3, 5];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    scene.ensure(size);
    final v = anim.value;
    final h = size.height, w = size.width;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = _sceneBase);

    final plane = _planePose(v, size);
    final layers = scene.pictures;
    for (var i = 0; i < layers.length; i++) {
      // The plane's shadow falls on the land, under the clouds.
      if (i == layers.length - 1) _drawPlane(canvas, plane, shadowOnly: true);
      final y = (v * _speeds[i] % 1) * h;
      for (final dy in [y - h, y, y + h]) {
        canvas.save();
        canvas.translate(0, dy);
        canvas.drawPicture(layers[i]);
        canvas.restore();
      }
    }
    _drawPlane(canvas, plane);

    // The white hill: the page rising into the sky, with its paper shadow.
    final hillH = math.min(72.0, h * 0.16);
    final hillPath = Path()
      ..moveTo(-10, h + 2)
      ..cubicTo(w * 0.22, h + 2, w * 0.28, h - hillH, w * 0.5, h - hillH)
      ..cubicTo(w * 0.72, h - hillH, w * 0.78, h + 2, w + 10, h + 2)
      ..close();
    canvas.drawPath(hillPath.shift(const Offset(0, -4)), _shadow);
    canvas.drawPath(hillPath, Paint()..color = hill);
  }

  /// Where the plane is, how big (altitude) and how tilted, along the cycle.
  _Pose _planePose(double v, Size s) {
    final width = math.min(s.width * 0.5, 210.0);
    final len = width * 1.15;
    final home = Offset(s.width / 2, s.height * 0.47);
    final t = v * 2 * math.pi;
    if (v < 0.66) {
      // Cruise: gentle sway and breathing altitude.
      return _Pose(home + Offset(math.sin(t * 3) * 7, math.sin(t * 2) * 4), width,
          1 + 0.025 * math.sin(t * 2), math.cos(t * 3) * 0.035);
    }
    if (v < 0.8) {
      // Speed up and leave through the top, climbing.
      final k = Curves.easeInCubic.transform((v - 0.66) / 0.14);
      return _Pose(Offset(home.dx, home.dy + (-len - home.dy) * k), width, 1 + 0.12 * k, 0);
    }
    if (v < 0.86) return _Pose(Offset(home.dx, -len * 2), width, 1, 0); // away
    // Come back rising from behind the hill, slowing down into place.
    final k = Curves.easeOutCubic.transform((v - 0.86) / 0.14);
    return _Pose(Offset(home.dx, s.height + len * 0.6 + (home.dy - s.height - len * 0.6) * k), width,
        1.1 - 0.1 * k, 0);
  }

  void _drawPlane(Canvas canvas, _Pose p, {bool shadowOnly = false}) {
    final scale = p.width / 200 * p.altitude;
    canvas.save();
    if (shadowOnly) {
      // Higher means a farther, softer shadow.
      final off = 22 * p.altitude;
      canvas.translate(p.center.dx + off, p.center.dy + off * 1.3);
      canvas.rotate(p.tilt);
      canvas.scale(scale * 0.96);
      canvas.translate(-100, -115);
      canvas.drawPath(
        PlaneArt.silhouette,
        Paint()
          ..color = const Color(0xFF0B1E45).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.restore();
      return;
    }
    canvas.translate(p.center.dx, p.center.dy);
    canvas.rotate(p.tilt);
    canvas.scale(scale);
    canvas.translate(-100, -115);
    PlaneArt.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.hill != hill;
}

class _Pose {
  const _Pose(this.center, this.width, this.altitude, this.tilt);
  final Offset center;
  final double width, altitude, tilt;
}

/// An airliner seen from above, nose up, drawn in a 200 x 230 box.
abstract final class PlaneArt {
  static final Path fuselage = Path()
    ..moveTo(100, 0)
    ..cubicTo(109, 2, 115, 20, 115, 42)
    ..lineTo(115, 190)
    ..cubicTo(115, 212, 108, 228, 100, 230)
    ..cubicTo(92, 228, 85, 212, 85, 190)
    ..lineTo(85, 42)
    ..cubicTo(85, 20, 91, 2, 100, 0)
    ..close();

  static Path _wing(bool right) {
    double x(double v) => right ? v : 200 - v;
    return Path()
      ..moveTo(x(112), 92)
      ..lineTo(x(194), 146)
      ..quadraticBezierTo(x(199), 150, x(197), 156)
      ..lineTo(x(194), 160)
      ..lineTo(x(112), 134)
      ..close();
  }

  static Path _stabilizer(bool right) {
    double x(double v) => right ? v : 200 - v;
    return Path()
      ..moveTo(x(110), 188)
      ..lineTo(x(146), 211)
      ..quadraticBezierTo(x(149), 214, x(147), 218)
      ..lineTo(x(110), 210)
      ..close();
  }

  static final List<Rect> engines = [
    for (final cx in [140.0, 168.0, 60.0, 32.0])
      Rect.fromCenter(center: Offset(cx, cx > 150 || cx < 50 ? 128 : 112), width: 13, height: 30),
  ];

  static final Path silhouette = () {
    final p = Path()..addPath(fuselage, Offset.zero);
    for (final r in [true, false]) {
      p.addPath(_wing(r), Offset.zero);
      p.addPath(_stabilizer(r), Offset.zero);
    }
    for (final e in engines) {
      p.addRRect(RRect.fromRectAndRadius(e, const Radius.circular(6)));
    }
    return p;
  }();

  static void paint(Canvas canvas) {
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF0B1E45).withValues(alpha: 0.12);
    final wingFill = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFE6EAF1), Colors.white, Color(0xFFE6EAF1)])
          .createShader(const Rect.fromLTWH(0, 90, 200, 70));
    for (final r in [true, false]) {
      final w = _wing(r), s = _stabilizer(r);
      canvas.drawPath(w, wingFill);
      canvas.drawPath(w, edge);
      canvas.drawPath(s, wingFill);
      canvas.drawPath(s, edge);
    }
    // Engines: silver pods under the wings, a dark intake at the front.
    for (final e in engines) {
      final pod = RRect.fromRectAndRadius(e, const Radius.circular(6));
      canvas.drawRRect(
          pod,
          Paint()
            ..shader = const LinearGradient(colors: [Color(0xFFB8C1CF), Color(0xFFF4F6F9), Color(0xFFB8C1CF)])
                .createShader(e));
      canvas.drawRRect(pod, edge);
      canvas.drawOval(Rect.fromCenter(center: e.topCenter + const Offset(0, 3), width: 9, height: 4),
          Paint()..color = const Color(0xFF44506A));
    }
    // Fuselage, lit from the left.
    canvas.drawPath(
        fuselage,
        Paint()
          ..shader = const LinearGradient(colors: [Colors.white, Color(0xFFF7F8FB), Color(0xFFD9DFE8)])
              .createShader(const Rect.fromLTWH(85, 0, 30, 230)));
    canvas.drawPath(fuselage, edge);
    // Cockpit windows and two rows of cabin windows.
    final dark = Paint()..color = const Color(0xFF1B2A4A);
    canvas.drawPath(
        Path()
          ..moveTo(92, 24)
          ..quadraticBezierTo(100, 17, 108, 24)
          ..lineTo(106, 28)
          ..quadraticBezierTo(100, 23, 94, 28)
          ..close(),
        dark);
    for (double y = 44; y <= 186; y += 5.5) {
      canvas.drawCircle(Offset(91, y), 1.05, dark);
      canvas.drawCircle(Offset(109, y), 1.05, dark);
    }
  }
}
