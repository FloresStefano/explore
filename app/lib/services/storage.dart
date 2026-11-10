import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../game/models.dart';

/// Everything is saved on the device: IndexedDB on the web, files on mobile.
class SaveStore {
  late Box<String> _save;
  late Box<Uint8List> _images;

  Future<void> open() async {
    await Hive.initFlutter('explore');
    _save = await Hive.openBox<String>('save');
    _images = await Hive.openBox<Uint8List>('images');
  }

  World? loadWorld() {
    final raw = _save.get('world');
    if (raw == null) return null;
    try {
      return World.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null; // corrupt or old save: start over
    }
  }

  Future<void> saveWorld(World w) => _save.put('world', jsonEncode(w.toJson()));

  Uint8List? image(String cellKey) => _images.get(cellKey);

  Future<void> putImage(String cellKey, Uint8List bytes) => _images.put(cellKey, bytes);

  Future<void> reset() async {
    await _save.clear();
    await _images.clear();
  }
}
