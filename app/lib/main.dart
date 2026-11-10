import 'package:flutter/material.dart';

import 'game/engine.dart';
import 'ui/game_screen.dart';

void main() {
  runApp(const ExploreApp());
}

class ExploreApp extends StatefulWidget {
  const ExploreApp({super.key});

  @override
  State<ExploreApp> createState() => _ExploreAppState();
}

class _ExploreAppState extends State<ExploreApp> {
  final game = GameController();

  @override
  void initState() {
    super.initState();
    game.init();
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66BB6A)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66BB6A), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: GameScreen(game: game),
    );
  }
}
