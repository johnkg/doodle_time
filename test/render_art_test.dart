// Renders every coloring page and lesson to PNG files for a visual check.
// Skipped unless RENDER_ART names an output folder:
//   RENDER_ART=/tmp/art flutter test test/render_art_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doodle_time/board_painter.dart';
import 'package:doodle_time/drawing_controller.dart';
import 'package:doodle_time/guide_painter.dart';
import 'package:doodle_time/guides.dart';
import 'package:doodle_time/models.dart';
import 'package:doodle_time/pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final String? _out = Platform.environment['RENDER_ART'];

Future<void> _save(
    String name, int w, int h, void Function(Canvas) draw) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = Colors.white);
  draw(canvas);
  final img = await rec.endRecording().toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$_out/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _page(Canvas canvas, ColoringPage p, Offset at, double side, bool filled) {
  final c = DrawingController()..setPage(p);
  if (filled) {
    for (int i = 0; i < p.regions.length; i++) {
      c.ops.add(FillOp(
        region: i,
        color: HSVColor.fromAHSV(1, (i * 47 % 360).toDouble(), 0.45, 0.95)
            .toColor(),
      ));
    }
  }
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.clipRect(Rect.fromLTWH(0, 0, side, side));
  BoardPainter(c).paint(canvas, Size(side, side));
  canvas.restore();
  c.dispose();
}

void main() {
  testWidgets('render art', (tester) async {
    await tester.runAsync(() async {
      const big = 700.0;
      for (final p in coloringPages) {
        await _save('page_${p.name}', (big * 2).toInt(), big.toInt(), (cv) {
          _page(cv, p, Offset.zero, big, false);
          _page(cv, p, const Offset(big, 0), big, true);
        });
      }
      const tile = 330.0;
      for (final filled in [false, true]) {
        await _save(filled ? 'pages_filled' : 'pages', 4 * tile.toInt(),
            3 * tile.toInt(), (cv) {
          for (int i = 0; i < coloringPages.length; i++) {
            _page(cv, coloringPages[i], Offset(i % 4 * tile, i ~/ 4 * tile),
                tile - 6, filled);
          }
        });
      }
      const step = 320.0;
      for (final g in drawingGuides) {
        final n = g.steps.length;
        await _save('lesson_${g.name}', (step * n).toInt(), step.toInt(), (cv) {
          for (int i = 0; i < n; i++) {
            cv.save();
            cv.translate(i * step, 0);
            GuidePreviewPainter(g, i).paint(cv, const Size(step - 8, step));
            cv.restore();
          }
        });
      }
      for (final g in drawingGuides) {
        await _save('final_${g.name}', 600, 600, (cv) {
          GuidePreviewPainter(g, g.steps.length - 1)
              .paint(cv, const Size(600, 600));
        });
      }
      final rows = (drawingGuides.length / 6).ceil();
      await _save('lessons', 6 * tile.toInt(), rows * tile.toInt(), (cv) {
        for (int i = 0; i < drawingGuides.length; i++) {
          final g = drawingGuides[i];
          cv.save();
          cv.translate(i % 6 * tile, i ~/ 6 * tile);
          GuidePreviewPainter(g, g.steps.length - 1)
              .paint(cv, const Size(tile - 6, tile - 6));
          cv.restore();
        }
      });
    });
  }, skip: _out == null);
}
