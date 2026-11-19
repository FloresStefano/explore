import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../common.dart';
import '../data.dart';
import 'home_art.dart';
import 'home_bits.dart';
import 'crazy.dart';
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
        future: Future.wait([
          App.repo.settings(),
          App.repo.get('summary.json'),
          App.repo.catalog(App.prefs.airports),
          App.repo.get('crazy.json'),
        ]),
        builder: (context, snap) {
          final settings = snap.data?[0] as Json?;
          final summary = snap.data?[1] as Json?;
          final catalog = (snap.data?[2] as List<Json>?) ?? const <Json>[];
          final places = _places(catalog);
          final best = bestOffers(catalog);
          // AI texts the job wrote for the Pazzie, when the offer is one of them.
          final crazyFile = snap.data?[3] as Json?;
          final texts = (crazyFile?['version'] == crazyTextVersion ? (crazyFile?['items'] as Json?) : null) ?? const <String, dynamic>{};
          final hours = _value(settings, 'SEL-08', 8);
          final maxPrice = _value(settings, 'JOB-09', 150);
          final n = NumberFormat.decimalPattern('it');
          final when = _when(summary?['run_at'] as String?);
          final lines = <(LineArt, String, String)>[
            (
              LineArt.calendar,
              'Non hai ferie?',
              'Ogni sera cerchiamo per te weekend, weekend lunghi e ponti, contando feste, santi patroni '
                  'e chiusure delle scuole: ogni viaggio ti lascia almeno ${num1(hours)} ore nette sul posto.',
            ),
            (
              LineArt.routes,
              'Da Verona, Bergamo e Treviso.',
              'Solo voli diretti e convenienti, sotto i ${num1(maxPrice)}\u00A0€ andata e ritorno: Ryanair, '
                  'Wizz Air, Volotea, easyJet e le altre compagnie, tutte nella stessa lista.',
            ),
            (
              LineArt.ticket,
              'E per chi decide al volo,',
              'le Pazzie: weekend, weekend lunghi e ponti sotto i 50\u00A0€, raccontati dall\'intelligenza '
                  'artificiale in una classifica che parte dal più vicino.',
            ),
          ];
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
                          const HeaderActions(),
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
                    for (final (i, line) in lines.indexed)
                      Reveal(
                        key: ValueKey('line$i'),
                        delay: Duration(milliseconds: 90 * i),
                        child: _Line(art: line.$1, lead: line.$2, text: line.$3, all: lines),
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
              // The ten best offers by the three indicators, sliding by; tap one to open its card.
              Reveal(
                key: const ValueKey('places'),
                delay: const Duration(milliseconds: 360),
                child: best.length < 3
                    ? const SizedBox(height: Sp.xl)
                    : Padding(
                        padding: const EdgeInsets.only(top: Sp.xxl),
                        child: Column(children: [
                          Text('Le ${best.length} occasioni migliori',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w700, color: ink)),
                          const SizedBox(height: Sp.xs),
                          const Text('meno euro per km e per ora, più ore di vita · tocca per aprire',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: Fs.small, color: muted)),
                          const SizedBox(height: Sp.md),
                          Marquee(speed: 24, children: [
                            for (final (i, o) in best.indexed)
                              BestChip(
                                rank: i + 1,
                                code: '${o['country_code'] ?? ''}',
                                city: '${o['city'] ?? o['destination']}'.split(' (').first,
                                price: o['price'] as num,
                                onTap: () => showCrazyCard(
                                  context,
                                  offer: o,
                                  rank: i + 1,
                                  catalog: catalog,
                                  ai: texts['${o['origin']}-${o['destination']}-${o['out_date']}-${o['ret_date']}']
                                      as Json?,
                                  caption: 'N° ${i + 1} delle ${best.length} occasioni migliori',
                                ),
                              ),
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
  const _Line({required this.art, required this.lead, required this.text, required this.all});
  final LineArt art;
  final String lead, text;

  /// All the blocks: each one takes the height of the tallest, so the three are equal.
  final List<(LineArt, String, String)> all;

  static const _style = TextStyle(fontFamily: 'Jakarta', fontSize: Fs.body + 1, height: 1.5, color: muted);
  static const _pad = Sp.lg + 2, _art = 52.0, _gap = Sp.lg;

  TextSpan _span(String lead, String text) => TextSpan(children: [
        TextSpan(text: '$lead ', style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
        TextSpan(text: text),
      ], style: _style);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth - 2 * _pad - _art - _gap;
        var tallest = _art;
        for (final (_, l, t) in all) {
          final tp = TextPainter(text: _span(l, t), textDirection: TextDirection.ltr, textScaler: scaler)
            ..layout(maxWidth: width);
          tallest = math.max(tallest, tp.height);
          tp.dispose();
        }
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Rd.xl),
            boxShadow: shadowSm,
          ),
          child: CustomPaint(
            painter: const SwooshPainter(),
            child: Padding(
              padding: const EdgeInsets.all(_pad),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LineArtTile(art),
                const SizedBox(width: _gap),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: tallest),
                    child: Text.rich(_span(lead, text)),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
