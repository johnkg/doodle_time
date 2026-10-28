import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'board_painter.dart';
import 'daily.dart';
import 'drawing_controller.dart';
import 'drawing_store.dart';
import 'guide_painter.dart';
import 'guides.dart';
import 'models.dart';
import 'pages.dart';
import 'parental_gate.dart';
import 'save_png_stub.dart' if (dart.library.js_interop) 'save_png_web.dart';
import 'sound_service.dart';
import 'speech_service.dart';
import 'unlock.dart';

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key, this.store, this.progressStore, this.now});

  /// Clock, injectable for tests. Null = real time.
  final DateTime Function()? now;

  /// Where to keep the drawing between launches. Null = don't save.
  final DrawingStore? store;

  /// Where finished lessons (stickers) are kept. Null = don't save.
  final ProgressStore? progressStore;

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  late final DrawingController c = DrawingController(store: widget.store);
  final SoundService sound = SoundService();
  final SpeechService speech = SpeechService();
  final GlobalKey _boardKey = GlobalKey();
  int? _pointer;
  DrawingGuide? _guide;
  int _step = 0;

  /// True while the child draws on real paper: the lesson fills the screen
  /// and there is no canvas.
  bool _paper = false;
  Set<String> _done = {};

  DateTime get _today => widget.now?.call() ?? DateTime.now();

  /// The daily card shows on a fresh, empty canvas.
  bool get _showDaily => _guide == null && !c.canUndo && c.page == null;

  void _startGuide(DrawingGuide g, {bool paper = false}) {
    c.setPage(null); // fresh blank canvas
    setState(() {
      _guide = g;
      _step = 0;
      _paper = paper;
    });
    _speakStep();
  }

  /// Asks where the child wants to draw, then starts the lesson.
  Future<void> _chooseMode(DrawingGuide g) async {
    final paper = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${g.emoji} ${g.name}',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 72)),
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('📄 On paper', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 72)),
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('✏️ In the app', style: TextStyle(fontSize: 24)),
              ),
            ),
          ],
        ),
      ),
    );
    if (paper == null || !mounted) return;
    _startGuide(g, paper: paper);
  }

  @override
  void initState() {
    super.initState();
    c.restore();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final store = widget.progressStore;
    if (store == null) return;
    try {
      final done = await store.loadDone();
      if (mounted) setState(() => _done = done);
    } catch (_) {
      // Unreadable progress: start with no stickers.
    }
  }

  @override
  void dispose() {
    c.saveNow();
    c.dispose();
    sound.dispose();
    speech.dispose();
    super.dispose();
  }

  /// Reads the current lesson step aloud (follows the Sounds switch).
  void _speakStep() {
    final g = _guide;
    if (g == null || !sound.enabled) return;
    final text = g.steps[_step].text;
    speech
        .speak(_paper && _step == 0 ? 'Get a pencil and a paper. $text' : text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3D6),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              final screen = box.biggest;
              // Wide landscape: lesson goes in a column beside the canvas.
              final wide =
                  screen.width >= 900 && screen.width >= screen.height * 1.2;
              final sideLesson = _guide != null && wide;
              if (_guide != null && _paper) return _paperLesson(screen, wide);
              return Column(
                children: [
                  _topBar(),
                  if (_guide != null && !wide)
                    _guidePanel(screen)
                  else if (_guide == null && _showDaily)
                    _dailyBanner(),
                  Expanded(
                    child: sideLesson
                        ? Row(
                            children: [
                              SizedBox(
                                width:
                                    (screen.width * 0.27).clamp(280.0, 360.0),
                                child: _guideSidePanel(),
                              ),
                              Expanded(child: _canvas()),
                            ],
                          )
                        : _canvas(),
                  ),
                  _bottomPanel(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- top bar ------------------------------------------------------------

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.photo_library,
              label: 'Pictures',
              onTap: _pickPage,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.undo,
              label: 'Undo',
              onTap: c.canUndo ? c.undo : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.redo,
              label: 'Redo',
              onTap: c.canRedo ? c.redo : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.delete_outline,
              label: 'Clear',
              onTap: c.canUndo ? _confirmClear : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.lock_outline,
              label: 'Grown-ups',
              onTap: _grownUps,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _grownUps() async {
    final ok = await showParentalGate(context);
    if (!ok || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Save picture (web)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _savePicture();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lock_open),
                title: const Text('Unlock all lessons'),
                value: _done.contains(unlockAllKey),
                onChanged: (v) {
                  final next = {..._done};
                  v ? next.add(unlockAllKey) : next.remove(unlockAllKey);
                  setState(() => _done = next);
                  setSheetState(() {});
                  widget.progressStore?.saveDone(next).catchError((_) {});
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: const Text('Sounds and voice'),
                value: sound.enabled,
                onChanged: (v) => setSheetState(() => sound.enabled = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePicture() async {
    final messenger = ScaffoldMessenger.of(context);
    final boundary =
        _boardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final saved = await savePng(
      data.buffer.asUint8List(),
      'doodle-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Saved! Look in your Downloads.'
              : 'Saving pictures works on web for now.',
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start over? 🧹', style: TextStyle(fontSize: 28)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 56)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(fontSize: 22)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 56)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
    if (yes == true) c.clear();
  }

  /// A locked lesson was tapped: say which lesson opens it.
  void _explainLocked(DrawingGuide before) {
    final line = 'Draw the ${before.name} first to open this one!';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('🔒 $line')));
    if (sound.enabled) speech.speak(line);
  }

  void _pickPage() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✏️ Learn to draw · ⭐ ${drawingGuides.where((g) => _done.contains(g.name)).length}/${drawingGuides.length}',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              for (final track in lessonTracks) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${track.emoji} ${track.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // One chain of lessons: finish a lesson to open the next.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < track.guides.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 18,
                            height: 4,
                            margin: const EdgeInsets.only(top: 42),
                            color: Colors.black12,
                          ),
                        _LessonNode(
                          guide: track.guides[i],
                          locked: !isUnlocked(track, i, _done),
                          done: _done.contains(track.guides[i].name),
                          onTap: () {
                            if (!isUnlocked(track, i, _done)) {
                              _explainLocked(lessonBefore(track, i)!);
                              return;
                            }
                            Navigator.pop(ctx);
                            _chooseMode(track.guides[i]);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                '🎨 Color a picture',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _PageChoice(
                    emoji: '📄',
                    label: 'Blank',
                    onTap: () {
                      c.setPage(null);
                      setState(() => _guide = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final p in coloringPages)
                    _PageChoice(
                      emoji: p.emoji,
                      label: p.name,
                      onTap: () {
                        c.setPage(p);
                        setState(() => _guide = null);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- daily drawing --------------------------------------------------------

  Widget _dailyBanner() {
    final today = _today;
    final g = dailyGuide(today);
    final doneToday = _done.contains(dayKey(today));
    final streak = dailyStreak(_done, today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.deepPurple, width: 2),
        ),
        child: Row(
          children: [
            Text(g.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doneToday ? '⭐ Done today!' : "🌟 Today's drawing",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    // "an Octopus", "a Dog"
                    'Draw ${'AEIOU'.contains(g.name[0]) ? 'an' : 'a'} ${g.name}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (streak >= 2)
                    Text(
                      '🔥 $streak days in a row',
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 52)),
              onPressed: () => _chooseMode(g),
              child: Text(
                doneToday ? 'Again' : 'Start ▶',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- step-by-step guide ---------------------------------------------------

  /// Lesson picture; tap it to see it full size.
  Widget _guidePicture(DrawingGuide g) => GestureDetector(
        onTap: () => _showBigPicture(g),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12, width: 2),
          ),
          child: CustomPaint(painter: GuidePreviewPainter(g, _step)),
        ),
      );

  /// Step label with the "hear it" and "close" buttons.
  Widget _guideHeader(DrawingGuide g) {
    const tight = BoxConstraints.tightFor(width: 40, height: 40);
    return Row(
      children: [
        Expanded(
          child: Text(
            '${g.emoji} ${g.name} · step ${_step + 1} of ${g.steps.length}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Hear the step',
          constraints: tight,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.volume_up),
          onPressed: () => speech.speak(g.steps[_step].text),
        ),
        IconButton(
          tooltip: _paper ? 'Draw in the app' : 'Draw on paper',
          constraints: tight,
          padding: EdgeInsets.zero,
          icon: Icon(_paper ? Icons.brush : Icons.description_outlined),
          onPressed: () {
            setState(() => _paper = !_paper);
            if (_paper) _speakStep();
          },
        ),
        IconButton(
          tooltip: 'Close lesson',
          constraints: tight,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _guide = null),
        ),
      ],
    );
  }

  Widget _guideText(DrawingGuide g, double fontSize) => Text(
        g.steps[_step].text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      );

  /// Back and Next (or Done) buttons.
  Widget _guideButtons(DrawingGuide g) {
    final isLast = _step == g.steps.length - 1;
    return Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () {
                setState(() => _step--);
                _speakStep();
              },
              child: const Text('⬅️ Back', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _nextStep,
            child: Text(isLast ? 'Done 🎉' : 'Next ➡️',
                style: const TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  BoxDecoration get _guideBox => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12, width: 2),
      );

  /// Lesson panel above the canvas (phones and portrait). The picture is sized
  /// by height as well as width so the canvas keeps most of the screen.
  Widget _guidePanel(Size screen) {
    final g = _guide!;
    final side =
        math.min(screen.width * 0.26, screen.height * 0.14).clamp(80.0, 150.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: _guideBox,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: side, height: side, child: _guidePicture(g)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _guideHeader(g),
                      _guideText(g, 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _guideButtons(g),
          ],
        ),
      ),
    );
  }

  /// Lesson panel as a column left of the canvas (wide landscape screens), so
  /// the canvas keeps its full height and the picture can be big.
  Widget _guideSidePanel() {
    final g = _guide!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: _guideBox,
        child: SingleChildScrollView(
          child: Column(
            children: [
              AspectRatio(aspectRatio: 1, child: _guidePicture(g)),
              const SizedBox(height: 10),
              _guideHeader(g),
              Align(
                alignment: Alignment.centerLeft,
                child: _guideText(g, 22),
              ),
              const SizedBox(height: 8),
              _guideButtons(g),
            ],
          ),
        ),
      ),
    );
  }

  /// Whole-screen lesson for drawing on real paper: big picture, one step at a
  /// time, no canvas.
  Widget _paperLesson(Size screen, bool wide) {
    final g = _guide!;
    // A square as big as fits; without the AspectRatio the picture has no
    // size of its own and collapses.
    final picture = Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: _guideBox,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _guidePicture(g),
            ),
          ),
        ),
      ),
    );
    final info = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: _guideBox,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _guideHeader(g),
              if (_step == 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('📄 Get a pencil and a paper',
                      style: TextStyle(fontSize: 18, color: Colors.deepPurple)),
                ),
              _guideText(g, 24),
              const SizedBox(height: 8),
              _guideButtons(g),
            ],
          ),
        ),
      ),
    );
    return wide
        ? Row(
            children: [
              Expanded(child: picture),
              SizedBox(
                width: (screen.width * 0.34).clamp(300.0, 420.0),
                child: Align(alignment: Alignment.center, child: info),
              ),
            ],
          )
        : Column(
            children: [
              Expanded(child: picture),
              info,
            ],
          );
  }

  void _showBigPicture(DrawingGuide g) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFFDF7),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CustomPaint(painter: GuidePreviewPainter(g, _step)),
            ),
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    final g = _guide;
    if (g == null) return;
    if (_step < g.steps.length - 1) {
      setState(() => _step++);
      _speakStep();
      return;
    }
    _finishLesson(g);
  }

  Future<void> _finishLesson(DrawingGuide g) async {
    final isNew = !_done.contains(g.name);
    final next = lessonAfter(g);
    final opensNext = next != null && isNew && !_done.contains(unlockAllKey);
    final today = _today;
    final isDaily = g.name == dailyGuide(today).name;
    setState(() {
      _guide = null;
      _done = {..._done, g.name, if (isDaily) dayKey(today)};
    });
    sound.play('fill.wav');
    if (sound.enabled) {
      speech.speak('Great job! You drew a ${g.name}!'
          '${opensNext ? ' You opened the ${next.name}!' : ''}');
    }
    try {
      await widget.progressStore?.saveDone(_done);
    } catch (_) {
      // Progress is best effort.
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, t, child) =>
                  Transform.scale(scale: t, child: child),
              child: Text(g.emoji, style: const TextStyle(fontSize: 96)),
            ),
            const SizedBox(height: 8),
            Text(
              'You drew a ${g.name}! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isNew ? 'New sticker ⭐' : 'Great job! ⭐',
              style: const TextStyle(fontSize: 20),
            ),
            if (opensNext)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '🔓 ${next.name} is open now',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            if (isDaily) ...[
              const SizedBox(height: 8),
              const Text(
                "Today's drawing done! 🌟",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(140, 56)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Yay! 🎉', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }

  // ---- canvas -------------------------------------------------------------

  Widget _canvas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DecoratedBox(
        key: const ValueKey('canvas'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black12, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  if (_pointer != null) return;
                  _pointer = e.pointer;
                  final before = c.ops.length;
                  c.pointerDown(e.localPosition, size);
                  if (c.ops.length > before) {
                    // Stamps and fills add an op immediately.
                    sound.play(c.tool == Tool.fill ? 'fill.wav' : 'pop.wav');
                  }
                },
                onPointerMove: (e) {
                  if (e.pointer != _pointer) return;
                  c.pointerMove(e.localPosition, size);
                },
                onPointerUp: (e) {
                  if (e.pointer != _pointer) return;
                  _pointer = null;
                  c.pointerUp();
                },
                onPointerCancel: (e) {
                  if (e.pointer != _pointer) return;
                  _pointer = null;
                  c.pointerUp();
                },
                child: RepaintBoundary(
                  key: _boardKey,
                  child: CustomPaint(
                    size: size,
                    painter: BoardPainter(c),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- bottom panel -------------------------------------------------------

  Widget _bottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ToolButton(
                  emoji: '🖌️',
                  label: 'Draw',
                  selected: c.tool == Tool.brush,
                  onTap: () => c.setTool(Tool.brush),
                ),
                _ToolButton(
                  emoji: '🧽',
                  label: 'Erase',
                  selected: c.tool == Tool.eraser,
                  onTap: () => c.setTool(Tool.eraser),
                ),
                _ToolButton(
                  emoji: c.stamp,
                  label: 'Stamp',
                  selected: c.tool == Tool.stamp,
                  onTap: () => c.setTool(Tool.stamp),
                ),
                if (c.page != null)
                  _ToolButton(
                    emoji: '🪣',
                    label: 'Fill',
                    selected: c.tool == Tool.fill,
                    onTap: () => c.setTool(Tool.fill),
                  ),
                const SizedBox(width: 12),
                for (final s in kBrushSizes)
                  _SizeDot(
                    size: s,
                    selected: c.brushSize == s,
                    onTap: () => c.setBrushSize(s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: c.tool == Tool.stamp ? _stampRow() : _colorRow(),
          ),
        ],
      ),
    );
  }

  Widget _colorRow() {
    return Row(
      children: [
        _RainbowDot(selected: c.rainbow, onTap: c.setRainbow),
        for (final col in kPalette)
          _ColorDot(
            color: col,
            selected: !c.rainbow && c.color == col,
            onTap: () => c.setColor(col),
          ),
      ],
    );
  }

  Widget _stampRow() {
    return Row(
      children: [
        for (final s in kStamps)
          _StampChoice(
            emoji: s,
            selected: c.stamp == s,
            onTap: () => c.setStamp(s),
          ),
      ],
    );
  }
}

// ---- small widgets ----------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Colors.black12, width: 2),
    );
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 28),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: selected ? Colors.deepPurple : Colors.black12,
        width: selected ? 4 : 2,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? const Color(0xFFEDE7F6) : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeDot extends StatelessWidget {
  const _SizeDot({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.transparent,
            width: 4,
          ),
        ),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF424242),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 5 : 2,
          ),
        ),
      ),
    );
  }
}

class _RainbowDot extends StatelessWidget {
  const _RainbowDot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(colors: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ]),
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 5 : 2,
          ),
        ),
      ),
    );
  }
}

class _StampChoice extends StatelessWidget {
  const _StampChoice({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? const Color(0xFFEDE7F6) : Colors.white,
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.black12,
            width: selected ? 4 : 2,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 30)),
      ),
    );
  }
}

/// One lesson on a track: a round picture of the finished drawing. Locked
/// lessons are faded with a lock; finished ones get a star.
class _LessonNode extends StatelessWidget {
  const _LessonNode({
    required this.guide,
    required this.locked,
    required this.done,
    required this.onTap,
  });

  final DrawingGuide guide;
  final bool locked;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: locked ? '${guide.name}, locked' : guide.name,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 96,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? Colors.amber : Colors.black26,
                        width: 4,
                      ),
                    ),
                    child: Opacity(
                      opacity: locked ? 0.15 : 1,
                      child: CustomPaint(
                        painter:
                            GuidePreviewPainter(guide, guide.steps.length - 1),
                      ),
                    ),
                  ),
                  if (locked) const Text('🔒', style: TextStyle(fontSize: 32)),
                  if (done)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text('⭐', style: TextStyle(fontSize: 24)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                guide.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: locked ? Colors.black38 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageChoice extends StatelessWidget {
  const _PageChoice({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Colors.black12, width: 2),
    );
    return Material(
      color: const Color(0xFFFFF3D6),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            children: [
              // Scale down instead of overflowing (long names, large system font).
              Padding(
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 44)),
                        Text(
                          label,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
