import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'guides.dart';

/// Reference picture for a lesson step, drawn like a pencil sketch: light
/// helper lines, dark outlines, thin strokes for fur and shadow. The new part
/// of this step is bright orange so a child sees exactly what to add. The
/// last step shows the finished sketch: helper lines rubbed out, all pencil.
class GuidePreviewPainter extends CustomPainter {
  GuidePreviewPainter(this.guide, this.step);

  final DrawingGuide guide;
  final int step;

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
          ..strokeWidth = isCurrent ? 1.3 : 0.8
          ..color = isCurrent ? _current.withValues(alpha: 0.75) : _helper;
      case GuideKind.shade:
        return p
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? 0.7 : 0.55
          ..color = (isCurrent ? _current : _pencil).withValues(alpha: 0.75);
      case GuideKind.line:
        return p
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? 2.2 : 1.2
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
    final s = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
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
