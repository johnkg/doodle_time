import 'package:flutter/material.dart';

import 'draw_screen.dart';
import 'drawing_store.dart';
import 'emoji_font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEmojiFont();
  runApp(
    KidsDrawApp(
      store: PrefsDrawingStore(),
      progressStore: PrefsProgressStore(),
    ),
  );
}

class KidsDrawApp extends StatelessWidget {
  const KidsDrawApp({super.key, this.store, this.progressStore, this.now});

  /// Null in tests so nothing touches device storage.
  final DrawingStore? store;
  final ProgressStore? progressStore;

  /// Clock for tests. Null = real time.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doodle Time',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        fontFamilyFallback: kEmojiFallback,
      ),
      home: DrawScreen(
        store: store,
        progressStore: progressStore,
        now: now,
      ),
    );
  }
}
