import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import 'settings.dart';

/// Area 4: price trends per route. The time axis is the observation date.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? _route;
  String? _pair;

  Future<Map<String, String>> _routes(List<String> airports) async {
    final out = <String, String>{};
    for (final a in airports) {
      (await App.repo.routes(a)).forEach((code, d) {
        if (((d as Json)['months'] as List? ?? const []).isEmpty) return; // never priced yet
        out['$a-$code'] = '${airportCity[a] ?? a} – ${d['city'] ?? code}';
      });
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => a.value.compareTo(b.value)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.prefs,
      builder: (context, _) => PageShell(
        headerHeight: 150,
        header: HeaderTitle(
          kicker: 'Andamento dei prezzi',
          title: 'Statistiche',
          action: RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
        ),
        child: FutureBuilder(
          key: ValueKey(App.prefs.airports.join()),
          future: _routes(App.prefs.airports),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            final routes = snap.data ?? {};
            if (routes.isEmpty) {
              return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [EmptyNote('Nessuna tratta con prezzi rilevati, per ora.')]);
            }
            final route = routes.containsKey(_route) ? _route! : routes.keys.first;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                WhiteCard(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tratta', style: TextStyle(fontSize: 12, color: muted)),
                    DropdownButton<String>(
                      value: route,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
                      items: [for (final e in routes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => setState(() {
                        _route = v;
                        _pair = null;
                      }),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                FutureBuilder(
                  key: ValueKey(route),
                  future: App.repo.history(route),
                  builder: (context, h) {
                    if (h.connectionState != ConnectionState.done) {
                      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                    }
                    final obs = ((h.data?['observations'] as List?) ?? const []).cast<List>();
                    if (obs.isEmpty) return const EmptyNote('Storico non ancora disponibile per questa tratta.');
                    // Monitor: per observation date, best price among future departures.
                    final monitor = <String, double>{};
                    final pairs = <String, Map<String, double>>{};
                    for (final o in obs) {
                      final observed = o[0] as String, price = (o[3] as num).toDouble();
                      if ((o[1] as String).compareTo(observed) > 0) {
                        monitor[observed] = monitor[observed] == null || price < monitor[observed]! ? price : monitor[observed]!;
                      }
                      (pairs['${o[1]}_${o[2]}'] ??= {})[observed] = price;
                    }
                    final pairKeys = pairs.keys.toList()..sort();
                    final pair = pairs.containsKey(_pair) ? _pair! : pairKeys.first;
                    String pairLabel(String k) => '${fmtDay(k.substring(0, 10))} – ${fmtDay(k.substring(11))}';
                    return Column(children: [
                      _ChartCard(
                        title: 'Monitor della tratta',
                        subtitle: 'Il miglior prezzo tra le partenze future, per data di rilevazione',
                        series: monitor,
                      ),
                      const SizedBox(height: 14),
                      _ChartCard(
                        title: 'Curva di una partenza',
                        subtitle: 'Prenoto ora o aspetto?',
                        series: pairs[pair]!,
                        picker: DropdownButton<String>(
                          value: pair,
                          isExpanded: true,
                          underline: const SizedBox(),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink),
                          items: [for (final k in pairKeys) DropdownMenuItem(value: k, child: Text(pairLabel(k)))],
                          onChanged: (v) => setState(() => _pair = v),
                        ),
                      ),
                    ]);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.series, this.picker});
  final String title, subtitle;
  final Map<String, double> series; // observation date -> price
  final Widget? picker;

  @override
  Widget build(BuildContext context) {
    final keys = series.keys.toList()..sort();
    final values = [for (final k in keys) series[k]!];
    return WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
        ?picker,
        const SizedBox(height: 10),
        if (values.isEmpty)
          const Text('Nessuna rilevazione.', style: TextStyle(color: muted))
        else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(euro(values.last), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: indigo)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('ultima rilevazione · ${fmtDay(keys.last)}', style: const TextStyle(fontSize: 12, color: muted)),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(height: 130, width: double.infinity, child: CustomPaint(painter: _LinePainter(values))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmtDay(keys.first), style: const TextStyle(fontSize: 11, color: muted)),
            Text(
              keys.length < 2 ? 'Lo storico è appena iniziato: il grafico cresce ogni giorno' : fmtDay(keys.last),
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE6E8F2)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    var lo = values.reduce((a, b) => a < b ? a : b), hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) {
      lo -= 5;
      hi += 5;
    }
    Offset at(int i) => Offset(
          values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1),
          size.height - (values[i] - lo) / (hi - lo) * (size.height - 16) - 8,
        );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    if (values.length > 1) {
      final area = Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = indigo.withValues(alpha: 0.08));
    }
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..color = indigo);
    final last = at(values.length - 1);
    canvas.drawCircle(last, 5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 3.5, Paint()..color = indigo);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values;
}
