import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import '../ticket.dart';

/// Groups offers by a key, cheapest group first (the minimum price leads the order).
List<(String, List<Json>)> groupOffers(List<Json> offers, String Function(Json) key, {bool byKey = false}) {
  final groups = <String, List<Json>>{};
  for (final o in offers) {
    (groups[key(o)] ??= []).add(o);
  }
  final list = groups.entries.map((e) => (e.key, e.value)).toList();
  if (byKey) {
    list.sort((a, b) => a.$1.compareTo(b.$1));
  } else {
    num min(List<Json> l) => l.map((o) => o['price'] as num).reduce((a, b) => a < b ? a : b);
    list.sort((a, b) => min(a.$2).compareTo(min(b.$2)));
  }
  return list;
}

String countryBadge(List<Json> offers) {
  final cc = (offers.first['country_code'] as String? ?? '').toUpperCase();
  return cc.isEmpty ? '?' : cc;
}

AggregateCard countryCard(BuildContext context, String country, List<Json> offers,
    {required String section, List<String> path = const []}) {
  final stats = Stats(offers);
  final cities = {for (final o in offers) o['city']}.length;
  final name = country.isEmpty ? 'Altro' : country;
  return AggregateCard(
    badge: countryBadge(offers),
    title: name,
    subtitle: '$cities ${cities == 1 ? 'meta' : 'mete'} · ${stats.n} ${stats.n == 1 ? 'offerta' : 'offerte'}',
    stats: stats,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OffersScreen(section: section, path: [...path, name], offers: offers)),
    ),
  );
}

/// Header of a detail page: back button, the section as kicker, the last choice as title.
Widget _detailHeader(BuildContext context, String section, List<String> path) => HeaderTitle(
      leading: RoundIcon(Icons.arrow_back, tooltip: 'Indietro', onTap: () => Navigator.pop(context)),
      kicker: section,
      title: path.last,
    );

/// Second level: the countries inside one choice (e.g. a month).
class CountriesScreen extends StatelessWidget {
  const CountriesScreen({super.key, required this.section, required this.path, required this.offers});
  final String section; // Home, Calendario, Mappa
  final List<String> path; // the hierarchical choice, e.g. ["Dicembre 2026"]
  final List<Json> offers;

  @override
  Widget build(BuildContext context) {
    final groups = groupOffers(offers, (o) => o['country'] as String? ?? '');
    return Scaffold(
      body: PageShell(
        headerHeight: sectionHeaderHeight,
        header: _detailHeader(context, section, path),
        child: ResponsiveList(
          header: [ChoiceRecap(path: path, offers: offers), const SizedBox(height: 14)],
          itemCount: groups.length,
          itemBuilder: (context, i) => countryCard(context, groups[i].$1, groups[i].$2, section: section, path: path),
        ),
      ),
    );
  }
}

/// Last level: the offers, with the sort menu.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key, required this.section, required this.path, required this.offers});
  final String section;
  final List<String> path;
  final List<Json> offers;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _sort = 'prezzo_asc';

  static const _sorts = {
    'prezzo_asc': 'Prezzo crescente',
    'prezzo_desc': 'Prezzo decrescente',
    'consigliate': 'Prezzo per ora utile',
    'data': 'Data di partenza',
    'ferie_asc': 'Meno giorni di ferie',
    'ferie_desc': 'Più giorni di ferie',
    'meta': 'Destinazione A-Z',
  };

  int _compare(Json a, Json b) {
    num n(Json o, String k) => (o[k] as num?) ?? double.infinity;
    final byPrice = n(a, 'price').compareTo(n(b, 'price'));
    int then(int c) => c != 0 ? c : byPrice;
    return switch (_sort) {
      'prezzo_desc' => -byPrice,
      'consigliate' => then(n(a, 'price_per_hour').compareTo(n(b, 'price_per_hour'))),
      'data' => then((a['out_date'] as String).compareTo(b['out_date'] as String)),
      'ferie_asc' => then(n(a, 'leave_days').compareTo(n(b, 'leave_days'))),
      'ferie_desc' => then(n(b, 'leave_days').compareTo(n(a, 'leave_days'))),
      'meta' => then('${a['city']}'.compareTo('${b['city']}')),
      _ => byPrice,
    };
  }

  @override
  Widget build(BuildContext context) {
    final offers = [...widget.offers]..sort(_compare);
    return Scaffold(
      body: PageShell(
        headerHeight: sectionHeaderHeight,
        header: _detailHeader(context, widget.section, widget.path),
        child: ResponsiveList(
          minItemWidth: 430,
          spacing: 14,
          header: [
            ChoiceRecap(path: widget.path, offers: widget.offers),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: SortMenu(value: _sort, options: _sorts, onChanged: (v) => setState(() => _sort = v)),
            ),
            const SizedBox(height: 12),
            if (offers.isEmpty) const EmptyNote('Nessuna offerta.', icon: Icons.filter_alt_off_outlined),
          ],
          itemCount: offers.length,
          itemBuilder: (context, i) => TicketCard(offers[i]),
        ),
      ),
    );
  }
}

class SortMenu extends StatelessWidget {
  const SortMenu({super.key, required this.value, required this.options, required this.onChanged});
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Ordina',
        initialValue: value,
        onSelected: onChanged,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (_) => [
          for (final e in options.entries)
            PopupMenuItem(
              value: e.key,
              child: Text(e.value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: e.key == value ? FontWeight.w700 : FontWeight.w400,
                      color: e.key == value ? indigo : ink)),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.swap_vert, size: 17, color: indigo),
            const SizedBox(width: 6),
            Text(options[value]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink)),
            const Icon(Icons.expand_more, size: 18, color: muted),
          ]),
        ),
      );
}
