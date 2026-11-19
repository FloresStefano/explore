import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';

void openSettings(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

void openInfo(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen()));

/// The two round buttons at the top right of every section on phones: Informazioni, Impostazioni.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        RoundIcon(Icons.info_outline_rounded, tooltip: 'Informazioni', onTap: () => openInfo(context)),
        const SizedBox(width: Sp.sm),
        RoundIcon(Icons.tune, tooltip: 'Impostazioni', onTap: () => openSettings(context)),
      ]);
}

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

/// Shell shared by Impostazioni and Informazioni: pushed page on phones, side-menu tab on desktop.
class _Page extends StatelessWidget {
  const _Page({required this.embedded, required this.kicker, required this.title, required this.child});
  final bool embedded;
  final String kicker, title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: PageShell(
          headerHeight: 110,
          maxWidth: 980,
          header: HeaderTitle(
            leading:
                embedded ? null : RoundIcon(Icons.arrow_back, tooltip: 'Indietro', onTap: () => Navigator.pop(context)),
            kicker: kicker,
            title: title,
          ),
          child: child,
        ),
      );
}

// ---------- Impostazioni: only what can be changed ----------

/// Departure airports and destination countries, saved on this device.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) => _Page(
        embedded: embedded,
        kicker: 'Le mie scelte',
        title: 'Impostazioni',
        child: ListenableBuilder(
          listenable: App.prefs,
          builder: (context, _) => FutureBuilder(
            future: App.repo.settings(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Loading(filters: false);
              final all = ((snap.data?['job']?['airports'] as List?)?.cast<String>()) ?? const ['VRN', 'BGY', 'TSF'];
              final prefs = App.prefs;
              return ListView(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.xxl),
                children: [
                  _Section(
                    title: 'Aeroporti di partenza',
                    subtitle: 'Cerchiamo i voli solo da quelli accesi. Almeno uno resta sempre attivo.',
                    icon: Icons.flight_takeoff_rounded,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.md),
                        child: Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
                          for (final a in all)
                            Pill('${airportCity[a] ?? a} ($a)',
                                selected: prefs.airports.contains(a), onTap: () => prefs.toggleAirport(a)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.lg),
                  _Countries(airports: all),
                  const SizedBox(height: Sp.lg),
                  const Center(
                    child: Text('Le scelte restano salvate su questo dispositivo.',
                        style: TextStyle(fontSize: Fs.label, color: muted)),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

/// Every destination country with offers; switching one off hides its offers in every section.
class _Countries extends StatelessWidget {
  const _Countries({required this.airports});
  final List<String> airports;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: App.repo.catalog(airports, all: true),
        builder: (context, snap) {
          final counts = <String, int>{}, names = <String, String>{};
          for (final o in snap.data ?? const <Json>[]) {
            final code = '${o['country_code'] ?? ''}'.toLowerCase();
            if (code.isEmpty) continue;
            counts[code] = (counts[code] ?? 0) + 1;
            names[code] = '${o['country'] ?? code.toUpperCase()}';
          }
          final codes = names.keys.toList()..sort((a, b) => names[a]!.compareTo(names[b]!));
          final off = App.prefs.excludedCountries;
          final on = codes.where((c) => !off.contains(c)).length;
          return _Section(
            title: 'Paesi di destinazione',
            subtitle: 'Spegni un paese e le offerte verso le sue città spariscono da tutte le sezioni.',
            icon: Icons.public_rounded,
            trailing: codes.isEmpty
                ? null
                : Text('$on di ${codes.length}',
                    style: const TextStyle(fontSize: Fs.small, fontWeight: FontWeight.w700, color: indigo)),
            children: [
              if (snap.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.all(Sp.lg), child: Center(child: CircularProgressIndicator()))
              else ...[
                Padding(
                  padding: const EdgeInsets.only(top: Sp.xs, bottom: Sp.sm),
                  child: Row(children: [
                    TextButton(
                        onPressed: off.isEmpty ? null : () => App.prefs.setAllCountries(true, codes),
                        child: const Text('Accendi tutti')),
                    TextButton(
                        onPressed: on == 0 ? null : () => App.prefs.setAllCountries(false, codes),
                        child: const Text('Spegni tutti')),
                  ]),
                ),
                LayoutBuilder(builder: (context, box) {
                  final cols = (box.maxWidth / 280).floor().clamp(1, 3);
                  final w = (box.maxWidth - (cols - 1) * Sp.sm) / cols;
                  return Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
                    for (final c in codes)
                      SizedBox(
                        width: w,
                        child: _CountryTile(code: c, name: names[c]!, offers: counts[c]!, on: !off.contains(c)),
                      ),
                  ]);
                }),
                const SizedBox(height: Sp.md),
              ],
            ],
          );
        },
      );
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.code, required this.name, required this.offers, required this.on});
  final String code, name;
  final int offers;
  final bool on;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? const Color(0xFFF4F7FE) : const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(Rd.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rd.md),
          onTap: () => App.prefs.toggleCountry(code),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.xs, Sp.xs, Sp.xs),
            child: Row(children: [
              AnimatedContainer(
                duration: Motion.fast,
                width: 34,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(color: on ? navy : faint, borderRadius: BorderRadius.circular(Rd.xs)),
                alignment: Alignment.center,
                child: Text(code.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: Fs.caption, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w600, color: on ? ink : muted)),
                  Text('$offers offerte', style: const TextStyle(fontSize: Fs.caption, color: muted)),
                ]),
              ),
              Switch(value: on, onChanged: (_) => App.prefs.toggleCountry(code)),
            ]),
          ),
        ),
      );
}

// ---------- Informazioni: read-only, grouped in tabs ----------

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  static int _tab = 0; // kept while the app is open

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
  Widget build(BuildContext context) => _Page(
        embedded: widget.embedded,
        kicker: 'Come funziona',
        title: 'Informazioni',
        child: FutureBuilder(
          future: Future.wait([App.repo.settings(), App.repo.meta(), App.repo.calendar()]),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading(filters: false);
            final settings = snap.data?[0];
            final meta = snap.data?[1];
            final cal = snap.data?[2];
            final entries = ((settings?['settings'] as List?) ?? const []).cast<Json>();
            String valueOf(String id) => '${entries.firstWhere((e) => e['id'] == id, orElse: () => {})['value'] ?? ''}';
            List<Widget> rules(String prefix) => [
                  for (final r in entries.where((e) => (e['id'] as String).startsWith(prefix)))
                    _Row(
                      id: r['id'] as String,
                      name: '${r['name']}',
                      value: _value(r['value'], r['unit'] as String?),
                      note: r['note'] as String?,
                    ),
                ];
            final ctx = (cal?['context'] as Json?) ?? const {};
            final runAt = DateTime.tryParse('${meta?['run_at'] ?? ''}')?.toLocal();
            final next = nextRun(valueOf('JOB-08'), DateTime.now());
            final sources = ((meta?['sources'] as Json?) ?? const {});
            final tabs = [
              // Profilo
              [
                _Section(
                  title: 'Il tuo calendario',
                  subtitle: 'Weekend, weekend+ e ponti sono calcolati su questi dati',
                  icon: Icons.person_outline_rounded,
                  children: [
                    _Row(id: 'USR-01', name: 'Comune di residenza', value: '${ctx['comune'] ?? 'Verona'}'),
                    _Row(id: 'USR-02', name: 'Calendario scolastico', value: cap('${ctx['region'] ?? '–'}')),
                    _Row(id: 'USR-03', name: 'Patrono', value: '${ctx['saint'] ?? '–'} · ${ctx['patron'] ?? ''}'),
                  ],
                ),
              ],
              // Dati
              [
                _Section(
                  title: 'Aggiornamento dei dati',
                  subtitle: 'Il job gira su GitHub Actions e pubblica i dati su GitHub Pages',
                  icon: Icons.schedule_rounded,
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
                          : '${inTime(next.difference(DateTime.now()))} · ogni sera; GitHub può ritardare di qualche minuto',
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
                const SizedBox(height: Sp.lg),
                _Section(title: 'Raccolta dei dati', icon: Icons.cloud_sync_outlined, children: rules('JOB')),
              ],
              // Viaggi
              [
                _Section(
                  title: 'Finestre di viaggio',
                  subtitle: 'Quando un viaggio è un weekend, un weekend+ o un ponte',
                  icon: Icons.event_note_rounded,
                  children: rules('FIN'),
                ),
              ],
              // Voli
              [
                _Section(
                  title: 'Selezione dei voli',
                  subtitle: 'Quali voli entrano nelle offerte',
                  icon: Icons.rule_rounded,
                  children: rules('SEL'),
                ),
                const SizedBox(height: Sp.lg),
                _Section(title: 'Offerte imperdibili', icon: Icons.local_offer_outlined, children: rules('IMP')),
              ],
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.xxl),
              children: [
                SegmentTabs(
                  bg: Colors.white,
                  tabs: const [
                    (Icons.person_outline_rounded, 'Profilo'),
                    (Icons.schedule_rounded, 'Dati'),
                    (Icons.event_note_rounded, 'Viaggi'),
                    (Icons.rule_rounded, 'Voli'),
                  ],
                  selected: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: Sp.lg),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  child: Column(key: ValueKey(_tab), children: tabs[_tab]),
                ),
              ],
            );
          },
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => WhiteCard(
        padding: const EdgeInsets.fromLTRB(Sp.lg + 2, Sp.lg, Sp.lg + 2, Sp.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: indigo),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(title, style: const TextStyle(fontSize: Fs.titleLg, fontWeight: FontWeight.w700))),
            ?trailing,
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 28),
              child: Text(subtitle!, style: const TextStyle(fontSize: Fs.label, color: muted)),
            ),
          const SizedBox(height: Sp.sm),
          ...children,
        ]),
      );
}

/// Name and value stand out; the ID is there, small and grey.
class _Row extends StatelessWidget {
  const _Row({required this.name, this.id, this.value, this.note});
  final String name;
  final String? id, value, note;

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
