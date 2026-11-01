import 'package:flutter/material.dart';

import '../board_painter.dart';
import '../drawing_controller.dart';
import 'style.dart';

/// The drawing area. Follows one finger at a time (a second touch is
/// ignored) and tells [onOpAdded] when a tap already made a stamp or fill.
class BoardCanvas extends StatefulWidget {
  const BoardCanvas({
    super.key,
    required this.controller,
    required this.repaintKey,
    required this.onOpAdded,
  });

  final DrawingController controller;

  /// Lets the screen turn the board into a PNG.
  final GlobalKey repaintKey;

  /// Called after a pointer-down that added an operation (stamp or fill).
  final VoidCallback onOpAdded;

  @override
  State<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<BoardCanvas> {
  static const double _borderWidth = 3;

  int? _activePointer;

  DrawingController get _c => widget.controller;

  void _onDown(PointerDownEvent e, Size size) {
    if (_activePointer != null) return;
    _activePointer = e.pointer;
    final before = _c.ops.length;
    _c.pointerDown(e.localPosition, size);
    if (_c.ops.length > before) widget.onOpAdded();
  }

  void _onMove(PointerMoveEvent e, Size size) {
    if (e.pointer == _activePointer) _c.pointerMove(e.localPosition, size);
  }

  void _onEnd(PointerEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    _c.pointerUp();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: kScreenPadding, vertical: 6),
      child: DecoratedBox(
        key: const ValueKey('canvas'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(color: Colors.black12, width: _borderWidth),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadius - _borderWidth),
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _onDown(e, size),
                onPointerMove: (e) => _onMove(e, size),
                onPointerUp: _onEnd,
                onPointerCancel: _onEnd,
                child: RepaintBoundary(
                  key: widget.repaintKey,
                  child: CustomPaint(size: size, painter: BoardPainter(_c)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
