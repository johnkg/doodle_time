import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'drawing_store.dart';
import 'models.dart';
import 'pages.dart';

const List<Color> kPalette = [
  Color(0xFFE53935), // red
  Color(0xFFFB8C00), // orange
  Color(0xFFFDD835), // yellow
  Color(0xFF43A047), // green
  Color(0xFF00ACC1), // teal
  Color(0xFF1E88E5), // blue
  Color(0xFF8E24AA), // purple
  Color(0xFFF06292), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF212121), // black
];

const List<String> kStamps = [
  '⭐', '❤️', '🌈', '🐶', '🐱', '🦋', '🌸', '🚀', '🍎', '☀️',
];

const List<double> kBrushSizes = [8, 16, 30];

class DrawingController extends ChangeNotifier {
  DrawingController({this.store});

  /// Optional. When null nothing is saved (used in tests).
  final DrawingStore? store;

  Tool tool = Tool.brush;
  Color color = kPalette.first;
  bool rainbow = false;
  double brushSize = kBrushSizes[1];
  String stamp = kStamps.first;
  ColoringPage? page;

  final List<DrawOp> ops = [];
  final List<DrawOp> _redo = [];
  StrokeOp? live;

  Offset _lastPx = Offset.zero;
  final math.Random _rng = math.Random();
  Timer? _saveTimer;

  bool get canUndo => ops.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  double get stampSize => 40 + brushSize * 3;

  // ---- persistence --------------------------------------------------------

  /// Bump when coloring page regions change: fills point at regions by index,
  /// so fills from an older version are dropped on load (strokes are kept).
  static const int saveVersion = 2;

  String encode() => jsonEncode({
        'v': saveVersion,
        'page': page?.name,
        'ops': [for (final op in ops) op.toJson()],
      });

  /// Loads the saved drawing. Bad data is ignored, never thrown.
  Future<void> restore() async {
    final s = store;
    if (s == null) return;
    try {
      final raw = await s.load();
      if (raw == null) return;
      decode(raw);
    } catch (_) {
      // Corrupt save: start with a blank page.
    }
  }

  void decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final pageName = map['page'] as String?;
    ColoringPage? p;
    for (final candidate in coloringPages) {
      if (candidate.name == pageName) p = candidate;
    }
    final oldRegions = (map['v'] as int? ?? 1) < saveVersion;
    final loaded = <DrawOp>[];
    for (final item in (map['ops'] as List? ?? const [])) {
      final op = DrawOp.fromJson(item as Map<String, dynamic>);
      if (op == null || (oldRegions && op is FillOp)) continue;
      loaded.add(op);
    }
    page = p;
    ops
      ..clear()
      ..addAll(loaded);
    _redo.clear();
    live = null;
    if (p != null) tool = Tool.fill;
    notifyListeners();
  }

  void _scheduleSave() {
    if (store == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), saveNow);
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    final s = store;
    if (s == null) return;
    try {
      await s.save(encode());
    } catch (_) {
      // Saving is best effort; drawing must keep working.
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---- settings -----------------------------------------------------------

  void setTool(Tool t) {
    tool = t;
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    rainbow = false;
    if (tool == Tool.eraser) tool = Tool.brush;
    notifyListeners();
  }

  void setRainbow() {
    rainbow = true;
    if (tool == Tool.eraser) tool = Tool.brush;
    notifyListeners();
  }

  void setBrushSize(double s) {
    brushSize = s;
    notifyListeners();
  }

  void setStamp(String s) {
    stamp = s;
    tool = Tool.stamp;
    notifyListeners();
  }

  /// Switching picture starts a fresh drawing.
  void setPage(ColoringPage? p) {
    page = p;
    ops.clear();
    _redo.clear();
    live = null;
    tool = p == null ? Tool.brush : Tool.fill;
    notifyListeners();
    _scheduleSave();
  }

  // ---- history ------------------------------------------------------------

  void undo() {
    if (ops.isEmpty) return;
    _redo.add(ops.removeLast());
    notifyListeners();
    _scheduleSave();
  }

  void redo() {
    if (_redo.isEmpty) return;
    ops.add(_redo.removeLast());
    notifyListeners();
    _scheduleSave();
  }

  void clear() {
    ops.clear();
    _redo.clear();
    live = null;
    notifyListeners();
    _scheduleSave();
  }

  void _push(DrawOp op) {
    ops.add(op);
    _redo.clear();
    notifyListeners();
    _scheduleSave();
  }

  // ---- pointer input ------------------------------------------------------

  Offset _norm(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0).toDouble(),
      (local.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  void pointerDown(Offset local, Size size) {
    final n = _norm(local, size);
    switch (tool) {
      case Tool.brush:
      case Tool.eraser:
        final erasing = tool == Tool.eraser;
        _lastPx = local;
        live = StrokeOp(
          color: color,
          width: erasing ? brushSize * 1.6 : brushSize,
          rainbow: rainbow,
          erase: erasing,
          first: n,
        );
        notifyListeners();
      case Tool.stamp:
        _push(StampOp(emoji: stamp, center: n, size: stampSize));
      case Tool.fill:
        _fillAt(local, size);
    }
  }

  void pointerMove(Offset local, Size size) {
    final s = live;
    if (s == null) return;
    if ((local - _lastPx).distance < 2) return;
    _lastPx = local;
    s.points.add(_norm(local, size));
    notifyListeners();
  }

  void pointerUp() {
    final s = live;
    if (s == null) return;
    live = null;
    _push(s);
  }

  void _fillAt(Offset local, Size size) {
    final p = page;
    if (p == null) return;
    final m = pageMatrix(size);
    for (int i = p.regions.length - 1; i >= 0; i--) {
      if (p.regions[i].path.transform(m.storage).contains(local)) {
        final fillColor = rainbow
            ? HSVColor.fromAHSV(1, _rng.nextDouble() * 360, 0.8, 1).toColor()
            : color;
        _push(FillOp(region: i, color: fillColor));
        return;
      }
    }
  }
}
