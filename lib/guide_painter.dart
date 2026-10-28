import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'guides.dart';

/// Reference picture for a lesson step, drawn like a pencil sketch: light
/// helper lines, hand-drawn outlines, soft graphite tone with hatching on
/// top. The new part of this step is bright orange so a child sees exactly
/// what to add. The last step shows the finished sketch: helper lines rubbed
/// out, all pencil.
class GuidePreviewPainter extends CustomPainter {
  GuidePreviewPainter(this.guide, this.step);

  final DrawingGuide guide;
  final int step;

  static const Color _pencil = Color(0xFF4A4D52);
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

  /// Two slightly different wobbly copies of an outline. Drawn on top of each
  /// other they look like a line gone over twice with a pencil. Built once per
  /// shape (the painter repaints a lot).
  static final Expando<List<Path>> _sketchy = Expando<List<Path>>();

  static List<Path> _sketchyPaths(GuideShape shape) =>
      _sketchy[shape] ??= [_wobble(shape.path, 1), _wobble(shape.path, 2)];

  static Path _wobble(Path path, int pass) {
    final out = Path();
    final phase = pass * 2.3;
    for (final m in path.computeMetrics()) {
      final len = m.length;
      if (len < 0.5) continue;
      // Tiny shapes (eye rings, bolts) should not be shaken apart.
      final amp = (pass == 1 ? 0.2 : 0.28) * math.min(1.0, len / 25);
      final n = math.max(2, (len / 1.3).ceil());
      for (int i = 0; i <= n; i++) {
        final d = len * i / n;
        final t = m.getTangentForOffset(d)!;
        final normal = Offset(-t.vector.dy, t.vector.dx);
        final w = amp *
            (math.sin(d * 0.33 + phase) +
                0.5 * math.sin(d * 0.87 + phase * 1.7)) /
            1.5;
        final p = t.position + normal * w;
        i == 0 ? out.moveTo(p.dx, p.dy) : out.lineTo(p.dx, p.dy);
      }
      if (m.isClosed) out.close();
    }
    return out;
  }

  Paint _stroke(double width, Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  void _drawLine(Canvas canvas, GuideShape shape, bool isCurrent) {
    final width = isCurrent ? 2.2 : 1.2;
    final color = isCurrent ? _current : _pencil;
    final paths = _sketchyPaths(shape);
    canvas.drawPath(
        paths[0], _stroke(width * 0.9, color.withValues(alpha: 0.9)));
    canvas.drawPath(
        paths[1], _stroke(width * 0.5, color.withValues(alpha: 0.65)));
  }

  void _drawShade(Canvas canvas, GuideShape shape, bool isCurrent) {
    final color = isCurrent ? _current : _pencil;
    final tone = shape.tone;
    if (tone != null) {
      // Soft tone, darkest toward the lower right (light from the upper
      // left), clipped to the shaded area; the hatching sits on top.
      final b = tone.getBounds();
      final a = (0.2 * shape.toneDepth).clamp(0.0, 0.5);
      canvas.save();
      canvas.clipPath(tone);
      canvas.drawRect(
        b.inflate(1),
        Paint()
          ..shader = ui.Gradient.linear(
            b.bottomRight,
            b.topLeft,
            [color.withValues(alpha: a), color.withValues(alpha: a * 0.12)],
          ),
      );
      canvas.restore();
    }
    canvas.drawPath(
      shape.path,
      _stroke(isCurrent ? 0.7 : 0.55, color.withValues(alpha: 0.75)),
    );
  }

  void _drawGuide(Canvas canvas, GuideShape shape, bool isCurrent) {
    canvas.drawPath(
      shape.path,
      _stroke(
        isCurrent ? 1.3 : 0.8,
        isCurrent ? _current.withValues(alpha: 0.75) : _helper,
      ),
    );
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
        final isCurrent = i == last && !finished;
        for (final shape in guide.steps[i].shapes) {
          if (shape.kind != kind) continue;
          switch (kind) {
            case GuideKind.guide:
              _drawGuide(canvas, shape, isCurrent);
            case GuideKind.shade:
              _drawShade(canvas, shape, isCurrent);
            case GuideKind.line:
              _drawLine(canvas, shape, isCurrent);
            case GuideKind.dot:
              canvas.drawPath(
                shape.path,
                Paint()
                  ..style = PaintingStyle.fill
                  ..color = isCurrent ? _current : _pencil,
              );
            case GuideKind.shine:
              canvas.drawPath(
                shape.path,
                Paint()
                  ..style = PaintingStyle.fill
                  ..color = Colors.white,
              );
          }
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GuidePreviewPainter old) =>
      old.guide != guide || old.step != step;
}
