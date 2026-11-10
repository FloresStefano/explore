import 'package:flutter/foundation.dart';

import '../services/api.dart';
import '../services/storage.dart';
import 'models.dart';
import 'world_gen.dart';

/// Game rules live here, on the device. The AI only interprets text and
/// narrates; this class decides what actually changes and saves it.
class GameController extends ChangeNotifier {
  GameController({StoryApi? api, SaveStore? store})
      : _api = api ?? StoryApi(),
        _store = store ?? SaveStore();

  final StoryApi _api;
  final SaveStore _store;

  World? world;
  final List<LogEntry> log = [];
  Uint8List? image;

  bool ready = false;
  bool thinking = false;
  bool drawing = false;

  Cell get here => world!.here;

  Future<void> init() async {
    await _store.open();
    world = _store.loadWorld();
    if (world == null) {
      world = generateWorld();
      _say('Benvenuto, esploratore! Scrivi o di\' cosa vuoi fare: "vai a nord", "guarda", "raccogli il fiore"... '
          'Scrivi "aiuto" per i suggerimenti.');
    } else {
      _say('Bentornato! Riprendiamo da dove eravamo rimasti.');
    }
    ready = true;
    notifyListeners();
    await _enter(announce: true);
  }

  Future<void> newGame() async {
    await _store.reset();
    world = generateWorld();
    log.clear();
    image = null;
    _say('Un nuovo mondo è nato! Buona esplorazione.');
    notifyListeners();
    await _enter(announce: true);
  }

  /// Handles one player command, typed or spoken.
  Future<void> submit(String input) async {
    final text = input.trim();
    if (text.isEmpty || thinking || world == null) return;
    log.add(LogEntry(text, fromPlayer: true));
    thinking = true;
    notifyListeners();
    try {
      final local = _quickParse(text);
      if (local != null) {
        await _apply(local);
      } else {
        Map<String, dynamic> action;
        try {
          action = await _api.interpret(text, _context());
        } on ApiException catch (e) {
          _say(_offlineLine(e));
          return;
        }
        await _apply(action);
      }
      await _store.saveWorld(world!);
    } finally {
      thinking = false;
      notifyListeners();
    }
  }

  // ---------- actions ----------

  Future<void> _apply(Map<String, dynamic> a) async {
    final w = world!;
    final cell = here;
    final reply = (a['reply'] as String?)?.trim() ?? '';
    final object = (a['object'] as String?)?.trim() ?? '';
    final target = (a['target'] as String?)?.trim() ?? '';

    switch (a['action']) {
      case 'move':
        final (dx, dy, name) = switch (a['direction']) {
          'n' => (0, -1, 'nord'),
          's' => (0, 1, 'sud'),
          'e' => (1, 0, 'est'),
          _ => (-1, 0, 'ovest'),
        };
        final nx = w.px + dx, ny = w.py + dy;
        if (!w.inside(nx, ny)) {
          _say('Verso $name c\'è una nebbiolina dorata: è il confine del mondo conosciuto. Meglio esplorare altrove!');
          return;
        }
        w.px = nx;
        w.py = ny;
        _say('Ti incammini verso $name...');
        await _enter(announce: true);
      case 'look':
        if (object.isEmpty || reply.isEmpty) {
          _say(cell.description.isNotEmpty ? cell.description : _fallbackDescription(cell));
        } else {
          _say(reply);
        }
      case 'take':
        final item = _match(cell.items, object);
        if (item == null) {
          _say(object.isEmpty ? 'Cosa vuoi prendere?' : 'Qui non vedo "$object".');
          return;
        }
        cell.items.remove(item);
        w.inventory.add(item);
        cell.addEvent('il giocatore ha raccolto: $item');
        cell.descriptionStale = true;
        _say(reply.isNotEmpty ? reply : 'Hai preso: $item.');
        await _refreshText(announce: false);
      case 'drop':
        final item = _match(w.inventory, object);
        if (item == null) {
          _say('Nel tuo zaino non c\'è "$object".');
          return;
        }
        w.inventory.remove(item);
        cell.items.add(item);
        cell.addEvent('il giocatore ha lasciato qui: $item');
        cell.descriptionStale = true;
        _say(reply.isNotEmpty ? reply : 'Hai lasciato: $item.');
        await _refreshText(announce: false);
      case 'give':
        final item = _match(w.inventory, object);
        if (item == null) {
          _say('Nel tuo zaino non c\'è "$object".');
          return;
        }
        w.inventory.remove(item);
        cell.addEvent('il giocatore ha regalato $item a $target');
        cell.descriptionStale = true;
        _say(reply.isNotEmpty ? reply : 'Hai regalato $item a $target.');
      case 'talk':
        cell.addEvent('il giocatore ha parlato con $target');
        _say(reply.isNotEmpty ? reply : '$target ti sorride.');
      case 'use':
        cell.addEvent('il giocatore ha usato $object${target.isNotEmpty ? ' su $target' : ''}');
        _say(reply.isNotEmpty ? reply : 'Provi a usare $object...');
      case 'change':
        final add = List<String>.from(a['addFeatures'] ?? const []);
        final remove = List<String>.from(a['removeFeatures'] ?? const []);
        for (final r in remove) {
          final m = _match(cell.features, r);
          if (m != null) cell.features.remove(m);
        }
        cell.features.addAll(add.where((f) => _match(cell.features, f) == null));
        cell.addEvent('il giocatore ha cambiato il luogo: ${a['effect'] ?? add.join(', ')}');
        cell.descriptionStale = true;
        cell.imageStale = true;
        _say(reply.isNotEmpty ? reply : 'Il luogo cambia sotto i tuoi occhi!');
        await _refreshText();
      case 'inventory':
        _say(w.inventory.isEmpty ? 'Il tuo zaino è vuoto.' : 'Nel tuo zaino hai: ${w.inventory.join(', ')}.');
      case 'help':
        _say('Puoi muoverti (nord, sud, est, ovest), guardare, raccogliere o lasciare oggetti, '
            'parlare con i personaggi, regalare cose, e perfino cambiare i luoghi: '
            '"pianto un albero", "costruisco un ponte"...');
      default:
        _say(reply.isNotEmpty ? reply : 'Non ho capito bene. Prova con "aiuto".');
    }
  }

  // ---------- entering and narrating cells ----------

  Future<void> _enter({bool announce = false}) async {
    final cell = here;
    image = _store.image(cell.key);
    notifyListeners();
    if (!cell.discovered) await _discover(cell);
    if (cell.descriptionStale || cell.description.isEmpty) {
      await _refreshText(announce: announce);
    } else if (announce) {
      _say('${cell.title}\n${cell.description}');
    }
    await _store.saveWorld(world!);
  }

  Future<void> _discover(Cell cell) async {
    final w = world!;
    final neighbors = [
      for (final (dx, dy, dir) in const [(0, -1, 'n'), (0, 1, 's'), (1, 0, 'e'), (-1, 0, 'o')])
        if (w.inside(cell.x + dx, cell.y + dy))
          {
            'dir': dir,
            'terreno': w.at(cell.x + dx, cell.y + dy).biome.label,
            if (w.at(cell.x + dx, cell.y + dy).name.isNotEmpty) 'nome': w.at(cell.x + dx, cell.y + dy).name,
          },
    ];
    thinking = true;
    notifyListeners();
    try {
      final r = await _api.region({'terreno': cell.biome.label, 'vicini': neighbors}, w.theme);
      cell.name = '${r['name']}';
      cell.features = List<String>.from(r['features'] ?? const []);
      cell.items = List<String>.from(r['items'] ?? const []);
      cell.npcs = [for (final n in (r['npcs'] ?? const [])) Npc.fromJson(Map<String, dynamic>.from(n))];
    } on ApiException {
      cell.name = _capitalize(cell.biome.label);
      cell.features = _fallbackFeatures[cell.biome] ?? const [];
    } finally {
      thinking = false;
    }
    cell.discovered = true;
    cell.descriptionStale = true;
    cell.imageStale = true;
  }

  /// Regenerates the description, and the picture if something visible changed.
  Future<void> _refreshText({bool announce = true}) async {
    final cell = here;
    thinking = true;
    notifyListeners();
    try {
      final d = await _api.describe(cell.toAi());
      cell.title = '${d['title']}';
      cell.description = '${d['description']}';
      final prompt = '${d['imagePrompt']}';
      if (prompt.isNotEmpty) cell.imagePrompt = '$prompt Setting: ${cell.biome.english}.';
      cell.descriptionStale = false;
    } on ApiException catch (e) {
      cell.title = cell.name;
      cell.description = _fallbackDescription(cell);
      if (e.rateLimited) _say(_offlineLine(e));
    } finally {
      thinking = false;
      notifyListeners();
    }
    if (announce) _say('${cell.title}\n${cell.description}');
    if (cell.imageStale || _store.image(cell.key) == null) await _refreshImage(cell);
  }

  Future<void> _refreshImage(Cell cell) async {
    final prompt = cell.imagePrompt.isNotEmpty
        ? cell.imagePrompt
        : 'A ${cell.biome.english} with ${cell.features.join(', ')}.';
    drawing = true;
    notifyListeners();
    try {
      final bytes = await _api.image(prompt);
      await _store.putImage(cell.key, bytes);
      cell.imageStale = false;
      if (identical(cell, here)) image = bytes;
    } on ApiException {
      // Keep the old picture (or the coloured placeholder) and retry next visit.
    } finally {
      drawing = false;
      notifyListeners();
    }
  }

  // ---------- helpers ----------

  Map<String, dynamic> _context() {
    final w = world!;
    return {
      ...here.toAi(),
      'zaino': w.inventory,
      'uscite': [
        for (final (dx, dy, dir) in const [(0, -1, 'n'), (0, 1, 's'), (1, 0, 'e'), (-1, 0, 'o')])
          if (w.inside(w.px + dx, w.py + dy)) dir,
      ],
    };
  }

  void _say(String text) {
    log.add(LogEntry(text));
    notifyListeners();
  }

  String _offlineLine(ApiException e) => e.rateLimited
      ? 'Il narratore deve riprendere fiato... aspetta un minutino e riprova!'
      : 'Il narratore non riesce a sentirti (problema di connessione). Puoi comunque muoverti con nord, sud, est, ovest.';

  /// Commands that need no AI: saves time and free AI quota.
  static Map<String, dynamic>? _quickParse(String text) {
    final t = text.toLowerCase().replaceAll(RegExp(r"[^a-zàèéìòù' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final move = RegExp(r"^(?:(?:vai|vado|andiamo|cammina|cammino|corri|corro)\s+)?(?:(?:a|al|verso|in direzione)\s+)?(nord|sud|est|ovest|n|s|e|o)$")
        .firstMatch(t);
    if (move != null) return {'action': 'move', 'direction': move.group(1)![0]};
    if (const {'inventario', 'zaino', 'i', 'cosa ho'}.contains(t)) return {'action': 'inventory'};
    if (const {'aiuto', 'help', 'cosa posso fare'}.contains(t)) return {'action': 'help'};
    if (const {'guarda', 'guardo', 'l', 'guardati intorno', 'mi guardo intorno', 'dove sono'}.contains(t)) {
      return {'action': 'look'};
    }
    return null;
  }

  /// Loose match of what the player said against a list of names.
  static String? _match(List<String> list, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    for (final s in list) {
      final l = s.toLowerCase();
      if (l == q || l.contains(q) || q.contains(l)) return s;
    }
    final words = q.split(' ').where((w) => w.length > 3).toSet();
    for (final s in list) {
      if (s.toLowerCase().split(' ').any(words.contains)) return s;
    }
    return null;
  }

  static String _fallbackDescription(Cell c) {
    final parts = <String>['Ti trovi in un ${c.biome.label}.'];
    if (c.features.isNotEmpty) parts.add('Intorno a te: ${c.features.join(', ')}.');
    if (c.items.isNotEmpty) parts.add('A terra noti: ${c.items.join(', ')}.');
    if (c.npcs.isNotEmpty) parts.add('Qui c\'è ${c.npcs.map((n) => n.name).join(' e ')}.');
    return parts.join(' ');
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _fallbackFeatures = {
    Biome.prato: ['fiori colorati', 'farfalle'],
    Biome.bosco: ['alberi alti', 'funghi'],
    Biome.lago: ['acqua limpida', 'ninfee'],
    Biome.spiaggia: ['sabbia dorata', 'conchiglie'],
    Biome.collina: ['erba morbida', 'un vecchio mulino'],
    Biome.montagna: ['rocce lisce', 'una cascatella'],
    Biome.villaggio: ['casette colorate', 'una fontana'],
  };
}
