import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Path builders shared by coloring pages and lessons.

/// Coloring pages and lessons are drawn in a square of this many units.
const double designSize = 100;

/// Maps the design square into the biggest centered square inside [size].
Matrix4 designMatrix(Size size) {
  final scale = math.min(size.width, size.height) / designSize;
  final dx = (size.width - designSize * scale) / 2;
  final dy = (size.height - designSize * scale) / 2;
  return Matrix4.translationValues(dx, dy, 0) *
      Matrix4.diagonal3Values(scale, scale, 1);
}

Path rectPath(double l, double t, double r, double b) =>
    Path()..addRect(Rect.fromLTRB(l, t, r, b));

Path roundRectPath(double l, double t, double r, double b, double radius) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

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
      ..addArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep);

/// Leaf or petal from [base] to [tip], [width] wide, bulging evenly on both sides.
Path leafPath(Offset base, Offset tip, double width) {
  final mid = (base + tip) / 2;
  final direction = tip - base;
  final bulge =
      Offset(-direction.dy, direction.dx) / direction.distance * width;
  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(mid.dx + bulge.dx, mid.dy + bulge.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(mid.dx - bulge.dx, mid.dy - bulge.dy, base.dx, base.dy)
    ..close();
}

/// Rotates [path] by [angle] radians around [center].
Path rotatePath(Path path, double angle, Offset center) {
  final matrix = Matrix4.translationValues(center.dx, center.dy, 0) *
      Matrix4.rotationZ(angle) *
      Matrix4.translationValues(-center.dx, -center.dy, 0);
  return path.transform(matrix.storage);
}

/// Boolean path operations with readable names.
extension PathCombining on Path {
  Path union(Path other) => Path.combine(PathOperation.union, this, other);
  Path minus(Path other) => Path.combine(PathOperation.difference, this, other);
  Path within(Path other) => Path.combine(PathOperation.intersect, this, other);
}

extension PathListCombining on Iterable<Path> {
  /// All paths merged into one outline.
  Path union() => reduce((a, b) => a.union(b));
}
