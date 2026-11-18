import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../common.dart';
import '../data.dart';
import 'home_art.dart';
import 'home_bits.dart';
import 'home_hero.dart';
import 'settings.dart';

/// Home: the idea behind the app in a few lines, under a plane flying over a paper-cut world.
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
              // Hero: the plane over the paper-cut landscape, the brand bar on the sky (phones).
              HomeHero(
                height: wide ? 440 : (MediaQuery.sizeOf(context).height * 0.5).clamp(340.0, 480.0) + top,
                top: wide
                    ? null
                    : Padding(
                        padding: EdgeInsets.fromLTRB(Sp.lg + 4, top + Sp.md, Sp.lg, 0),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(Rd.sm + 2),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: Sp.sm + 2),
                          const Expanded(
                            child: Text('Weekend Break',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: Fs.title,
                                    fontWeight: FontWeight.w800,
                                    shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)])),
                          ),
                          RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
                        ]),
                      ),
              ),
              // The slogan on the white page, right under the hill: a light spaced line and a bold one.
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg + 4, Sp.sm, Sp.lg + 4, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Reveal(
                    key: const ValueKey('slogan'),
                    child: Column(children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('IL MONDO È TROPPO PICCOLO',
                            style: TextStyle(
                                color: navy, fontSize: Fs.title, fontWeight: FontWeight.w500, letterSpacing: 4.5)),
                      ),
                      const SizedBox(height: Sp.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('PER NON GIRARLO TUTTO',
                            style: TextStyle(
                                color: const Color(0xFF214A8C),
                                fontSize: wide ? 46 : 36,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                      ),
                      if (summary != null) ...[
                        const SizedBox(height: Sp.lg),
                        Wrap(alignment: WrapAlignment.center, spacing: Sp.sm, runSpacing: Sp.sm, children: [
                          _Stat('${n.format(summary['offers'] ?? 0)} offerte'),
                          _Stat('${places.isNotEmpty ? places.length : summary['destinations'] ?? 0} mete'),
                          if (when.isNotEmpty) _Stat('aggiornate $when', icon: Icons.schedule),
                        ]),
                      ],
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xl + 4, Sp.lg, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Reveal(
                      key: const ValueKey('line1'),
                      child: _Line(
                        art: LineArt.calendar,
                        lead: 'Non hai ferie?',
                        text: 'Cerchiamo noi ogni sera per te: weekend, weekend lunghi o ponti per sfruttare '
                            'ogni ora al meglio, con almeno ${num1(hours)} ore sul posto.',
                      ),
                    ),
                    Reveal(
                      key: const ValueKey('line2'),
                      delay: const Duration(milliseconds: 90),
                      child: _Line(
                        art: LineArt.routes,
                        lead: 'Da Verona, Bergamo e Treviso.',
                        text: 'Solo voli convenienti, sotto i ${num1(maxPrice)} € andata e ritorno.',
                      ),
                    ),
                    const Reveal(
                      key: ValueKey('line3'),
                      delay: Duration(milliseconds: 180),
                      child: _Line(
                        art: LineArt.ticket,
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

/// A live figure under the slogan, on a soft pill.
class _Stat extends StatelessWidget {
  const _Stat(this.text, {this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: muted), const SizedBox(width: 6)],
          Text(text,
              style: const TextStyle(color: ink, fontSize: Fs.label, fontWeight: FontWeight.w600, fontFeatures: tabular)),
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.art, required this.lead, required this.text});
  final LineArt art;
  final String lead, text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: WhiteCard(
        padding: const EdgeInsets.all(Sp.lg + 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LineArtTile(art),
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
