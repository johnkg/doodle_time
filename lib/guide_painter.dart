import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'guides.dart';
import 'shapes.dart';

/// Reference picture for a lesson step, drawn like a pencil sketch: light
/// helper lines, dark outlines, thin strokes for fur and shadow. The new part
/// of this step is bright orange so a child sees exactly what to add. The
/// last step shows the finished sketch: helper lines rubbed out, all pencil.
class GuidePreviewPainter extends CustomPainter {
  GuidePreviewPainter(this.guide, this.step);

  final DrawingGuide guide;
  final int step;

  // Line widths in design units (the picture is 100 wide).
  static const double _helperWidth = 0.8;
  static const double _helperWidthCurrent = 1.3;
  static const double _shadeWidth = 0.55;
  static const double _shadeWidthCurrent = 0.7;
  static const double _lineWidth = 1.2;
  static const double _lineWidthCurrent = 2.2;
  static const double _helperAlphaCurrent = 0.75;
  static const double _shadeAlpha = 0.75;

  static const Color _pencil = Color(0xFF55595E);
  static const Color _helper = Color(0xFFAFC3D3);
  static const Color _current = Color(0xFFFF6F00);

  // Back to front: helper lines under everything, shines on top of dots.
  static const _layers = [
    GuideKind.guide,
    GuideKind.shade,
    GuideKind.line,
    GuideKind.dot,
    GuideKind.shine,
  ];

  Paint _paint(GuideKind kind, bool isCurrent) {
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case GuideKind.guide:
        return p
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? _helperWidthCurrent : _helperWidth
          ..color = isCurrent
              ? _current.withValues(alpha: _helperAlphaCurrent)
              : _helper;
      case GuideKind.shade:
        return p
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? _shadeWidthCurrent : _shadeWidth
          ..color =
              (isCurrent ? _current : _pencil).withValues(alpha: _shadeAlpha);
      case GuideKind.line:
        return p
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? _lineWidthCurrent : _lineWidth
          ..color = isCurrent ? _current : _pencil;
      case GuideKind.dot:
        return p
          ..style = PaintingStyle.fill
          ..color = isCurrent ? _current : _pencil;
      case GuideKind.shine:
        return p
          ..style = PaintingStyle.fill
          ..color = Colors.white;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(designMatrix(size).storage);
    final last = math.min(step, guide.steps.length - 1);
    final finished = last == guide.steps.length - 1;
    for (final kind in _layers) {
      if (kind == GuideKind.guide && finished) continue;
      for (int i = 0; i <= last; i++) {
        // The finished picture is all pencil, like the last panel of a
        // drawing book page.
        final paint = _paint(kind, i == last && !finished);
        for (final shape in guide.steps[i].shapes) {
          if (shape.kind == kind) canvas.drawPath(shape.path, paint);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GuidePreviewPainter old) =>
      old.guide != guide || old.step != step;
}
