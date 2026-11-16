import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';

void openSettings(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

/// USR entries are editable and stay on the device; every other rule is shown
/// read-only with its ID, straight from the file the job publishes.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<(Json?, Json)> _data = () async {
    return (await App.repo.settings(), await App.repo.patrons());
  }();

  static String _value(dynamic v, String? unit) {
    final s = switch (v) {
      true => 'Sì',
      false => 'No',
      List l => l.join(unit == 'ora' ? ' - ' : ', '),
      Map m => m.entries.map((e) => '${e.key} ${e.value}').join(', '),
      _ => '$v',
    };
    return unit == null || unit == 'ora' || unit == 'MM-GG' ? s : '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageShell(
        headerHeight: 150,
        header: HeaderTitle(
          leading: RoundIcon(Icons.arrow_back, tooltip: 'Indietro', onTap: () => Navigator.pop(context)),
          kicker: 'Preferenze e regole',
          title: 'Impostazioni',
        ),
        child: ListenableBuilder(
          listenable: App.prefs,
          builder: (context, _) => FutureBuilder(
            future: _data,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final settings = snap.data?.$1;
              final patrons = snap.data?.$2 ?? {};
              final prefs = App.prefs;
              final comuni = {...patrons.keys, prefs.comune}.toList();
              final p = patrons[prefs.comune] as Json?;
              final all = ((settings?['job']?['airports'] as List?)?.cast<String>()) ?? const ['VRN', 'BGY', 'TSF'];
              final rules = ((settings?['settings'] as List?) ?? const [])
                  .cast<Json>()
                  .where((e) => e['editable'] != 'user')
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  WhiteCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Le tue preferenze', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const Text('Salvate solo su questo dispositivo', style: TextStyle(fontSize: 12, color: muted)),
                      const SizedBox(height: 14),
                      _Field(
                        id: 'USR-01',
                        label: 'Comune di residenza',
                        child: DropdownButton<String>(
                          value: prefs.comune,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [for (final c in comuni) DropdownMenuItem(value: c, child: Text(c))],
                          onChanged: (v) => v == null ? null : prefs.setComune(v),
                        ),
                      ),
                      _Field(id: 'USR-02', label: 'Regione (calendario scolastico)', value: '${p?['region'] ?? '–'}'),
                      _Field(
                          id: 'USR-03',
                          label: 'Festa del patrono',
                          value: p == null ? '–' : '${p['saint']} · ${p['patron']}'),
                      const SizedBox(height: 6),
                      const _IdLabel('USR-04', 'Aeroporti di partenza'),
                      const SizedBox(height: 8),
                      Wrap(children: [
                        for (final a in all)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Pill('${airportCity[a] ?? a} ($a)',
                                selected: prefs.airports.contains(a), onTap: () => prefs.toggleAirport(a)),
                          ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  WhiteCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Regole di selezione', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const Text('Sola lettura: cosa viene mostrato e cosa viene scartato',
                          style: TextStyle(fontSize: 12, color: muted)),
                      const SizedBox(height: 8),
                      if (rules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Regole non disponibili al momento.', style: TextStyle(color: muted)),
                        ),
                      for (final r in rules)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 62, child: Tag('${r['id']}')),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${r['name']}', style: const TextStyle(fontSize: 13, color: muted)),
                                const SizedBox(height: 2),
                                Text(_value(r['value'], r['unit'] as String?),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IdLabel extends StatelessWidget {
  const _IdLabel(this.id, this.label);
  final String id, label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Tag(id),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: muted))),
      ]);
}

class _Field extends StatelessWidget {
  const _Field({required this.id, required this.label, this.value, this.child});
  final String id, label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _IdLabel(id, label),
            child ??
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text(value ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
          ]),
        ),
      );
}
