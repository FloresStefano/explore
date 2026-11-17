import 'package:flutter/material.dart';

import 'common.dart';
import 'data.dart';

/// AI tourist card (7.1): classic sights within 100 km and what is special in the travel period.
Future<void> showGuide(BuildContext context, Json o) {
  final body = _GuideBody(o);
  if (isWide(context)) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760), child: body),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => _GuideBody(o, controller: controller),
    ),
  );
}

class _GuideBody extends StatelessWidget {
  const _GuideBody(this.o, {this.controller});
  final Json o;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final city = o['city'] ?? o['destination'];
    return FutureBuilder(
      future: App.ai.guide(o),
      builder: (context, snap) {
        final g = snap.data;
        final children = <Widget>[
          Row(children: [
            const Icon(Icons.auto_awesome, color: violet, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(g?['title'] as String? ?? 'Cosa vedere a $city',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ),
            if (isWide(context)) IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          Text('Dal ${fmtDay(o['out_date'])} al ${fmtDay(o['ret_date'])} · città e dintorni entro 100 km',
              style: const TextStyle(fontSize: 12.5, color: muted)),
          const SizedBox(height: 16),
        ];
        if (snap.connectionState != ConnectionState.done) {
          children.addAll([
            const SizedBox(height: 30),
            const Center(child: CircularProgressIndicator(color: violet)),
            const SizedBox(height: 16),
            const Text('Sto preparando la scheda con l\'AI.\nLa prima volta serve una ventina di secondi.',
                textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ]);
        } else if (g == null || g['error'] != null) {
          children.add(EmptyNote('Scheda non disponibile: ${g?['error'] ?? 'errore'}.\nRiprova tra poco.'));
        } else {
          children.addAll([
            Text('${g['intro']}', style: const TextStyle(fontSize: 14.5, height: 1.45)),
            if ((g['weather'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _Note(Icons.thermostat_outlined, g['weather'] as String),
            ],
            const _Section('Da non perdere'),
            for (final c in (g['classics'] as List? ?? const []).cast<Json>())
              _Item(
                title: '${c['name']}',
                trailing: (c['distance_km'] as num? ?? 0) > 0 ? '${c['distance_km']} km' : 'in città',
                text: '${c['why']}',
              ),
            const _Section('In quel periodo'),
            for (final p in (g['period'] as List? ?? const []).cast<Json>())
              _Item(title: '${p['name']}', trailing: '${p['when']}', text: '${p['note']}'),
            if ((g['tips'] as List? ?? const []).isNotEmpty) ...[
              const _Section('Consigli pratici'),
              for (final t in (g['tips'] as List)) _Note(Icons.lightbulb_outline, '$t'),
            ],
            const SizedBox(height: 16),
            Text(
              'Testo generato dall\'AI (${g['model'] ?? 'Workers AI'}) il ${g['generated'] ?? ''}: '
              'date ed eventi vanno verificati prima di partire.',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ]);
        }
        return ListView(controller: controller, padding: const EdgeInsets.fromLTRB(22, 8, 22, 28), children: children);
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: violet)),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.title, required this.trailing, required this.text});
  final String title, trailing, text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Tag(trailing, color: violet, bg: violetBg),
          ]),
          const SizedBox(height: 3),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4A4F6A), height: 1.4)),
        ]),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: violet),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ]),
      );
}
