import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;

const _pagesData = 'https://floresstefano.github.io/explore/data/';

/// Reads the static JSON files published by the daily job. A missing file or
/// field never throws: a source can be temporarily down (spec, section 10).
class Repo {
  Repo()
      : base = kIsWeb && Uri.base.host.endsWith('github.io') ? Uri.base.resolve('data/') : Uri.parse(_pagesData);
  final Uri base;
  final _cache = <String, Future<dynamic>>{};

  Future<dynamic> get(String path) {
    return _cache[path] ??= _fetch(path).then((v) {
      if (v == null) _cache.remove(path);
      return v;
    });
  }

  Future<dynamic> _fetch(String path) async {
    try {
      final r = await http.get(base.resolve(path)).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    return null;
  }

  Future<List<Json>> top() async => _list((await get('top.json'))?['offers']);
  Future<Json?> meta() async => (await get('meta.json')) as Json?;
  Future<Json?> settings() async => (await get('settings.json')) as Json?;
  Future<Json> patrons() async => ((await get('patrons.json')) as Json?) ?? {};
  Future<List<Json>> windows() async => _list((await get('windows/national.json'))?['windows']);
  Future<Json?> history(String route) async => (await get('history/$route.json')) as Json?;

  /// Destinations of one airport: code -> info.
  Future<Json> routes(String airport) async =>
      ((await get('routes/$airport.json'))?['destinations'] as Json?) ?? {};

  /// Offers for one date pair, merged over the given airports.
  Future<List<Json>> offersFor(String key, List<String> airports) async {
    final files = await Future.wait(airports.map((a) => get('offers/$a.json')));
    return [for (final f in files) ..._list(f?['pairs']?[key]?['offers'])];
  }

  static List<Json> _list(dynamic v) => v is List ? v.cast<Json>() : const [];
}

/// USR settings: kept on the device only.
class Prefs extends ChangeNotifier {
  SharedPreferences? _sp;
  List<String> airports = ['VRN', 'BGY', 'TSF'];
  String comune = 'Verona';

  Future<void> load() async {
    try {
      _sp = await SharedPreferences.getInstance();
      airports = _sp!.getStringList('USR-04') ?? airports;
      comune = _sp!.getString('USR-01') ?? comune;
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

  void setComune(String value) {
    comune = value;
    _sp?.setString('USR-01', value);
    notifyListeners();
  }
}

class App {
  App._();
  static final repo = Repo();
  static final prefs = Prefs();
}
