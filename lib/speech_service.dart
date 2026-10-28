import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads lesson steps aloud for children who can't read yet.
/// Created lazily; any failure (no voice installed, browser blocks it) is
/// ignored so drawing never breaks.
class SpeechService {
  FlutterTts? _tts;
  int _voiceTries = 0;
  bool _voicePicked = false;

  /// Keeps plain English words only: drops emoji and symbols so the voice
  /// doesn't try to read them.
  static String speakable(String text) => text
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Cheerful delivery: a closing "!" lifts the voice at the end of the line.
  static String lively(String words) =>
      RegExp(r'[.!?]$').hasMatch(words) ? words : '$words!';

  // Novelty voices that ship with macOS/iOS; fun for a minute, bad for lessons.
  static const _novelty = [
    'albert',
    'bad news',
    'bahh',
    'bells',
    'boing',
    'bubbles',
    'cellos',
    'deranged',
    'fred',
    'good news',
    'hysterical',
    'junior',
    'kathy',
    'organ',
    'princess',
    'ralph',
    'superstar',
    'trinoids',
    'whisper',
    'wobble',
    'zarvox',
  ];

  // Warm, natural English voices, best first. Names are matched in lowercase.
  static const _preferred = {
    'natural': 100, // Edge "Online (Natural)" neural voices
    'ava': 80,
    'google us english': 75,
    'samantha': 70,
    'allison': 65,
    'google uk english female': 65,
    'nicky': 60,
    'tessa': 55,
    'moira': 55,
    'karen': 50,
    'zira': 40,
  };

  /// Best English voice from `{name, locale}` maps, or null when none is
  /// English. Prefers neural/natural and friendly voices over robotic ones.
  static Map<String, String>? pickVoice(List<Map<String, String>> voices) {
    Map<String, String>? best;
    int bestScore = -1;
    for (final v in voices) {
      final name = (v['name'] ?? '').toLowerCase();
      final locale = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
      if (!locale.startsWith('en')) continue;
      if (_novelty.any(name.contains)) continue;
      int score = 1;
      for (final e in _preferred.entries) {
        if (name.contains(e.key) && e.value > score) score = e.value;
      }
      if (name.contains('enhanced') || name.contains('premium')) score += 20;
      if (locale == 'en-us') score += 5;
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best;
  }

  Future<void> _chooseVoice(FlutterTts tts) async {
    // Browsers load their voice list late, so allow a few tries.
    if (_voicePicked || _voiceTries >= 4) return;
    _voiceTries++;
    final raw = await tts.getVoices;
    if (raw is! List) return;
    final voices = [
      for (final v in raw)
        if (v is Map)
          {
            'name': '${v['name'] ?? ''}',
            'locale': '${v['locale'] ?? ''}',
          },
    ];
    final pick = pickVoice(voices);
    if (pick == null) return;
    await tts.setVoice(pick);
    _voicePicked = true;
  }

  Future<void> speak(String text) async {
    final words = speakable(text);
    if (words.isEmpty) return;
    try {
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      try {
        await _chooseVoice(tts);
      } catch (_) {
        // Keep the default voice.
      }
      // The web passes the rate straight to the browser (1.0 = normal), but
      // phones use 0.5 for normal speed. 0.4 on the web was very slow.
      await tts.setSpeechRate(kIsWeb ? 0.95 : 0.5);
      await tts.setPitch(kIsWeb ? 1.3 : 1.2);
      await tts.speak(lively(words));
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
