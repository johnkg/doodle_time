import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'guides.dart';

/// Reference picture for a lesson step: earlier steps in gray, the new
/// part of this step in bright orange so a child sees exactly what to add.
class GuidePreviewPainter extends CustomPainter {
  GuidePreviewPainter(this.guide, this.step);

  final DrawingGuide guide;
  final int step;

  static const Color _old = Color(0xFF9E9E9E);
  static const Color _current = Color(0xFFFF6F00);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    final last = math.min(step, guide.steps.length - 1);
    for (int i = 0; i <= last; i++) {
      final isCurrent = i == last;
      final color = isCurrent ? _current : _old;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCurrent ? 2.6 : 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      final solid = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      for (final shape in guide.steps[i].shapes) {
        canvas.drawPath(shape.path, shape.fill ? solid : stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GuidePreviewPainter old) =>
      old.guide != guide || old.step != step;
}
