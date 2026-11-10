import 'dart:math';

import 'models.dart';

/// Procedural terrain: value noise for height and moisture, mapped to biomes.
/// The same seed always gives the same map, so only the seed and the cells
/// the player changed need to be saved (we save everything for simplicity).
World generateWorld({int? seed, int size = 12, String theme = 'una valle incantata con animali parlanti'}) {
  seed ??= Random().nextInt(1 << 30);
  final height = _Noise(seed);
  final moisture = _Noise(seed + 7919);
  final cells = <Cell>[];
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final h = height.at(x / 4.0, y / 4.0);
      final m = moisture.at(x / 3.0, y / 3.0);
      cells.add(Cell(x: x, y: y, biome: _biome(h, m)));
    }
  }
  final world = World(seed: seed, width: size, height: size, cells: cells, theme: theme);
  // Start in the middle, in a cozy village.
  world.px = size ~/ 2;
  world.py = size ~/ 2;
  cells[world.py * size + world.px] = Cell(x: world.px, y: world.py, biome: Biome.villaggio);
  return world;
}

Biome _biome(double h, double m) {
  if (h < 0.28) return Biome.lago;
  if (h < 0.34) return Biome.spiaggia;
  if (h > 0.78) return Biome.montagna;
  if (h > 0.64) return Biome.collina;
  if (m > 0.55) return Biome.bosco;
  if (m < 0.2 && h > 0.45) return Biome.villaggio;
  return Biome.prato;
}

class _Noise {
  _Noise(int seed) : _seed = seed;
  final int _seed;

  // Seeded Random per lattice point: small multipliers and xor keep it within
  // 32-bit-safe math, so it also works when compiled to JavaScript.
  double _rand(int x, int y) => Random(((x * 73856093) ^ (y * 19349663) ^ _seed) & 0x3FFFFFFF).nextDouble();

  double at(double x, double y) {
    final x0 = x.floor(), y0 = y.floor();
    final fx = _smooth(x - x0), fy = _smooth(y - y0);
    final a = _rand(x0, y0), b = _rand(x0 + 1, y0);
    final c = _rand(x0, y0 + 1), d = _rand(x0 + 1, y0 + 1);
    final top = a + (b - a) * fx;
    final bottom = c + (d - c) * fx;
    return top + (bottom - top) * fy;
  }

  double _smooth(double t) => t * t * (3 - 2 * t);
}
