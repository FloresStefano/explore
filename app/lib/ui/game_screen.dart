import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../game/engine.dart';
import '../game/models.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game});
  final GameController game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  GameController get game => widget.game;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _send([String? text]) {
    final t = (text ?? _input.text).trim();
    if (t.isEmpty) return;
    _input.clear();
    game.submit(t);
    _focus.requestFocus();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') setState(() => _listening = false);
        },
        onError: (_) => setState(() => _listening = false),
      );
      if (!_speechReady) {
        _snack('Il microfono non è disponibile su questo dispositivo o browser.');
        return;
      }
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'it_IT', partialResults: true, cancelOnError: true),
      onResult: (r) {
        _input.text = r.recognizedWords;
        if (r.finalResult) {
          setState(() => _listening = false);
          _send(r.recognizedWords);
        }
      },
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _confirmNewGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nuovo mondo?'),
        content: const Text('Il mondo attuale verrà cancellato e ne nascerà uno nuovo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Nuovo mondo')),
        ],
      ),
    );
    if (ok == true) await game.newGame();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.ready || game.world == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(
              title: Text(game.here.title.isNotEmpty ? game.here.title : 'Explore'),
              actions: [
                if (!wide)
                  IconButton(
                    tooltip: 'Mappa',
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: ListenableBuilder(listenable: game, builder: (_, _) => _MapView(world: game.world!)),
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Zaino',
                  icon: const Icon(Icons.backpack_outlined),
                  onPressed: () => game.submit('inventario'),
                ),
                IconButton(tooltip: 'Nuovo mondo', icon: const Icon(Icons.refresh), onPressed: _confirmNewGame),
              ],
            ),
            body: SafeArea(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _mainColumn(maxImageHeight: box.maxHeight * 0.45)),
                        SizedBox(
                          width: 340,
                          child: Padding(padding: const EdgeInsets.all(16), child: _MapView(world: game.world!)),
                        ),
                      ],
                    )
                  : _mainColumn(maxImageHeight: box.maxHeight * 0.32),
            ),
          );
        });
      },
    );
  }

  Widget _mainColumn({required double maxImageHeight}) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxImageHeight),
          child: _Scene(game: game),
        ),
        Expanded(child: _Log(entries: game.log)),
        if (game.thinking)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        _compass(),
        _inputBar(),
      ],
    );
  }

  Widget _compass() {
    Widget b(IconData icon, String label, String cmd) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton.icon(
            onPressed: game.thinking ? null : () => game.submit(cmd),
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 4,
        children: [
          b(Icons.arrow_back, 'Ovest', 'ovest'),
          b(Icons.arrow_upward, 'Nord', 'nord'),
          b(Icons.arrow_downward, 'Sud', 'sud'),
          b(Icons.arrow_forward, 'Est', 'est'),
          b(Icons.visibility_outlined, 'Guarda', 'guarda'),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: _listening ? 'Smetti di ascoltare' : 'Parla',
            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            color: _listening ? Colors.red : null,
            onPressed: game.thinking ? null : _toggleMic,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              enabled: !game.thinking,
              textInputAction: TextInputAction.send,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Cosa vuoi fare?',
                border: OutlineInputBorder(),
                counterText: '',
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(tooltip: 'Invia', icon: const Icon(Icons.send), onPressed: game.thinking ? null : _send),
        ],
      ),
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final cell = game.here;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: game.image != null
                ? Image.memory(game.image!, key: ValueKey(game.image.hashCode), fit: BoxFit.cover, gaplessPlayback: true)
                : Container(
                    key: ValueKey(cell.biome),
                    color: cell.biome.color,
                    alignment: Alignment.center,
                    child: Text(cell.biome.label, style: Theme.of(context).textTheme.headlineSmall),
                  ),
          ),
          if (game.drawing)
            Positioned(
              right: 12,
              bottom: 12,
              child: Chip(
                avatar: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                label: const Text('Sto disegnando...'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Log extends StatelessWidget {
  const _Log({required this.entries});
  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[entries.length - 1 - i];
        return Align(
          alignment: e.fromPlayer ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 640),
            decoration: BoxDecoration(
              color: e.fromPlayer ? scheme.primaryContainer : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(e.text, style: const TextStyle(fontSize: 16, height: 1.35)),
          ),
        );
      },
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.world});
  final World world;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mappa', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: world.width / world.height,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: world.width),
            itemCount: world.cells.length,
            itemBuilder: (context, i) {
              final c = world.cells[i];
              final isHere = c.x == world.px && c.y == world.py;
              return Tooltip(
                message: c.discovered ? c.name : '???',
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: c.discovered ? c.biome.color : c.biome.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                    border: isHere ? Border.all(color: Colors.red.shade700, width: 2) : null,
                  ),
                  child: isHere ? const FittedBox(child: Icon(Icons.person_pin_circle, color: Colors.red)) : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final b in Biome.values)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 12, height: 12, color: b.color),
                const SizedBox(width: 4),
                Text(b.label, style: Theme.of(context).textTheme.bodySmall),
              ]),
          ],
        ),
      ],
    );
  }
}
