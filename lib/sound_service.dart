import 'package:audioplayers/audioplayers.dart';

/// Tiny sound effects. Players are created on first use so tests and
/// startup never touch the audio plugin. Sound is a nice-to-have, so any
/// audio failure is swallowed and never breaks drawing.
class SoundService {
  bool enabled = true;
  final Map<String, AudioPlayer> _players = {};

  Future<void> play(String fileName) async {
    if (!enabled) return;
    try {
      final player = _players.putIfAbsent(fileName, () => AudioPlayer());
      await player.stop();
      await player.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Ignore: no audio device, autoplay blocked, etc.
    }
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
  }
}
