import 'package:flutter/material.dart';

import 'drawing_controller.dart';
import 'emoji_font.dart';
import 'models.dart';
import 'pages.dart';

/// Paints, bottom to top: white paper, color fills, strokes + stamps
/// (in their own layer so the eraser only removes strokes), page outlines.
class BoardPainter extends CustomPainter {
  BoardPainter(this.c) : super(repaint: c);

  final DrawingController c;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Colors.white);

    final page = c.page;
    List<Path> paths = const [];
    if (page != null) {
      final m = pageMatrix(size);
      paths = [for (final r in page.regions) r.path.transform(m.storage)];
      final fills = <int, Color>{};
      for (final op in c.ops) {
        if (op is FillOp) fills[op.region] = op.color;
      }
      for (int i = 0; i < paths.length; i++) {
        canvas.drawPath(
          paths[i],
          Paint()
            ..style = PaintingStyle.fill
            ..color = fills[i] ?? Colors.white,
        );
      }
    }

    canvas.saveLayer(rect, Paint());
    for (final op in c.ops) {
      if (op is StrokeOp) {
        _drawStroke(canvas, size, op);
      } else if (op is StampOp) {
        _drawStamp(canvas, size, op);
      }
    }
    final live = c.live;
    if (live != null) _drawStroke(canvas, size, live);
    canvas.restore();

    if (page != null) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF212121);
      final detail = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF424242);
      final m = pageMatrix(size);
      final covers = _coversFor(page, size, paths);
      for (int i = 0; i < paths.length; i++) {
        canvas.save();
        final cover = covers[i];
        if (cover != null) {
          // Hide the part of this outline that later regions sit on top of.
          // Even-odd rect + cover = everything except the cover.
          canvas.clipPath(Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(rect)
            ..addPath(cover, Offset.zero));
        }
        canvas.drawPath(paths[i], outline);
        final details = page.regions[i].details;
        if (details.isNotEmpty) {
          // Also clipped to the region, so detail lines can overshoot its edge.
          canvas.clipPath(paths[i]);
          for (final d in details) {
            canvas.drawPath(d.transform(m.storage), detail);
          }
        }
        canvas.restore();
      }
    }
  }

  // Per region: union of all regions drawn after it (null for the top one).
  // Path unions are slow, so keep the last result; it only changes with page or size.
  static ColoringPage? _coverPage;
  static Size? _coverSize;
  static List<Path?> _covers = const [];

  static List<Path?> _coversFor(ColoringPage page, Size size, List<Path> paths) {
    if (page == _coverPage && size == _coverSize) return _covers;
    final covers = List<Path?>.filled(paths.length, null);
    Path? above;
    for (int i = paths.length - 1; i >= 0; i--) {
      covers[i] = above;
      above = above == null
          ? paths[i]
          : Path.combine(PathOperation.union, above, paths[i]);
    }
    _coverPage = page;
    _coverSize = size;
    return _covers = covers;
  }

  void _drawStroke(Canvas canvas, Size size, StrokeOp s) {
    final pts = [
      for (final p in s.points) Offset(p.dx * size.width, p.dy * size.height),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    if (s.erase) {
      paint.blendMode = BlendMode.clear;
    } else {
      paint.color = s.color;
    }

    // A single tap leaves a dot.
    if (pts.length == 1) {
      final dot = Paint()..style = PaintingStyle.fill;
      if (s.erase) {
        dot.blendMode = BlendMode.clear;
      } else {
        dot.color = s.rainbow ? _rainbowColor(0) : s.color;
      }
      canvas.drawCircle(pts.first, s.width / 2, dot);
      return;
    }

    if (s.rainbow && !s.erase) {
      for (int i = 1; i < pts.length; i++) {
        paint.color = _rainbowColor(i);
        canvas.drawLine(pts[i - 1], pts[i], paint);
      }
      return;
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }

  Color _rainbowColor(int i) =>
      HSVColor.fromAHSV(1, (i * 9 % 360).toDouble(), 0.85, 1).toColor();

  void _drawStamp(Canvas canvas, Size size, StampOp s) {
    final tp = TextPainter(
      text: TextSpan(
        text: s.emoji,
        // Not under the app theme, so name the emoji font here too.
        style: TextStyle(fontSize: s.size, fontFamilyFallback: kEmojiFallback),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final center = Offset(s.center.dx * size.width, s.center.dy * size.height);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
