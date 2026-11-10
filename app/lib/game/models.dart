import 'package:flutter/material.dart';

/// Terrain types of the grid. The terrain is procedural; everything else in a
/// cell (name, features, items, characters) is invented by the AI on discovery.
enum Biome {
  prato('prato fiorito', 'flowery meadow', Color(0xFF9CCC65)),
  bosco('bosco', 'friendly forest', Color(0xFF43A047)),
  lago('laghetto', 'small clear lake', Color(0xFF4FC3F7)),
  spiaggia('spiaggia', 'sandy beach', Color(0xFFFFE082)),
  collina('collina', 'rolling hill', Color(0xFFC5E1A5)),
  montagna('montagna', 'gentle mountain', Color(0xFFBCAAA4)),
  villaggio('villaggio', 'tiny cozy village', Color(0xFFFFB74D));

  const Biome(this.label, this.english, this.color);
  final String label;
  final String english;
  final Color color;
}

class Npc {
  Npc({required this.name, required this.kind, required this.mood});

  final String name;
  final String kind;
  final String mood;

  factory Npc.fromJson(Map<String, dynamic> j) => Npc(
        name: '${j['name'] ?? 'Qualcuno'}',
        kind: '${j['kind'] ?? 'amico'}',
        mood: '${j['mood'] ?? 'allegro'}',
      );

  Map<String, dynamic> toJson() => {'name': name, 'kind': kind, 'mood': mood};

  @override
  String toString() => '$name ($kind, $mood)';
}

class Cell {
  Cell({required this.x, required this.y, required this.biome});

  final int x;
  final int y;
  final Biome biome;

  /// False until the AI has invented the content of this cell.
  bool discovered = false;
  String name = '';
  List<String> features = [];
  List<String> items = [];
  List<Npc> npcs = [];

  /// What the player did here, newest last. Feeds the description.
  List<String> events = [];

  String title = '';
  String description = '';
  String imagePrompt = '';

  /// The text must be regenerated because the state changed.
  bool descriptionStale = true;

  /// The picture must be regenerated because something visible changed.
  bool imageStale = true;

  String get key => '$x,$y';

  void addEvent(String e) {
    events.add(e);
    if (events.length > 12) events = events.sublist(events.length - 12);
  }

  /// State sent to the AI, kept small.
  Map<String, dynamic> toAi() => {
        'terreno': biome.label,
        if (name.isNotEmpty) 'nome': name,
        'elementi': features,
        'oggetti': items,
        'personaggi': npcs.map((n) => n.toJson()).toList(),
        'eventi_recenti': events,
      };

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'biome': biome.name,
        'discovered': discovered,
        'name': name,
        'features': features,
        'items': items,
        'npcs': npcs.map((n) => n.toJson()).toList(),
        'events': events,
        'title': title,
        'description': description,
        'imagePrompt': imagePrompt,
        'descriptionStale': descriptionStale,
        'imageStale': imageStale,
      };

  factory Cell.fromJson(Map<String, dynamic> j) {
    final c = Cell(x: j['x'], y: j['y'], biome: Biome.values.byName(j['biome']));
    c.discovered = j['discovered'] ?? false;
    c.name = j['name'] ?? '';
    c.features = List<String>.from(j['features'] ?? const []);
    c.items = List<String>.from(j['items'] ?? const []);
    c.npcs = [for (final n in (j['npcs'] ?? const [])) Npc.fromJson(Map<String, dynamic>.from(n))];
    c.events = List<String>.from(j['events'] ?? const []);
    c.title = j['title'] ?? '';
    c.description = j['description'] ?? '';
    c.imagePrompt = j['imagePrompt'] ?? '';
    c.descriptionStale = j['descriptionStale'] ?? true;
    c.imageStale = j['imageStale'] ?? true;
    return c;
  }
}

class World {
  World({required this.seed, required this.width, required this.height, required this.cells, required this.theme});

  final int seed;
  final int width;
  final int height;
  final String theme;
  final List<Cell> cells;

  int px = 0;
  int py = 0;
  List<String> inventory = [];

  Cell at(int x, int y) => cells[y * width + x];
  Cell get here => at(px, py);
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'width': width,
        'height': height,
        'theme': theme,
        'px': px,
        'py': py,
        'inventory': inventory,
        'cells': cells.map((c) => c.toJson()).toList(),
      };

  factory World.fromJson(Map<String, dynamic> j) {
    final w = World(
      seed: j['seed'],
      width: j['width'],
      height: j['height'],
      theme: j['theme'] ?? 'una valle incantata',
      cells: [for (final c in j['cells']) Cell.fromJson(Map<String, dynamic>.from(c))],
    );
    w.px = j['px'];
    w.py = j['py'];
    w.inventory = List<String>.from(j['inventory'] ?? const []);
    return w;
  }
}

/// A line in the adventure log.
class LogEntry {
  LogEntry(this.text, {this.fromPlayer = false});
  final String text;
  final bool fromPlayer;
}
