import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Path builders shared by coloring pages and lessons (100 x 100 design space).

Path rectPath(double l, double t, double r, double b) =>
    Path()..addRect(Rect.fromLTRB(l, t, r, b));

Path roundRectPath(double l, double t, double r, double b, double radius) =>
    Path()
      ..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

Path ovalPath(double l, double t, double r, double b) =>
    Path()..addOval(Rect.fromLTRB(l, t, r, b));

Path circlePath(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

/// Ellipse centered on (cx, cy), rotated by [angle] radians.
Path ellipsePath(double cx, double cy, double rx, double ry,
    {double angle = 0}) {
  final m = Matrix4.translationValues(cx, cy, 0)..rotateZ(angle);
  return (Path()..addOval(Rect.fromLTRB(-rx, -ry, rx, ry)))
      .transform(m.storage);
}

/// Straight segments through [pts]; [close] joins the last point to the first.
Path polyPath(List<Offset> pts, {bool close = true}) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final o in pts.skip(1)) {
    p.lineTo(o.dx, o.dy);
  }
  if (close) p.close();
  return p;
}

/// Smooth curve through every point in [pts] (Catmull-Rom spline).
/// With [close] the curve loops back to the start and makes a closed shape.
Path smoothPath(List<Offset> pts, {bool close = false}) {
  final n = pts.length;
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  if (n < 3) {
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
  }
  Offset at(int i) => close ? pts[i % n] : pts[i.clamp(0, n - 1)];
  final segments = close ? n : n - 1;
  for (int i = 0; i < segments; i++) {
    final p0 = at(close ? i - 1 + n : i - 1);
    final p1 = at(i);
    final p2 = at(i + 1);
    final p3 = at(i + 2);
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  if (close) p.close();
  return p;
}

/// Closed smooth shape through [pts].
Path blobPath(List<Offset> pts) => smoothPath(pts, close: true);

/// Points around a circle, handy for petals, rays and star shapes.
List<Offset> ringPoints(double cx, double cy, double r, int count,
        {double start = -math.pi / 2}) =>
    [
      for (int i = 0; i < count; i++)
        Offset(cx + r * math.cos(start + i * 2 * math.pi / count),
            cy + r * math.sin(start + i * 2 * math.pi / count)),
    ];

/// Points alternating between radius [ro] and [ri]: a star or a zigzag crown.
List<Offset> starPoints(double cx, double cy, double ro, double ri, int tips,
        {double start = -math.pi / 2}) =>
    [
      for (int i = 0; i < tips * 2; i++)
        Offset(cx + (i.isEven ? ro : ri) * math.cos(start + i * math.pi / tips),
            cy + (i.isEven ? ro : ri) * math.sin(start + i * math.pi / tips)),
    ];

/// Arc of a circle (open path).
Path arcPath(double cx, double cy, double r, double start, double sweep) =>
    Path()
      ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep);
