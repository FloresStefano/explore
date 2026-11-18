import 'dart:async';

import 'package:flutter/material.dart';

import '../common.dart';

/// Fades and lifts its child in, after [delay]: the Home blocks arrive one after another.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}

/// Start of the next weekend: Friday at 18:00, local time.
DateTime nextWeekendStart(DateTime now) {
  final friday = DateTime(now.year, now.month, now.day + ((DateTime.friday - now.weekday) % 7), 18);
  return friday.isAfter(now) || now.weekday != DateTime.friday ? friday : friday.add(const Duration(days: 7));
}

/// From Friday 18:00 to Sunday midnight it is weekend.
bool isWeekendNow(DateTime now) =>
    (now.weekday == DateTime.friday && now.hour >= 18) ||
    now.weekday == DateTime.saturday ||
    now.weekday == DateTime.sunday;

/// "Il prossimo weekend inizia tra" with days, hours, minutes and seconds ticking.
class WeekendCountdown extends StatefulWidget {
  const WeekendCountdown({super.key, this.now});
  final DateTime Function()? now; // for tests

  @override
  State<WeekendCountdown> createState() => _WeekendCountdownState();
}

class _WeekendCountdownState extends State<WeekendCountdown> {
  Timer? _tick;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final weekend = isWeekendNow(now);
    final left = nextWeekendStart(now).difference(now);
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.lg + 2, Sp.lg, Sp.lg + 2, Sp.lg + 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [indigo, Color(0xFF4A63E0)],
        ),
        borderRadius: BorderRadius.circular(Rd.xl),
        boxShadow: [BoxShadow(color: indigo.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(weekend ? Icons.celebration_rounded : Icons.hourglass_top_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(weekend ? 'È weekend! Sei ancora a casa?' : 'Il prossimo weekend inizia tra',
              style: const TextStyle(color: Colors.white, fontSize: Fs.small, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: Sp.md),
        if (weekend)
          const Text('Guarda le partenze di stasera o prepara il prossimo.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: Fs.small))
        else
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Digit(left.inDays, 'giorni'),
            _Digit(left.inHours % 24, 'ore'),
            _Digit(left.inMinutes % 60, 'min'),
            _Digit(left.inSeconds % 60, 'sec'),
          ]),
      ]),
    );
  }
}

class _Digit extends StatelessWidget {
  const _Digit(this.value, this.label);
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 62,
        margin: const EdgeInsets.symmetric(horizontal: Sp.xs),
        padding: const EdgeInsets.symmetric(vertical: Sp.sm),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Rd.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(children: [
          // The changing figure slides up, like a departures board.
          AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (child, a) => ClipRect(
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
            ),
            child: Text(value.toString().padLeft(2, '0'),
                key: ValueKey(value),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: Fs.headline + 2,
                    fontWeight: FontWeight.w800,
                    fontFeatures: tabular,
                    height: 1.1)),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: Fs.caption, fontWeight: FontWeight.w500)),
        ]),
      );
}

/// Endless band of destination names, sliding at [speed] pixels per second; edges fade out.
class Marquee extends StatefulWidget {
  const Marquee({super.key, required this.children, this.speed = 28, this.reverse = false});
  final List<Widget> children;
  final double speed;
  final bool reverse;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  late final _c = AnimationController(vsync: this);
  double _width = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.hasSize) return;
    _width = box.size.width;
    if (_width > 0) {
      _c.duration = Duration(milliseconds: (_width / widget.speed * 1000).round());
      _c.repeat();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget copy({Key? key}) => Row(key: key, mainAxisSize: MainAxisSize.min, children: [
          for (final c in widget.children) Padding(padding: const EdgeInsets.only(right: Sp.sm), child: c),
        ]);
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
        stops: [0, 0.08, 0.92, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: ClipRect(
        child: SizedBox(
          height: 40,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final dx = _width * (widget.reverse ? _c.value - 1 : -_c.value);
              return OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(offset: Offset(dx, 0), child: child),
              );
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [copy(key: _key), copy(), copy()]),
          ),
        ),
      ),
    );
  }
}

/// A destination in the marquee: country code badge and city name.
class PlaceChip extends StatelessWidget {
  const PlaceChip({super.key, required this.code, required this.city});
  final String code;
  final String city;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 6, Sp.md, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(99)),
            child: Text(code.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: Fs.caption - 1, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          ),
          const SizedBox(width: Sp.sm),
          Text(city, style: const TextStyle(fontSize: Fs.small, fontWeight: FontWeight.w600, color: ink)),
        ]),
      );
}
