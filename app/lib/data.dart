import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;

const _pagesData = 'https://floresstefano.github.io/explore/data/';
const aiBase = 'https://weekend-ai.explore-ai.workers.dev';

/// Reads the static JSON files published by the daily job. A missing file or
/// field never throws: a source can be temporarily down (spec, section 10).
class Repo {
  Repo()
      : base = kIsWeb && (Uri.base.host.endsWith('github.io') || Uri.base.host == 'localhost')
            ? Uri.base.resolve('data/')
            : Uri.parse(_pagesData);
  final Uri base;
  final _cache = <String, Future<dynamic>>{};
  final _catalog = <String, Future<List<Json>>>{};

  Future<dynamic> get(String path) {
    return _cache[path] ??= _fetch(path).then((v) {
      if (v == null) _cache.remove(path);
      return v;
    });
  }

  Future<dynamic> _fetch(String path) async {
    try {
      final r = await http.get(base.resolve(path)).timeout(const Duration(seconds: 40));
      if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    return null;
  }

  void refresh() {
    _cache.clear();
    _catalog.clear();
  }

  Future<List<Json>> top() async => _list((await get('top.json'))?['offers']);
  Future<Json?> meta() async => (await get('meta.json')) as Json?;
  Future<Json?> settings() async => (await get('settings.json')) as Json?;
  Future<Json?> calendar() async => (await get('calendar.json')) as Json?;
  Future<Json> patrons() async => ((await get('patrons.json')) as Json?) ?? {};
  Future<Json?> history(String route) async => (await get('history/$route.json')) as Json?;

  /// Destinations of one airport: code -> info.
  Future<Json> routes(String airport) async =>
      ((await get('routes/$airport.json'))?['destinations'] as Json?) ?? {};

  /// Every published offer from the given airports, flat, cheapest first.
  Future<List<Json>> catalog(List<String> airports) {
    final key = ([...airports]..sort()).join(',');
    return _catalog[key] ??= () async {
      final files = await Future.wait(airports.map((a) => get('offers/$a.json')));
      final out = <Json>[];
      for (final f in files) {
        final pairs = (f?['pairs'] as Json?) ?? const {};
        for (final p in pairs.values) {
          for (final o in _list((p as Json)['offers'])) {
            if (o['type'] != null) out.add(o);
          }
        }
      }
      out.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
      if (out.isEmpty) _catalog.remove(key);
      return out;
    }();
  }

  static List<Json> _list(dynamic v) => v is List ? v.cast<Json>() : const [];
}

/// Calls to the AI Worker (Cloudflare Workers AI, free tier).
class Ai {
  final _guides = <String, Future<Json>>{};
  Future<Json>? _recap;

  Future<Json> recap() => _recap ??= _call(http.get(Uri.parse('$aiBase/recap'))).then((v) {
        if (v.containsKey('error')) _recap = null;
        return v;
      });

  Future<Json> guide(Json o) {
    final key = '${o['destination']}:${(o['out_date'] as String).substring(0, 7)}';
    return _guides[key] ??= _call(http.post(
      Uri.parse('$aiBase/guide'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'code': o['destination'],
        'city': o['city'] ?? o['destination'],
        'country': o['country'] ?? '',
        'out': o['out_date'],
        'ret': o['ret_date'],
      }),
    )).then((v) {
      if (v.containsKey('error')) _guides.remove(key);
      return v;
    });
  }

  static Future<Json> _call(Future<http.Response> req) async {
    try {
      final r = await req.timeout(const Duration(seconds: 90));
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Json;
      if (r.statusCode != 200) return {'error': body['message'] ?? 'Errore ${r.statusCode}'};
      return body;
    } catch (e) {
      return {'error': 'Servizio AI non raggiungibile'};
    }
  }
}

/// USR settings: kept on the device only.
class Prefs extends ChangeNotifier {
  SharedPreferences? _sp;
  List<String> airports = ['VRN', 'BGY', 'TSF'];
  bool sideMenuExpanded = true;

  Future<void> load() async {
    try {
      _sp = await SharedPreferences.getInstance();
      airports = _sp!.getStringList('USR-04') ?? airports;
      sideMenuExpanded = _sp!.getBool('ui.sideMenu') ?? true;
    } catch (_) {}
    notifyListeners();
  }

  void toggleAirport(String code) {
    final next = [...airports];
    next.contains(code) ? next.remove(code) : next.add(code);
    if (next.isEmpty) return; // at least one departure airport
    airports = next;
    _sp?.setStringList('USR-04', airports);
    notifyListeners();
  }

  void toggleSideMenu() {
    sideMenuExpanded = !sideMenuExpanded;
    _sp?.setBool('ui.sideMenu', sideMenuExpanded);
    notifyListeners();
  }
}

/// Kind of break and month chosen in the combo boxes: one choice shared by
/// Home, Calendar and Map while the app is open.
class SharedFilter extends ChangeNotifier {
  SharedFilter() {
    // ?mese=2026-12 opens the app on that month.
    final m = Uri.base.queryParameters['mese'];
    if (m != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(m)) month = m;
  }

  String? type;
  String? month;

  void setType(String? v) {
    type = v;
    notifyListeners();
  }

  void setMonth(String? v) {
    month = v;
    notifyListeners();
  }
}

class App {
  App._();
  static final repo = Repo();
  static final prefs = Prefs();
  static final ai = Ai();
  static final filter = SharedFilter();

  /// Rebuild on device settings or on the shared filter.
  static final changes = Listenable.merge([prefs, filter]);
}

/// Filters shared by Home, Calendar and Map.
class OfferFilter {
  const OfferFilter({this.type, this.month, this.day, this.from, this.to, this.country, this.destination});
  final String? type;
  final String? month; // yyyy-mm of the departure
  final DateTime? day; // the trip contains this day
  final DateTime? from; // the trip is inside [from, to]
  final DateTime? to;
  final String? country;
  final String? destination;

  bool test(Json o) {
    if (type != null && o['type'] != type) return false;
    final out = o['out_date'] as String;
    if (month != null && !out.startsWith(month!)) return false;
    if (country != null && o['country'] != country) return false;
    if (destination != null && o['destination'] != destination) return false;
    if (day != null || from != null) {
      final a = DateTime.parse(out), b = DateTime.parse(o['ret_date'] as String);
      if (day != null && (day!.isBefore(a) || day!.isAfter(b))) return false;
      if (from != null && (a.isBefore(from!) || b.isAfter(to ?? from!))) return false;
    }
    return true;
  }

  List<Json> apply(List<Json> offers) => offers.where(test).toList();

  OfferFilter copyWith({String? country, String? destination, String? month}) => OfferFilter(
        type: type,
        month: month ?? this.month,
        day: day,
        from: from,
        to: to,
        country: country ?? this.country,
        destination: destination ?? this.destination,
      );
}

/// Months (yyyy-mm) covered by the offers: the scan depth decides the choice.
List<String> monthsOf(List<Json> offers) =>
    {for (final o in offers) (o['out_date'] as String).substring(0, 7)}.toList()..sort();
