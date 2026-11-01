import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'daily.dart';
import 'drawing_controller.dart';
import 'drawing_store.dart';
import 'guides.dart';
import 'models.dart';
import 'parental_gate.dart';
import 'save_png_stub.dart' if (dart.library.js_interop) 'save_png_web.dart';
import 'sound_service.dart';
import 'speech_service.dart';
import 'ui/board_canvas.dart';
import 'ui/daily_banner.dart';
import 'ui/dialogs.dart';
import 'ui/grown_ups_sheet.dart';
import 'ui/lesson_view.dart';
import 'ui/picture_picker.dart';
import 'ui/style.dart';
import 'ui/tool_panel.dart';
import 'ui/tool_widgets.dart';
import 'unlock.dart';

/// Wide landscape screens put the lesson in a column beside the canvas.
const double _wideMinWidth = 900;
const double _wideMinAspect = 1.2;

const String _stampSound = 'pop.wav';
const String _fillSound = 'fill.wav';
const String _paperIntro = 'Get a pencil and a paper.';

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
  late final DrawingController _drawing =
      DrawingController(store: widget.store);
  final SoundService _sound = SoundService();
  final SpeechService _speech = SpeechService();
  final GlobalKey _boardKey = GlobalKey();

  /// The lesson being followed and its current step; null when just drawing.
  DrawingGuide? _lesson;
  int _step = 0;

  /// True while the child draws on real paper: the lesson fills the screen
  /// and there is no canvas.
  bool _onPaper = false;

  /// Finished lessons, finished days and the unlock-all switch.
  Set<String> _progress = {};

  DateTime get _today => widget.now?.call() ?? DateTime.now();

  /// The daily card shows on a fresh, empty canvas.
  bool get _showDaily =>
      _lesson == null && !_drawing.canUndo && _drawing.page == null;

  @override
  void initState() {
    super.initState();
    _drawing.restore();
    _loadProgress();
  }

  @override
  void dispose() {
    _drawing.saveNow();
    _drawing.dispose();
    _sound.dispose();
    _speech.dispose();
    super.dispose();
  }

  // ---- progress ---------------------------------------------------------------

  Future<void> _loadProgress() async {
    try {
      final loaded = await widget.progressStore?.loadDone();
      if (loaded != null && mounted) setState(() => _progress = loaded);
    } catch (_) {
      // Unreadable progress: start with no stickers.
    }
  }

  Future<void> _saveProgress() async {
    try {
      await widget.progressStore?.saveDone(_progress);
    } catch (_) {
      // Progress is best effort.
    }
  }

  void _setUnlockAll(bool unlocked) {
    setState(() {
      _progress = {..._progress};
      unlocked ? _progress.add(unlockAllKey) : _progress.remove(unlockAllKey);
    });
    _saveProgress();
  }

  // ---- lessons ----------------------------------------------------------------

  /// Asks where the child wants to draw, then starts the lesson.
  Future<void> _chooseLessonPlace(DrawingGuide lesson) async {
    final onPaper = await askDrawingPlace(context, lesson);
    if (onPaper == null || !mounted) return;
    _startLesson(lesson, onPaper: onPaper);
  }

  void _startLesson(DrawingGuide lesson, {required bool onPaper}) {
    _drawing.setPage(null); // fresh blank canvas
    setState(() {
      _lesson = lesson;
      _step = 0;
      _onPaper = onPaper;
    });
    _speakStep();
  }

  void _closeLesson() => setState(() => _lesson = null);

  void _togglePaper() {
    setState(() => _onPaper = !_onPaper);
    if (_onPaper) _speakStep();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _speakStep();
  }

  /// Reads the current lesson step aloud (follows the Sounds switch).
  void _speakStep() {
    final lesson = _lesson;
    if (lesson == null || !_sound.enabled) return;
    final text = lesson.steps[_step].text;
    _speech.speak(_onPaper && _step == 0 ? '$_paperIntro $text' : text);
  }

  void _nextStep() {
    final lesson = _lesson!;
    if (_step < lesson.steps.length - 1) {
      _goToStep(_step + 1);
    } else {
      _finishLesson(lesson);
    }
  }

  Future<void> _finishLesson(DrawingGuide lesson) async {
    final isNewSticker = !_progress.contains(lesson.name);
    final next = lessonAfter(lesson);
    final opened =
        isNewSticker && !_progress.contains(unlockAllKey) ? next : null;
    final today = _today;
    final isDaily = lesson.name == dailyGuide(today).name;
    setState(() {
      _lesson = null;
      _progress = {..._progress, lesson.name, if (isDaily) dayKey(today)};
    });
    _sound.play(_fillSound);
    if (_sound.enabled) {
      _speech.speak('Great job! You drew a ${lesson.name}!'
          '${opened == null ? '' : ' You opened the ${opened.name}!'}');
    }
    await _saveProgress();
    if (!mounted) return;
    await showLessonDone(
      context,
      guide: lesson,
      isNewSticker: isNewSticker,
      openedLesson: opened,
      isDailyLesson: isDaily,
    );
  }

  /// A locked lesson was tapped: say which lesson opens it.
  void _explainLocked(DrawingGuide lessonBefore) {
    final line = 'Draw the ${lessonBefore.name} first to open this one!';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('🔒 $line')));
    if (_sound.enabled) _speech.speak(line);
  }

  LessonControls _lessonControls(DrawingGuide lesson) => LessonControls(
        guide: lesson,
        step: _step,
        paper: _onPaper,
        onHear: () => _speech.speak(lesson.steps[_step].text),
        onTogglePaper: _togglePaper,
        onClose: _closeLesson,
        onBack: () => _goToStep(_step - 1),
        onNext: _nextStep,
        onZoomPicture: () => showBigPicture(context, lesson, _step),
      );

  // ---- actions ----------------------------------------------------------------

  void _openPicker() {
    showPicturePicker(
      context,
      done: _progress,
      onLockedLesson: _explainLocked,
      onLesson: _chooseLessonPlace,
      onPage: (page) {
        _drawing.setPage(page);
        _closeLesson();
      },
    );
  }

  Future<void> _openGrownUps() async {
    final allowed = await showParentalGate(context);
    if (!allowed || !mounted) return;
    showGrownUpsSheet(
      context,
      unlockAll: _progress.contains(unlockAllKey),
      soundsOn: _sound.enabled,
      onSavePicture: _savePicture,
      onUnlockAllChanged: _setUnlockAll,
      onSoundsChanged: (on) => _sound.enabled = on,
    );
  }

  Future<void> _confirmClear() async {
    if (await askClearDrawing(context)) _drawing.clear();
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
        content: Text(saved
            ? 'Saved! Look in your Downloads.'
            : 'Saving pictures works on web for now.'),
      ),
    );
  }

  // ---- layout -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBackground,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _drawing,
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              final screen = box.biggest;
              final wide = screen.width >= _wideMinWidth &&
                  screen.width >= screen.height * _wideMinAspect;
              final lesson = _lesson;
              if (lesson != null && _onPaper) {
                return PaperLesson(
                  controls: _lessonControls(lesson),
                  screen: screen,
                  wide: wide,
                );
              }
              return Column(
                children: [
                  _topBar(),
                  if (lesson != null && !wide)
                    LessonStrip(
                        controls: _lessonControls(lesson), screen: screen)
                  else if (_showDaily)
                    _dailyBanner(),
                  Expanded(child: _canvasArea(lesson, screen, wide)),
                  ToolPanel(controller: _drawing),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _canvasArea(DrawingGuide? lesson, Size screen, bool wide) {
    final canvas = BoardCanvas(
      controller: _drawing,
      repaintKey: _boardKey,
      onOpAdded: () =>
          _sound.play(_drawing.tool == Tool.fill ? _fillSound : _stampSound),
    );
    if (lesson == null || !wide) return canvas;
    return Row(
      children: [
        SizedBox(
          width: LessonSideColumn.widthFor(screen.width),
          child: LessonSideColumn(controls: _lessonControls(lesson)),
        ),
        Expanded(child: canvas),
      ],
    );
  }

  Widget _topBar() {
    final c = _drawing;
    final buttons = [
      ActionButton(
          icon: Icons.photo_library, label: 'Pictures', onTap: _openPicker),
      ActionButton(
          icon: Icons.undo, label: 'Undo', onTap: c.canUndo ? c.undo : null),
      ActionButton(
          icon: Icons.redo, label: 'Redo', onTap: c.canRedo ? c.redo : null),
      ActionButton(
        icon: Icons.delete_outline,
        label: 'Clear',
        onTap: c.canUndo ? _confirmClear : null,
      ),
      ActionButton(
          icon: Icons.lock_outline, label: 'Grown-ups', onTap: _openGrownUps),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 8, kScreenPadding, 2),
      child: Row(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }

  Widget _dailyBanner() {
    final today = _today;
    final lesson = dailyGuide(today);
    return DailyBanner(
      guide: lesson,
      doneToday: _progress.contains(dayKey(today)),
      streak: dailyStreak(_progress, today),
      onStart: () => _chooseLessonPlace(lesson),
    );
  }
}
