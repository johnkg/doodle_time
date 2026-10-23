import 'package:shared_preferences/shared_preferences.dart';

/// Where the current drawing is kept between launches.
abstract class DrawingStore {
  Future<String?> load();
  Future<void> save(String json);
}

/// Uses shared_preferences (localStorage on web).
class PrefsDrawingStore implements DrawingStore {
  static const _key = 'doodle_time_drawing_v1';

  @override
  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> save(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json);
  }
}

/// Which lessons the child has finished (their sticker collection).
abstract class ProgressStore {
  Future<Set<String>> loadDone();
  Future<void> saveDone(Set<String> done);
}

class PrefsProgressStore implements ProgressStore {
  static const _key = 'doodle_time_done_v1';

  @override
  Future<Set<String>> loadDone() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  @override
  Future<void> saveDone(Set<String> done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, done.toList());
  }
}
