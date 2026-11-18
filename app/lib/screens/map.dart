import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common.dart';
import '../data.dart';
import 'offers.dart';
import 'settings.dart';

// View of Europe and its surroundings, in degrees.
const _west = -26.0, _east = 46.0, _south = 26.5, _north = 67.0;

double _merc(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
final _yTop = _merc(_north), _yBottom = _merc(_south);
const _aspect = 1.18; // width / height of the view

Offset _project(double lon, double lat, Size s) => Offset(
      (lon - _west) / (_east - _west) * s.width,
      (_yTop - _merc(lat.clamp(-80, 84).toDouble())) / (_yTop - _yBottom) * s.height,
    );

/// Area 3: direct destinations from the chosen airports, on an offline map
/// drawn from Natural Earth land outlines (public domain).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static Future<List<List<Offset>>>? _land;
  String? _selected;
  String? _loadedFor;
  Future<(List<List<Offset>>, Map<String, Json>, List<Json>)>? _loading;

  static Future<List<List<Offset>>> _loadLand() async {
    final rings = jsonDecode(await rootBundle.loadString('assets/europe_land.json')) as List;
    return [
      for (final r in rings)
        [for (final p in r as List) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())],
    ];
  }

  Future<(List<List<Offset>>, Map<String, Json>, List<Json>)> _load(List<String> airports) async {
    final land = await (_land ??= _loadLand());
    final dests = <String, Json>{};
    final catalog = await App.repo.catalog(airports);
    final all = await Future.wait(airports.map(App.repo.routes));
    for (var i = 0; i < airports.length; i++) {
      all[i].forEach((code, v) {
        final d = v as Json;
        if (d['lat'] == null) return;
        final e = dests.putIfAbsent(code, () => {...d, 'from': <String>[], 'months': <String>{}, 'airlines': <String>{}});
        (e['from'] as List).add(airports[i]);
        (e['months'] as Set).addAll((d['months'] as List? ?? const []).cast<String>());
        (e['airlines'] as Set).addAll((d['airlines'] as List? ?? const []).cast<String>());
      });
    }
    return (land, dests, catalog);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.changes,
      builder: (context, _) {
        final prefs = App.prefs;
        final airportsKey = prefs.airports.join();
        if (_loadedFor != airportsKey) {
          _loadedFor = airportsKey;
          _loading = _load(prefs.airports);
        }
        return PageShell(
          headerHeight: sectionHeaderHeight,
          header: HeaderTitle(
            // Departure airports come from the settings (USR-04).
            kicker: 'Offerte per meta',
            title: 'Mappa',
            action: isWide(context) ? null : RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
          ),
          child: FutureBuilder(
            key: ValueKey(prefs.airports.join()),
            future: _loading,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Loading();
              }
              final (land, all, catalog) = snap.data!;
              // Months come from the offers in hand: the scan depth decides the choice.
              final months = monthsOf(catalog);
              final offers = OfferFilter.shared().apply(catalog);
              final filters = FilterBar(months: months, airlines: airlinesOf(catalog));
              final byDest = <String, List<Json>>{};
              for (final o in offers) {
                (byDest[o['destination'] as String] ??= []).add(o);
              }
              final count = CountLine('${byDest.length} mete · ${offers.length} offerte');
              final dests = {for (final e in all.entries) if (byDest.containsKey(e.key)) e.key: e.value};
              final others = {for (final e in all.entries) if (!byDest.containsKey(e.key)) e.key: e.value};
              final sel = _selected == null ? null : dests[_selected];
              final selOffers = _selected == null ? const <Json>[] : (byDest[_selected] ?? const <Json>[]);
              final wide = MediaQuery.sizeOf(context).width >= 1100;
              final mapCard = WhiteCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Rd.md),
                        child: AspectRatio(
                          aspectRatio: _aspect,
                          child: ColoredBox(
                            color: const Color(0xFFCDD5F6),
                            child: InteractiveViewer(
                              maxScale: 6,
                              child: LayoutBuilder(builder: (context, box) {
                                final size = box.biggest;
                                return GestureDetector(
                                  onTapUp: (t) => setState(() => _selected = _nearest(dests, t.localPosition, size)),
                                  child: CustomPaint(size: size, painter: _MapPainter(land, dests, others, _selected)),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        dests.isEmpty
                            ? 'Nessuna meta con offerte in questo periodo.'
                            : 'Tocca un punto per vederne le offerte, pizzica per ingrandire',
                        style: const TextStyle(fontSize: Fs.label, color: muted),
                      ),
                    ]),
                  );
              final side = <Widget>[
                if (sel != null && selOffers.isNotEmpty)
                  AggregateCard(
                    badge: _selected!,
                    title: '${sel['city'] ?? sel['name']}, ${sel['country'] ?? ''}',
                    subtitle: 'Da ${(sel['from'] as List).map((a) => airportCity[a] ?? a).join(', ')} · '
                        '${selOffers.length} offerte · ${(sel['airlines'] as Set).join(', ')}',
                    stats: Stats(selOffers),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OffersScreen(
                          section: 'Mappa',
                          path: [
                            if ('${sel['country'] ?? ''}'.isNotEmpty) '${sel['country']}',
                            '${sel['city'] ?? _selected}',
                          ],
                          offers: selOffers,
                        ),
                      ),
                    ),
                  )
                else
                  const EmptyNote('Tocca una meta sulla mappa per vedere prezzo minimo e offerte.',
                      icon: Icons.touch_app_outlined),
              ];
              if (wide) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    filters,
                    const SizedBox(height: 12),
                    count,
                    Expanded(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: SingleChildScrollView(child: mapCard)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: ListView(children: side)),
                      ]),
                    ),
                  ]),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [filters, const SizedBox(height: 12), count, mapCard, const SizedBox(height: 12), ...side],
              );
            },
          ),
        );
      },
    );
  }

  static String? _nearest(Map<String, Json> dests, Offset p, Size size) {
    String? best;
    var bestD = 18.0 * 18.0;
    dests.forEach((code, d) {
      final q = _project((d['lon'] as num).toDouble(), (d['lat'] as num).toDouble(), size);
      final dist = (q - p).distanceSquared;
      if (dist < bestD) {
        bestD = dist;
        best = code;
      }
    });
    return best;
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.land, this.dests, this.others, this.selected);
  final List<List<Offset>> land;
  final Map<String, Json> dests; // with offers in the chosen period
  final Map<String, Json> others; // routes without offers right now
  final String? selected;

  static const _origins = {'VRN': Offset(10.888, 45.396), 'BGY': Offset(9.704, 45.674), 'TSF': Offset(12.194, 45.648)};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    // One path per outline: simple polygons, so the fill cannot flip inside out.
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFFA9B2E0);
    for (final ring in land) {
      final first = _project(ring[0].dx, ring[0].dy, size);
      final path = Path()..moveTo(first.dx, first.dy);
      for (var i = 1; i < ring.length; i++) {
        final p = _project(ring[i].dx, ring[i].dy, size);
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    final faint = Paint()..color = muted.withValues(alpha: 0.45);
    others.forEach((code, d) {
      canvas.drawCircle(_project((d['lon'] as num).toDouble(), (d['lat'] as num).toDouble(), size), 1.8, faint);
    });
    final dot = Paint()..color = indigo;
    final halo = Paint()..color = indigo.withValues(alpha: 0.18);
    dests.forEach((code, d) {
      final p = _project((d['lon'] as num).toDouble(), (d['lat'] as num).toDouble(), size);
      if (code == selected) {
        canvas.drawCircle(p, 9, Paint()..color = orange.withValues(alpha: 0.3));
        canvas.drawCircle(p, 4.5, Paint()..color = orange);
      } else {
        canvas.drawCircle(p, 5, halo);
        canvas.drawCircle(p, 2.6, dot);
      }
    });
    for (final code in App.prefs.airports) {
      final o = _origins[code];
      if (o == null) continue;
      final p = _project(o.dx, o.dy, size);
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = navy);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.dests != dests || old.selected != selected;
}
