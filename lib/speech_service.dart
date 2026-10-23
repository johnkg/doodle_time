import 'package:flutter_tts/flutter_tts.dart';

/// Reads lesson steps aloud for children who can't read yet.
/// Created lazily; any failure (no voice installed, browser blocks it) is
/// ignored so drawing never breaks.
class SpeechService {
  FlutterTts? _tts;

  /// Keeps plain English words only: drops emoji and symbols so the voice
  /// doesn't try to read them.
  static String speakable(String text) => text
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> speak(String text) async {
    final words = speakable(text);
    if (words.isEmpty) return;
    try {
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      await tts.setSpeechRate(0.4);
      await tts.setPitch(1.1);
      await tts.speak(words);
    } catch (_) {
      // Ignore: voice unavailable.
    }
  }

  void dispose() {
    try {
      _tts?.stop();
    } catch (_) {
      // Ignore.
    }
  }
}
