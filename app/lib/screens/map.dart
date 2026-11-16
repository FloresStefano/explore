import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common.dart';
import '../data.dart';
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
  String? _monthFilter;
  String? _selected;

  static Future<List<List<Offset>>> _loadLand() async {
    final rings = jsonDecode(await rootBundle.loadString('assets/europe_land.json')) as List;
    return [
      for (final r in rings)
        [for (final p in r as List) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())],
    ];
  }

  Future<(List<List<Offset>>, Map<String, Json>, Map<String, Json>)> _load(List<String> airports) async {
    final land = await (_land ??= _loadLand());
    final dests = <String, Json>{};
    final origins = <String, Json>{};
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
    return (land, dests, origins);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.prefs,
      builder: (context, _) {
        final prefs = App.prefs;
        return PageShell(
          headerHeight: 150,
          header: HeaderTitle(
            kicker: 'Mete dirette',
            title: 'Mappa',
            action: RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
          ),
          child: FutureBuilder(
            key: ValueKey(prefs.airports.join()),
            future: _load(prefs.airports),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final (land, all, _) = snap.data!;
              final months = <String>{for (final d in all.values) ...(d['months'] as Set).cast<String>()}.toList()..sort();
              final dests = {
                for (final e in all.entries)
                  if (_monthFilter == null || (e.value['months'] as Set).contains(_monthFilter)) e.key: e.value,
              };
              final sel = _selected == null ? null : dests[_selected];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  WhiteCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final a in const ['VRN', 'BGY', 'TSF'])
                            Pill(airportCity[a]!, selected: prefs.airports.contains(a), onTap: () => prefs.toggleAirport(a)),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
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
                                  child: CustomPaint(size: size, painter: _MapPainter(land, dests, _selected)),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        dests.isEmpty
                            ? 'Nessuna rotta disponibile al momento.'
                            : '${dests.length} mete dirette · tocca un punto, pizzica per ingrandire',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _monthPill('Tutto l\'anno', null),
                      for (final m in months) _monthPill(fmtMonth(DateTime.parse('$m-01')), m),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  if (sel != null)
                    WhiteCard(
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
                          child: Text(_selected!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${sel['city'] ?? sel['name']}, ${sel['country'] ?? ''}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              'Da ${(sel['from'] as List).map((a) => airportCity[a] ?? a).join(', ')} · '
                              '${(sel['airlines'] as Set).join(', ')}',
                              style: const TextStyle(fontSize: 12.5, color: muted),
                            ),
                            if (sel['last_confirmed'] != null)
                              Text('Ultima conferma ${fmtDay(sel['last_confirmed'] as String)}',
                                  style: const TextStyle(fontSize: 11.5, color: muted)),
                          ]),
                        ),
                      ]),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _monthPill(String label, String? m) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: _monthFilter == m ? indigo : Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _monthFilter = m),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _monthFilter == m ? Colors.white : ink)),
            ),
          ),
        ),
      );

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
  _MapPainter(this.land, this.dests, this.selected);
  final List<List<Offset>> land;
  final Map<String, Json> dests;
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
