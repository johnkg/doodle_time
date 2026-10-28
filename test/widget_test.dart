import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:doodle_time/daily.dart';
import 'package:doodle_time/drawing_controller.dart';
import 'package:doodle_time/drawing_store.dart';
import 'package:doodle_time/guides.dart';
import 'package:doodle_time/main.dart';
import 'package:doodle_time/models.dart';
import 'package:doodle_time/pages.dart';
import 'package:doodle_time/parental_gate.dart';
import 'package:doodle_time/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements DrawingStore {
  String? data;

  @override
  Future<String?> load() async => data;

  @override
  Future<void> save(String json) async => data = json;
}

class MemoryProgress implements ProgressStore {
  Set<String> done = {};

  @override
  Future<Set<String>> loadDone() async => {...done};

  @override
  Future<void> saveDone(Set<String> d) async => done = {...d};
}

void main() {
  const size = Size(100, 100);

  testWidgets('app starts with action buttons', (tester) async {
    await tester.pumpWidget(const KidsDrawApp());
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Pictures'), findsOneWidget);
    expect(find.text('Grown-ups'), findsOneWidget);
  });

  testWidgets('grown-ups button opens the math gate', (tester) async {
    await tester.pumpWidget(const KidsDrawApp());
    await tester.tap(find.text('Grown-ups'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Grown-ups only'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  group('drawing', () {
    test('stroke can be undone and redone', () {
      final c = DrawingController();
      c.pointerDown(const Offset(10, 10), size);
      c.pointerMove(const Offset(30, 30), size);
      c.pointerUp();
      expect(c.ops.length, 1);
      c.undo();
      expect(c.ops, isEmpty);
      c.redo();
      expect(c.ops.length, 1);
    });

    test('new action clears redo history', () {
      final c = DrawingController();
      c.pointerDown(const Offset(10, 10), size);
      c.pointerUp();
      c.undo();
      expect(c.canRedo, isTrue);
      c.pointerDown(const Offset(20, 20), size);
      c.pointerUp();
      expect(c.canRedo, isFalse);
    });

    test('single tap leaves a dot', () {
      final c = DrawingController();
      c.pointerDown(const Offset(50, 50), size);
      c.pointerUp();
      expect(c.ops.single, isA<StrokeOp>());
    });

    test('stamp tool adds a stamp on tap', () {
      final c = DrawingController();
      c.setStamp('⭐');
      c.pointerDown(const Offset(50, 50), size);
      c.pointerUp();
      expect(c.ops.single, isA<StampOp>());
    });

    test('picking a color after eraser returns to brush', () {
      final c = DrawingController();
      c.setTool(Tool.eraser);
      c.setColor(kPalette[3]);
      expect(c.tool, Tool.brush);
    });
  });

  group('coloring pages', () {
    test('fill tool colors the region under the tap', () {
      final c = DrawingController();
      c.setPage(coloringPages.first);
      expect(c.tool, Tool.fill);
      c.pointerDown(const Offset(5, 5), size); // sky
      c.pointerUp();
      final op = c.ops.single as FillOp;
      expect(op.region, 0);
    });

    test('tap outside any page leaves no fill on blank canvas', () {
      final c = DrawingController();
      c.setTool(Tool.fill);
      c.pointerDown(const Offset(5, 5), size);
      c.pointerUp();
      expect(c.ops, isEmpty);
    });

    test('switching page clears the drawing', () {
      final c = DrawingController();
      c.pointerDown(const Offset(10, 10), size);
      c.pointerUp();
      c.setPage(null);
      expect(c.ops, isEmpty);
    });

    test('every page has unique name and regions', () {
      final names = coloringPages.map((p) => p.name).toSet();
      expect(names.length, coloringPages.length);
      for (final p in coloringPages) {
        expect(p.regions, isNotEmpty);
      }
    });

    test('every region has enough visible area to tap', () {
      // Sample the page every half unit; each region must be the top one
      // somewhere in at least 12 square units (48 samples).
      final tooSmall = <String>[];
      for (final p in coloringPages) {
        final hits = List<int>.filled(p.regions.length, 0);
        for (double y = 0.25; y < 100; y += 0.5) {
          for (double x = 0.25; x < 100; x += 0.5) {
            for (int i = p.regions.length - 1; i >= 0; i--) {
              if (p.regions[i].path.contains(Offset(x, y))) {
                hits[i]++;
                break;
              }
            }
          }
        }
        for (int i = 0; i < hits.length; i++) {
          if (hits[i] < 48) tooSmall.add('${p.name} region $i (${hits[i]})');
        }
      }
      expect(tooSmall, isEmpty);
    });
  });

  group('persistence', () {
    test('drawing survives save and restore', () async {
      final store = MemoryStore();
      final a = DrawingController(store: store);
      a.setPage(coloringPages[1]);
      a.setColor(kPalette[5]);
      a.pointerDown(const Offset(5, 5), size); // fill water
      a.pointerUp();
      a.setTool(Tool.brush);
      a.pointerDown(const Offset(40, 40), size);
      a.pointerMove(const Offset(60, 60), size);
      a.pointerUp();
      a.setStamp('🐶');
      a.pointerDown(const Offset(70, 70), size);
      a.pointerUp();
      await a.saveNow();

      final b = DrawingController(store: store);
      await b.restore();
      expect(b.page?.name, coloringPages[1].name);
      expect(b.ops.length, 3);
      expect(b.ops[0], isA<FillOp>());
      expect(b.ops[1], isA<StrokeOp>());
      expect((b.ops[1] as StrokeOp).points.length, 2);
      expect(b.ops[2], isA<StampOp>());
      expect((b.ops[2] as StampOp).emoji, '🐶');
      a.dispose();
      b.dispose();
    });

    test('corrupt save is ignored', () async {
      final store = MemoryStore()..data = '{not json';
      final c = DrawingController(store: store);
      await c.restore();
      expect(c.ops, isEmpty);
      c.dispose();
    });

    test('unknown ops in save are skipped', () {
      final c = DrawingController();
      c.decode(
          '{"v":2,"page":null,"ops":[{"t":"zzz"},{"t":"f","i":0,"c":4278190080}]}');
      expect(c.ops.length, 1);
      expect(c.ops.single, isA<FillOp>());
    });

    test('fills from saves made before the page redraw are dropped', () {
      final c = DrawingController();
      c.decode('{"v":1,"page":"Fish","ops":['
          '{"t":"f","i":3,"c":4278190080},'
          '{"t":"s","c":4278190080,"w":16,"r":false,"e":false,'
          '"p":[0.1,0.1,0.2,0.2]}]}');
      expect(c.page?.name, 'Fish');
      expect(c.ops.single, isA<StrokeOp>());
    });
  });

  group('draw guides', () {
    test('every guide is well formed', () {
      final names = drawingGuides.map((g) => g.name).toSet();
      expect(names.length, drawingGuides.length);
      for (final g in drawingGuides) {
        expect(g.steps.length, inInclusiveRange(3, 8), reason: g.name);
        expect(g.level, inInclusiveRange(1, 3), reason: g.name);
        for (final s in g.steps) {
          expect(s.text, isNotEmpty, reason: g.name);
          expect(s.shapes, isNotEmpty, reason: '${g.name}: ${s.text}');
          for (final shape in s.shapes) {
            final b = shape.path.getBounds();
            expect(b.left, greaterThanOrEqualTo(0), reason: g.name);
            expect(b.top, greaterThanOrEqualTo(0), reason: g.name);
            expect(b.right, lessThanOrEqualTo(100), reason: g.name);
            expect(b.bottom, lessThanOrEqualTo(100), reason: g.name);
          }
        }
      }
    });

    test('helper lines start each lesson and are gone in the last step', () {
      for (final g in drawingGuides) {
        bool has(GuideStep s, GuideKind k) => s.shapes.any((x) => x.kind == k);
        expect(g.steps.any((s) => has(s, GuideKind.guide)), isTrue,
            reason: g.name);
        expect(has(g.steps.last, GuideKind.guide), isFalse, reason: g.name);
        expect(g.steps.any((s) => has(s, GuideKind.shade)), isTrue,
            reason: g.name);
      }
    });

    testWidgets('lesson walks through steps', (tester) async {
      await tester.pumpWidget(const KidsDrawApp());
      await tester.tap(find.text('Pictures'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();
      final n = drawingGuides.firstWhere((g) => g.name == 'Sun').steps.length;
      expect(find.textContaining('step 1 of $n'), findsOneWidget);
      await tester.tap(find.textContaining('Next'));
      await tester.pumpAndSettle();
      expect(find.textContaining('step 2 of $n'), findsOneWidget);
      await tester.tap(find.textContaining('Back'));
      await tester.pumpAndSettle();
      expect(find.textContaining('step 1 of $n'), findsOneWidget);
    });
  });

  group('daily drawing', () {
    test('same date gives the same lesson at any time of day', () {
      expect(
        dailyGuide(DateTime(2026, 10, 23, 0, 5)).name,
        dailyGuide(DateTime(2026, 10, 23, 23, 55)).name,
      );
    });

    test('walks through every lesson before repeating', () {
      final seen = <String>{};
      for (int i = 0; i < drawingGuides.length; i++) {
        seen.add(dailyGuide(DateTime(2026, 10, 1 + i)).name);
      }
      expect(seen.length, drawingGuides.length);
    });

    test('day key format', () {
      expect(dayKey(DateTime(2026, 3, 5)), 'day:2026-03-05');
    });

    test('streak counts back from today or yesterday', () {
      final today = DateTime(2026, 10, 23);
      expect(dailyStreak({}, today), 0);
      expect(dailyStreak({dayKey(today)}, today), 1);
      // Today not done yet: yesterday and the day before still count.
      expect(
        dailyStreak(
          {dayKey(DateTime(2026, 10, 22)), dayKey(DateTime(2026, 10, 21))},
          today,
        ),
        2,
      );
      // A gap breaks the streak.
      expect(
        dailyStreak({dayKey(today), dayKey(DateTime(2026, 10, 21))}, today),
        1,
      );
      expect(dailyStreak({dayKey(DateTime(2026, 10, 20))}, today), 0);
    });

    testWidgets('banner shows today lesson and starts it', (tester) async {
      final now = DateTime(2026, 10, 23, 9);
      final g = dailyGuide(now);
      await tester.pumpWidget(KidsDrawApp(now: () => now));
      expect(find.textContaining(RegExp('Draw an? ${g.name}')), findsOneWidget);
      await tester.tap(find.textContaining('Start'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('step 1 of ${g.steps.length}'),
        findsOneWidget,
      );
      expect(find.textContaining('Start'), findsNothing);
    });

    testWidgets('finishing the daily lesson marks the day', (tester) async {
      final now = DateTime(2026, 10, 23, 9);
      final g = dailyGuide(now);
      final progress = MemoryProgress();
      await tester.pumpWidget(
        KidsDrawApp(progressStore: progress, now: () => now),
      );
      await tester.tap(find.textContaining('Start'));
      await tester.pumpAndSettle();
      for (int i = 0; i < g.steps.length - 1; i++) {
        await tester.tap(find.textContaining('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.textContaining('Done'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Today's drawing done"), findsOneWidget);
      expect(progress.done, containsAll([g.name, dayKey(now)]));
      await tester.tap(find.textContaining('Yay'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Done today'), findsOneWidget);
    });
  });

  group('stickers and voice', () {
    testWidgets('finishing a lesson gives a sticker', (tester) async {
      final progress = MemoryProgress();
      await tester.pumpWidget(KidsDrawApp(progressStore: progress));
      await tester.tap(find.text('Pictures'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();
      final n = drawingGuides.firstWhere((g) => g.name == 'Sun').steps.length;
      for (int i = 0; i < n - 1; i++) {
        await tester.tap(find.textContaining('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.textContaining('Done'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You drew a Sun'), findsOneWidget);
      expect(find.textContaining('New sticker'), findsOneWidget);
      expect(progress.done, contains('Sun'));
    });

    // Share of the screen height the canvas must keep during a lesson.
    for (final (size, share) in const [
      (Size(1200, 800), 0.5),
      (Size(1400, 700), 0.5),
      (Size(390, 844), 0.44),
      (Size(360, 640), 0.25),
    ]) {
      testWidgets('lesson panel leaves the canvas room to draw on ($size)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const KidsDrawApp());
        await tester.tap(find.text('Pictures'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sun'));
        await tester.pumpAndSettle();
        expect(find.textContaining('step 1 of'), findsOneWidget);
        expect(tester.getSize(find.byKey(const ValueKey('canvas'))).height,
            greaterThan(size.height * share));
      });
    }

    test('speakable keeps words and drops emoji', () {
      expect(
          SpeechService.speakable('Draw a big circle ⭕'), 'Draw a big circle');
      expect(SpeechService.speakable('Add two eyes 👀'), 'Add two eyes');
      expect(SpeechService.speakable('⭕'), isEmpty);
    });

    test('every lesson step has speakable words', () {
      for (final g in drawingGuides) {
        for (final s in g.steps) {
          expect(SpeechService.speakable(s.text), isNotEmpty, reason: s.text);
        }
      }
    });
  });

  group('speech voice', () {
    Map<String, String> v(String name, [String locale = 'en-US']) =>
        {'name': name, 'locale': locale};

    test('prefers natural voices, skips non-English and novelty voices', () {
      final pick = SpeechService.pickVoice([
        v('Zarvox'),
        v('Amelie', 'fr-FR'),
        v('Microsoft David - English (United States)'),
        v('Google US English'),
        v('Microsoft Aria Online (Natural) - English (United States)'),
      ]);
      expect(pick?['name'], contains('Aria Online (Natural)'));
    });

    test('enhanced version of a friendly voice wins', () {
      final pick = SpeechService.pickVoice([
        v('Samantha'),
        v('Samantha (Enhanced)'),
      ]);
      expect(pick?['name'], 'Samantha (Enhanced)');
    });

    test('no English voice means no pick', () {
      expect(
          SpeechService.pickVoice([v('Amelie', 'fr-FR'), v('Fred')]), isNull);
      expect(SpeechService.pickVoice([]), isNull);
    });

    test('lively adds an exclamation mark only when needed', () {
      expect(SpeechService.lively('Draw a circle'), 'Draw a circle!');
      expect(SpeechService.lively('Great job!'), 'Great job!');
      expect(SpeechService.lively('Ready?'), 'Ready?');
    });
  });

  group('parental gate', () {
    test('has 4 unique options including the answer', () {
      for (int seed = 0; seed < 50; seed++) {
        final q = GateQuestion.random(math.Random(seed));
        expect(q.options.length, 4);
        expect(q.options.toSet().length, 4);
        expect(q.options, contains(q.answer));
        expect(q.options.every((o) => o > 0), isTrue);
      }
    });

    test('only the right answer is correct', () {
      final q = GateQuestion.random(math.Random(1));
      expect(q.isCorrect(q.answer), isTrue);
      expect(q.isCorrect(q.answer + 1), isFalse);
    });
  });

  group('web emoji font', () {
    // A character missing from the bundled font makes Flutter web fetch a
    // font from Google, so every emoji/symbol used in lib/ must be in it.
    test('covers every emoji used in the app', () {
      final covered = _cmapCodePoints(
          File('assets/fonts/NotoColorEmoji.ttf').readAsBytesSync());
      final used = <int>{
        for (final f in Directory('lib').listSync().whereType<File>())
          if (f.path.endsWith('.dart'))
            for (final r in f.readAsStringSync().runes)
              if (r >= 0x2000 && r != 0xFE0F && r != 0x200D) r,
      };
      final missing = [
        for (final r in used)
          if (!covered.contains(r))
            'U+${r.toRadixString(16).toUpperCase()} ${String.fromCharCode(r)}',
      ];
      expect(missing, isEmpty);
    });
  });
}

/// Code points in a TrueType font's format 12 cmap subtable.
Set<int> _cmapCodePoints(Uint8List font) {
  final d = ByteData.sublistView(font);
  final numTables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + 16 * i;
    if (String.fromCharCodes(font, rec, rec + 4) == 'cmap') {
      cmap = d.getUint32(rec + 8);
    }
  }
  final out = <int>{};
  final subtables = d.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final s = cmap + d.getUint32(cmap + 4 + 8 * i + 4);
    if (d.getUint16(s) != 12) continue;
    final groups = d.getUint32(s + 12);
    for (var g = 0; g < groups; g++) {
      final start = d.getUint32(s + 16 + 12 * g);
      final end = d.getUint32(s + 20 + 12 * g);
      for (var c = start; c <= end; c++) {
        out.add(c);
      }
    }
  }
  return out;
}
