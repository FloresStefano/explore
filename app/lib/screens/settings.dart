import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';

void openSettings(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

/// Next run of a daily cron "M H * * *" (UTC), in local time.
DateTime? nextRun(String? cron, DateTime now) {
  final p = (cron ?? '').split(' ');
  final m = int.tryParse(p.isNotEmpty ? p[0] : ''), h = int.tryParse(p.length > 1 ? p[1] : '');
  if (m == null || h == null) return null;
  final u = now.toUtc();
  var t = DateTime.utc(u.year, u.month, u.day, h, m);
  if (!t.isAfter(u)) t = t.add(const Duration(days: 1));
  return t.toLocal();
}

String inTime(Duration d) =>
    d.inHours >= 1 ? 'tra ${d.inHours} h ${d.inMinutes % 60} min' : 'tra ${d.inMinutes} min';

const _groups = {
  'FIN': 'Finestre di viaggio',
  'SEL': 'Selezione dei voli',
  'IMP': 'Offerte imperdibili',
  'JOB': 'Raccolta dei dati',
};

/// "Le mie preferenze" (USR, on the device) clearly apart from the selection rules,
/// shown read-only straight from the file the job publishes.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});
  final bool embedded; // shown as a tab of the side menu instead of a pushed page

  static String _value(dynamic v, String? unit) {
    final s = switch (v) {
      true => 'Sì',
      false => 'No',
      List l => l.join(unit == 'ora' ? ' – ' : ', '),
      Map m => m.entries.map((e) => '${e.key} ${e.value}').join(' · '),
      _ => '$v',
    };
    return unit == null || unit == 'ora' || unit == 'MM-GG' || unit == 'cron UTC' ? s : '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageShell(
        headerHeight: 150,
        maxWidth: 980,
        header: HeaderTitle(
          leading: embedded ? null : RoundIcon(Icons.arrow_back, tooltip: 'Indietro', onTap: () => Navigator.pop(context)),
          kicker: 'Preferenze e regole',
          title: 'Impostazioni',
        ),
        child: ListenableBuilder(
          listenable: App.prefs,
          builder: (context, _) => FutureBuilder(
            future: Future.wait([App.repo.settings(), App.repo.meta(), App.repo.calendar()]),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Loading(filters: false);
              final settings = snap.data?[0];
              final meta = snap.data?[1];
              final cal = snap.data?[2];
              final prefs = App.prefs;
              final entries = ((settings?['settings'] as List?) ?? const []).cast<Json>();
              final all = ((settings?['job']?['airports'] as List?)?.cast<String>()) ?? const ['VRN', 'BGY', 'TSF'];
              String valueOf(String id) => '${entries.firstWhere((e) => e['id'] == id, orElse: () => {})['value'] ?? ''}';
              final ctx = (cal?['context'] as Json?) ?? const {};
              final runAt = DateTime.tryParse('${meta?['run_at'] ?? ''}')?.toLocal();
              final next = nextRun(valueOf('JOB-08'), DateTime.now());
              final sources = ((meta?['sources'] as Json?) ?? const {});
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _Section(
                    title: 'Le mie preferenze',
                    subtitle: 'Salvate solo su questo dispositivo',
                    icon: Icons.person_outline,
                    children: [
                      _Row(
                        id: 'USR-04',
                        name: 'Aeroporti di partenza',
                        child: Wrap(runSpacing: 6, children: [
                          for (final a in all)
                            Pill('${airportCity[a] ?? a} ($a)',
                                selected: prefs.airports.contains(a), onTap: () => prefs.toggleAirport(a)),
                        ]),
                      ),
                      _Row(id: 'USR-01', name: 'Comune di residenza', value: '${ctx['comune'] ?? 'Verona'}',
                          note: 'Weekend, weekend+ e ponti sono calcolati per questo comune'),
                      _Row(id: 'USR-02', name: 'Calendario scolastico', value: cap('${ctx['region'] ?? '–'}')),
                      _Row(id: 'USR-03', name: 'Patrono', value: '${ctx['saint'] ?? '–'} · ${ctx['patron'] ?? ''}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Aggiornamento dei dati',
                    subtitle: 'Il job gira su GitHub Actions e pubblica i dati su GitHub Pages',
                    icon: Icons.schedule,
                    children: [
                      _Row(
                        name: 'Ultima raccolta',
                        value: runAt == null ? 'non disponibile' : fmtDateTime(runAt),
                        note: runAt == null ? null : 'Dati di ${ago(runAt)}',
                      ),
                      _Row(
                        id: 'JOB-08',
                        name: 'Prossimo aggiornamento',
                        value: next == null ? '–' : fmtDateTime(next),
                        note: next == null
                            ? null
                            : '${inTime(next.difference(DateTime.now()))} · ogni giorno; GitHub può ritardare '
                                'di qualche minuto',
                      ),
                      for (final e in sources.entries)
                        _Row(
                          name: 'Fonte ${e.key}',
                          value: (e.value as Json)['enabled'] == false
                              ? 'spenta'
                              : '${(e.value as Json)['calls'] ?? 0} chiamate · ${(e.value as Json)['errors'] ?? 0} errori',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final g in _groups.entries) ...[
                    _Section(
                      title: g.value,
                      subtitle: g.key == 'FIN' ? 'Regole di selezione · sola lettura' : null,
                      icon: Icons.rule,
                      children: [
                        for (final r in entries.where((e) => (e['id'] as String).startsWith(g.key)))
                          _Row(
                            id: r['id'] as String,
                            name: '${r['name']}',
                            value: _value(r['value'], r['unit'] as String?),
                            note: r['note'] as String?,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => WhiteCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: indigo),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: Fs.titleLg, fontWeight: FontWeight.w700)),
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 28),
              child: Text(subtitle!, style: const TextStyle(fontSize: Fs.label, color: muted)),
            ),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}

/// Name and value stand out; the ID is there, small and grey.
class _Row extends StatelessWidget {
  const _Row({required this.name, this.id, this.value, this.note, this.child});
  final String name;
  final String? id, value, note;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F1F6)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w600, color: ink)),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(value!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w700, color: indigo)),
              ),
            ],
          ]),
          if (child != null) Padding(padding: const EdgeInsets.only(top: 8), child: child),
          if (note != null || id != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (note != null)
                  Expanded(child: Text(note!, style: const TextStyle(fontSize: Fs.label, color: muted, height: 1.35)))
                else
                  const Spacer(),
                if (id != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(id!, style: TextStyle(fontSize: Fs.caption, color: muted.withValues(alpha: 0.8))),
                  ),
              ]),
            ),
        ]),
      );
}
