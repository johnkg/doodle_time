import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shapes.dart';

/// One shape of a "how to draw" lesson, in a 100 x 100 design space.
/// [fill] shapes are small solid dots (eyes, buttons); the rest are outlines.
class GuideShape {
  GuideShape(this.path, {this.fill = false});
  final Path path;
  final bool fill;
}

class GuideStep {
  GuideStep(this.text, this.shapes);

  /// Short instruction a young child can follow (with an emoji hint).
  final String text;

  /// Shapes added in this step. Earlier steps stay visible in gray.
  final List<GuideShape> shapes;
}

class DrawingGuide {
  DrawingGuide(this.name, this.emoji, this.steps, {this.level = 1});
  final String name;
  final String emoji;
  final List<GuideStep> steps;

  /// 1 = easy, 2 = medium, 3 = harder. Used to group the picker.
  final int level;
}

// ---- tiny builders ----------------------------------------------------------
// Parts that touch should meet at their edges rather than overlap, so a child
// never sees one line running through another shape.

GuideShape _line(List<Offset> pts, {bool close = false}) =>
    GuideShape(polyPath(pts, close: close));

/// Smooth curve through the points; [close] makes a closed shape.
GuideShape _smooth(List<Offset> pts, {bool close = false}) =>
    GuideShape(smoothPath(pts, close: close));

GuideShape _circle(double cx, double cy, double r) =>
    GuideShape(circlePath(cx, cy, r));

GuideShape _dot(double cx, double cy, double r) =>
    GuideShape(circlePath(cx, cy, r), fill: true);

GuideShape _oval(double cx, double cy, double rx, double ry, {double angle = 0}) =>
    GuideShape(ellipsePath(cx, cy, rx, ry, angle: angle));

GuideShape _rect(double l, double t, double r, double b) =>
    GuideShape(rectPath(l, t, r, b));

GuideShape _round(double l, double t, double r, double b, double radius) =>
    GuideShape(roundRectPath(l, t, r, b, radius));

GuideShape _arc(double cx, double cy, double r, double start, double sweep) =>
    GuideShape(arcPath(cx, cy, r, start, sweep));

GuideShape _star(double cx, double cy, double r) =>
    GuideShape(polyPath(starPoints(cx, cy, r, r * 0.45, 5)));

/// Leaf or petal from [base] to [tip], [w] wide.
GuideShape _leaf(Offset base, Offset tip, double w) {
  final mid = (base + tip) / 2;
  final d = tip - base;
  final n = Offset(-d.dy, d.dx) / d.distance * w;
  return GuideShape(Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy)
    ..close());
}

/// Middle vein and a few side veins for a [_leaf].
List<GuideShape> _veins(Offset base, Offset tip, double w) {
  final d = tip - base;
  final n = Offset(-d.dy, d.dx) / d.distance * w * 0.32;
  return [
    _line([base, base + d * 0.85]),
    for (final t in [0.35, 0.6])
      for (final side in [1.0, -1.0])
        _line([base + d * t, base + d * (t + 0.15) + n * side]),
  ];
}

/// Point on an ellipse at [angle] (0 = right, pi/2 = down).
Offset _on(double cx, double cy, double rx, double ry, double angle) =>
    Offset(cx + rx * math.cos(angle), cy + ry * math.sin(angle));

/// Rows of little arcs (tiles, scales) kept fully inside [area].
List<GuideShape> _scallops(Path area, Rect box, double s, {Path? avoid}) {
  final out = <GuideShape>[];
  int row = 0;
  for (double y = box.top; y < box.bottom; y += s * 0.65, row++) {
    for (double x = box.left + (row.isOdd ? s / 2 : 0); x < box.right; x += s) {
      final probes = [
        Offset(x - s / 2, y), Offset(x, y + s / 2), Offset(x + s / 2, y),
      ];
      if (probes.every(area.contains) &&
          (avoid == null || !probes.any(avoid.contains))) {
        out.add(_arc(x, y, s / 2, 0, math.pi));
      }
    }
  }
  return out;
}

/// Little grass tufts.
List<GuideShape> _tufts(List<Offset> spots) => [
      for (final p in spots)
        _line([
          p + const Offset(-1.8, 0),
          p + const Offset(-0.8, -3.2),
          p + const Offset(0, -0.4),
          p + const Offset(1, -3.6),
          p + const Offset(1.8, 0),
        ]),
    ];

/// A bird far away: two little arcs.
List<GuideShape> _gull(double x, double y) => [
      _arc(x - 2.2, y + 1.3, 2.2, 3.8, 1.9),
      _arc(x + 2.2, y + 1.3, 2.2, 3.7, 1.9),
    ];

// ---- lessons (easiest first) ---------------------------------------------------

DrawingGuide _sun() => DrawingGuide('Sun', '☀️', [
      GuideStep('Draw a big circle ⭕', [_circle(50, 50, 16)]),
      GuideStep('Draw pointy rays all around it 🔺', [
        for (int i = 0; i < 8; i++)
          _line([
            _on(50, 50, 19, 19, i * math.pi / 4 - 0.17),
            _on(50, 50, 33, 33, i * math.pi / 4),
            _on(50, 50, 19, 19, i * math.pi / 4 + 0.17),
          ]),
      ]),
      GuideStep('Add little wavy rays in between ✨', [
        for (int i = 0; i < 8; i++)
          _smooth([
            _on(50, 50, 20, 20, i * math.pi / 4 + math.pi / 8),
            _on(50, 50, 23.5, 23.5, i * math.pi / 4 + math.pi / 8 + 0.06),
            _on(50, 50, 27, 27, i * math.pi / 4 + math.pi / 8),
          ]),
      ]),
      GuideStep('Add two eyes and round cheeks 👀', [
        _dot(44, 46, 2.2),
        _dot(56, 46, 2.2),
        _circle(39.5, 53, 2.6),
        _circle(60.5, 53, 2.6),
      ]),
      GuideStep('Add a big smile 😊', [_arc(50, 51, 7, 0.35, math.pi - 0.7)]),
    ]);

DrawingGuide _apple() => DrawingGuide('Apple', '🍎', [
      GuideStep('Draw a round apple with a dip on top 🍎', [
        _smooth(const [
          Offset(50, 34), Offset(60, 28), Offset(72, 32), Offset(78, 46),
          Offset(76, 64), Offset(68, 78), Offset(58, 82), Offset(50, 79),
          Offset(42, 82), Offset(32, 78), Offset(24, 64), Offset(22, 46),
          Offset(28, 32), Offset(40, 28),
        ], close: true),
      ]),
      GuideStep('Draw a little stem 🌿', [
        _smooth(const [Offset(49, 34), Offset(48.6, 27), Offset(50, 19)]),
        _smooth(const [Offset(52, 33.4), Offset(51.6, 26), Offset(53, 19)]),
        _line(const [Offset(50, 19), Offset(53, 19)]),
      ]),
      GuideStep('Add a leaf with lines in it 🍃', [
        _leaf(const Offset(52.4, 25), const Offset(70, 16), 6),
        ..._veins(const Offset(52.4, 25), const Offset(70, 16), 6),
      ]),
      GuideStep('Add a shiny spot ✨', [
        _smooth(const [Offset(30, 52), Offset(31, 43), Offset(37, 36)]),
        _oval(33, 58, 1.4, 2.6),
      ]),
      GuideStep('Add tiny freckles 🟤', [
        for (final (x, y) in const [
          (60.0, 44.0), (66.0, 54.0), (56.0, 62.0), (44.0, 66.0), (64.0, 68.0),
          (52.0, 50.0), (40.0, 56.0),
        ])
          _dot(x, y, 0.8),
      ]),
      GuideStep('Draw a shadow under the apple 🌑', [
        _smooth(const [Offset(28, 88), Offset(50, 91), Offset(72, 88)]),
      ]),
    ]);

DrawingGuide _moon() => DrawingGuide('Moon', '🌙', [
      GuideStep('Draw a crescent moon like a big letter C 🌙', [
        GuideShape(Path.combine(PathOperation.difference,
            circlePath(50, 50, 30), circlePath(64, 42, 26))),
      ]),
      GuideStep('Draw a sleepy eye with lashes 😴', [
        _smooth(const [Offset(25, 45), Offset(29, 48.5), Offset(33, 45)]),
        _line(const [Offset(26.5, 47), Offset(25, 49.5)]),
        _line(const [Offset(29, 48.5), Offset(29, 51.5)]),
        _line(const [Offset(31.5, 47), Offset(33, 49.5)]),
      ]),
      GuideStep('Add a smile and a rosy cheek 🙂', [
        _smooth(const [Offset(27, 60), Offset(31, 63), Offset(36, 61)]),
        _circle(36, 54.5, 2.4),
      ]),
      GuideStep('Draw some round craters ⚪', [
        _circle(38, 28, 2.2),
        _circle(34, 71, 2.5),
        _circle(24.5, 58, 1.6),
      ]),
      GuideStep('Draw three stars ⭐', [
        _star(80, 70, 6),
        _star(84, 24, 4.5),
        _star(66, 88, 3.5),
      ]),
      GuideStep('Add tiny twinkle dots ✨', [
        _dot(12, 14, 1.2),
        _dot(90, 48, 1.2),
        _dot(56, 10, 1.2),
        _dot(92, 90, 1.2),
      ]),
      GuideStep('Draw a fluffy cloud below ☁️', [
        GuideShape(Path.combine(
            PathOperation.union,
            Path.combine(PathOperation.union, circlePath(14, 88, 6),
                circlePath(22, 84, 7.5)),
            Path.combine(PathOperation.union, circlePath(31, 88, 6),
                circlePath(22, 91, 5)))),
      ]),
    ]);

DrawingGuide _house() {
  final roof = polyPath(const [Offset(20, 48), Offset(50, 22), Offset(80, 48)]);
  final chimney = rectPath(59.5, 17, 67.5, 48);
  return DrawingGuide('House', '🏠', [
    GuideStep('Draw the walls like a box with no lid ⬜', [
      _line(const [Offset(26, 48), Offset(26, 82), Offset(74, 82), Offset(74, 48)]),
    ]),
    GuideStep('Draw a big triangle roof 🔺', [GuideShape(roof)]),
    GuideStep('Add a chimney with curly smoke 💨', [
      _line(const [Offset(60, 30.7), Offset(60, 20), Offset(67, 20), Offset(67, 36.7)]),
      _rect(58.5, 17, 68.5, 20),
      _smooth(const [Offset(64, 15), Offset(66.5, 11), Offset(62.5, 7.5), Offset(66, 3)]),
    ]),
    GuideStep('Draw a door with a round top and a knob 🚪', [
      GuideShape(Path()
        ..moveTo(44, 82)
        ..lineTo(44, 67)
        ..arcToPoint(const Offset(56, 67), radius: const Radius.circular(6))
        ..lineTo(56, 82)),
      _line(const [Offset(46.5, 70), Offset(53.5, 70)]),
      _dot(54, 76, 1),
    ]),
    GuideStep('Draw two windows with crosses 🪟', [
      _rect(31, 56, 41, 66),
      _line(const [Offset(36, 56), Offset(36, 66)]),
      _line(const [Offset(31, 61), Offset(41, 61)]),
      _rect(30, 66, 42, 68.5),
      _rect(59, 56, 69, 66),
      _line(const [Offset(64, 56), Offset(64, 66)]),
      _line(const [Offset(59, 61), Offset(69, 61)]),
      _rect(58, 66, 70, 68.5),
    ]),
    GuideStep('Draw little bumps on the roof for tiles 🧱', [
      ..._scallops(roof, const Rect.fromLTRB(20, 31, 80, 46), 4.4, avoid: chimney),
    ]),
    GuideStep('Add the ground, a path and some grass 🌱', [
      _line(const [Offset(4, 82), Offset(26, 82)]),
      _line(const [Offset(74, 82), Offset(96, 82)]),
      _line(const [Offset(45, 82), Offset(39, 97)]),
      _line(const [Offset(55, 82), Offset(61, 97)]),
      _oval(48, 86.5, 2.8, 1.5),
      _oval(52, 92, 3.4, 1.8),
      ..._tufts(const [Offset(12, 90), Offset(24, 94), Offset(78, 92), Offset(90, 88)]),
    ]),
  ]);
}

DrawingGuide _tree() => DrawingGuide('Tree', '🌳', [
      GuideStep('Draw a big bumpy cloud shape for the leaves 🌳', [
        GuideShape([
          circlePath(50, 32, 16), circlePath(34, 40, 13), circlePath(66, 40, 13),
          circlePath(40, 54, 11), circlePath(60, 54, 11), circlePath(50, 50, 13),
        ].reduce((a, b) => Path.combine(PathOperation.union, a, b))),
      ]),
      GuideStep('Draw the trunk getting wider at the bottom 🪵', [
        _smooth(const [Offset(45, 62), Offset(44, 74), Offset(42, 84), Offset(35, 90)]),
        _smooth(const [Offset(55, 62), Offset(56, 74), Offset(58, 84), Offset(65, 90)]),
      ]),
      GuideStep('Draw the ground on both sides ➖', [
        _line(const [Offset(6, 90), Offset(35, 90)]),
        _line(const [Offset(65, 90), Offset(94, 90)]),
      ]),
      GuideStep('Add lines and a hole in the bark 🦉', [
        _smooth(const [Offset(47.5, 66), Offset(47, 72)]),
        _smooth(const [Offset(53, 78), Offset(53.6, 86)]),
        _oval(50, 76, 2, 3),
      ]),
      GuideStep('Draw little curls in the leaves 🍃', [
        _arc(38, 38, 3, 3.4, 2),
        _arc(56, 24, 3, 3.4, 2),
        _arc(64, 46, 3, 3.4, 2),
        _arc(48, 44, 3, 3.4, 2),
      ]),
      GuideStep('Add some apples 🍎', [
        for (final (x, y) in const [(44.0, 30.0), (60.0, 34.0), (36.0, 50.0), (58.0, 54.0)]) ...[
          _circle(x, y, 2.6),
          _line([Offset(x, y - 2.6), Offset(x + 0.8, y - 4.2)]),
        ],
      ]),
      GuideStep('Add grass and a flying bird 🐦', [
        ..._tufts(const [Offset(14, 90), Offset(26, 90), Offset(76, 90), Offset(88, 90)]),
        ..._gull(84, 12),
      ]),
    ]);

DrawingGuide _mushroom() {
  // Cap bottom and gill line are symmetric quadratics, so x moves evenly with t.
  double capY(double x) {
    final t = (x - 14) / 72;
    return 52 - 16 * t * (1 - t);
  }

  double gillY(double x) {
    final t = (x - 16) / 68;
    return 52.5 + 15 * t * (1 - t);
  }

  return DrawingGuide('Mushroom', '🍄', [
    GuideStep('Draw a big round cap like an umbrella 🍄', [
      GuideShape(Path()
        ..moveTo(14, 52)
        ..cubicTo(14, 24, 34, 14, 50, 14)
        ..cubicTo(66, 14, 86, 24, 86, 52)
        ..quadraticBezierTo(50, 44, 14, 52)
        ..close()),
    ]),
    GuideStep('Draw a curve under the cap with little lines 〰️', [
      GuideShape(Path()
        ..moveTo(16, 52.5)
        ..quadraticBezierTo(50, 60, 84, 52.5)),
      for (final x in [24.0, 30.0, 36.0, 64.0, 70.0, 76.0])
        _line([Offset(x, capY(x)), Offset(x + (x < 50 ? 1 : -1), gillY(x + (x < 50 ? 1 : -1)))]),
    ]),
    GuideStep('Draw a thick stem with a round bottom 🟫', [
      _smooth([Offset(40, gillY(40)), const Offset(39, 70), const Offset(37, 84)]),
      _smooth([Offset(60, gillY(60)), const Offset(61, 70), const Offset(63, 84)]),
      _smooth(const [
        Offset(37, 84), Offset(34, 87), Offset(40, 90), Offset(60, 90),
        Offset(66, 87), Offset(63, 84),
      ]),
    ]),
    GuideStep('Add a frilly ring on the stem 🎀', [
      _smooth(const [Offset(39.5, 66), Offset(50, 70), Offset(60.6, 66)]),
      _smooth(const [Offset(39.3, 68.5), Offset(50, 73), Offset(60.8, 68.5)]),
    ]),
    GuideStep('Draw round spots on the cap ⚪', [
      _oval(30, 36, 5, 3.4),
      _oval(50, 24, 6, 4),
      _oval(69, 34, 5, 3.4),
      _oval(58, 41, 3.5, 2.4),
      _oval(40, 42, 3, 2),
    ]),
    GuideStep('Draw a baby mushroom next to it 🍄', [
      GuideShape(Path()
        ..moveTo(72, 82)
        ..cubicTo(72, 72, 88, 72, 88, 82)
        ..close()),
      _line(const [Offset(78, 82), Offset(77.5, 90)]),
      _line(const [Offset(82, 82), Offset(82.5, 90)]),
    ]),
    GuideStep('Add the ground and grass 🌱', [
      _line(const [Offset(4, 90), Offset(40, 90)]),
      _line(const [Offset(60, 90), Offset(77.5, 90)]),
      _line(const [Offset(82.5, 90), Offset(96, 90)]),
      ..._tufts(const [Offset(12, 90), Offset(26, 90), Offset(68, 90), Offset(92, 90)]),
    ]),
  ]);
}

DrawingGuide _robot() => DrawingGuide('Robot', '🤖', [
      GuideStep('Draw a square head with round corners ⬜', [_round(32, 16, 68, 44, 4)]),
      GuideStep('Add two round eyes 👀', [
        _circle(42, 27, 5),
        _circle(58, 27, 5),
        _dot(42, 27, 2.2),
        _dot(58, 27, 2.2),
      ]),
      GuideStep('Draw a mouth with stripes 😬', [
        _rect(40, 35, 60, 40),
        for (final x in [44.0, 48.0, 52.0, 56.0]) _line([Offset(x, 35), Offset(x, 40)]),
      ]),
      GuideStep('Add an antenna and ear bolts 📡', [
        _line(const [Offset(50, 16), Offset(50, 8.4)]),
        _circle(50, 6, 2.4),
        _rect(28, 24, 32, 36),
        _rect(68, 24, 72, 36),
      ]),
      GuideStep('Draw a neck and a big body 🟦', [
        _line(const [Offset(45, 44), Offset(45, 48)]),
        _line(const [Offset(55, 44), Offset(55, 48)]),
        _round(30, 48, 70, 80, 3),
      ]),
      GuideStep('Draw a panel with buttons and a dial 🔘', [
        _rect(38, 54, 62, 72),
        _circle(43, 59, 2),
        _circle(50, 59, 2),
        _circle(57, 62, 3.4),
        _line(const [Offset(57, 62), Offset(59, 59.5)]),
        _line(const [Offset(41, 67), Offset(50, 67)]),
      ]),
      GuideStep('Add two arms with round hands 💪', [
        _rect(18, 52, 30, 58),
        _circle(14, 55, 4),
        _rect(70, 52, 82, 58),
        _circle(86, 55, 4),
      ]),
      GuideStep('Draw two legs and big feet 🦶', [
        _line(const [Offset(37, 80), Offset(37, 92)]),
        _line(const [Offset(47, 80), Offset(47, 92)]),
        _line(const [Offset(53, 80), Offset(53, 92)]),
        _line(const [Offset(63, 80), Offset(63, 92)]),
        _round(33, 92, 49, 97, 2),
        _round(51, 92, 67, 97, 2),
      ]),
    ]);

DrawingGuide _sailboat() => DrawingGuide('Sailboat', '⛵', [
      GuideStep('Draw the boat with a curved bottom 🛶', [
        GuideShape(Path()
          ..moveTo(16, 64)
          ..lineTo(86, 64)
          ..quadraticBezierTo(80, 77, 72, 80)
          ..lineTo(32, 80)
          ..quadraticBezierTo(22, 77, 16, 64)
          ..close()),
      ]),
      GuideStep('Add a line and round windows 🔘', [
        _line(const [Offset(18.8, 69), Offset(83.4, 69)]),
        _circle(38, 74, 2.2),
        _circle(50, 74, 2.2),
        _circle(62, 74, 2.2),
      ]),
      GuideStep('Draw a tall mast with a flag 🚩', [
        _line(const [Offset(50, 64), Offset(50, 8)]),
        _line(const [Offset(50, 8.5), Offset(60, 11), Offset(50, 13.5)]),
      ]),
      GuideStep('Draw a big curvy sail ⛵', [
        GuideShape(Path()
          ..moveTo(52, 15)
          ..quadraticBezierTo(66, 32, 76, 53)
          ..lineTo(52, 53)
          ..close()),
        _line(const [Offset(52, 26), Offset(60, 25)]),
        _line(const [Offset(52, 38), Offset(67, 37)]),
        _round(51, 54, 78, 56.5, 1.2),
      ]),
      GuideStep('Draw a smaller sail in front 🔺', [
        GuideShape(Path()
          ..moveTo(48, 17)
          ..quadraticBezierTo(36, 37, 24, 58)
          ..lineTo(48, 58)
          ..close()),
      ]),
      GuideStep('Add a little cabin on the deck 🏠', [
        _line(const [Offset(54, 64), Offset(54, 58.5), Offset(68, 58.5), Offset(68, 64)]),
        _circle(58, 61.3, 1.3),
        _circle(64, 61.3, 1.3),
      ]),
      GuideStep('Draw wavy water 🌊', [
        _smooth([for (int i = 0; i <= 10; i++) Offset(i * 10.0, i.isEven ? 84 : 81)]),
        _smooth([for (int i = 0; i <= 8; i++) Offset(6 + i * 11.0, i.isEven ? 93 : 90)]),
      ]),
      GuideStep('Add the sun and two birds ☀️', [
        _circle(86, 16, 6),
        for (int i = 0; i < 8; i++)
          _line([
            _on(86, 16, 8, 8, i * math.pi / 4),
            _on(86, 16, 11, 11, i * math.pi / 4),
          ]),
        ..._gull(24, 14),
        ..._gull(33, 22),
      ]),
    ]);

DrawingGuide _fish() {
  final body = smoothPath(const [
    Offset(81, 52), Offset(76, 43), Offset(64, 36), Offset(48, 36),
    Offset(34, 42), Offset(25, 49), Offset(25, 55), Offset(34, 61),
    Offset(48, 67), Offset(64, 67), Offset(76, 61),
  ], close: true);
  final fin = ellipsePath(51, 56, 7, 3.3, angle: 0.5);
  return DrawingGuide('Fish', '🐟', [
    GuideStep('Draw a long body with a pointy nose 🐟', [GuideShape(body)]),
    GuideStep('Add a tail with two points 🐠', [
      GuideShape(Path()
        ..moveTo(25.6, 48.6)
        ..quadraticBezierTo(18, 40, 7, 36)
        ..quadraticBezierTo(12, 46, 15, 52)
        ..quadraticBezierTo(12, 58, 7, 68)
        ..quadraticBezierTo(18, 64, 25.6, 55.4)),
      _line(const [Offset(23, 52), Offset(12, 42)]),
      _line(const [Offset(23, 52), Offset(12, 62)]),
    ]),
    GuideStep('Draw a fin on top and one below 🌊', [
      GuideShape(Path()
        ..moveTo(38, 40)
        ..quadraticBezierTo(42, 26, 56, 22)
        ..quadraticBezierTo(62, 28, 66, 37)),
      GuideShape(Path()
        ..moveTo(44, 65.6)
        ..quadraticBezierTo(46, 74, 52, 76)
        ..quadraticBezierTo(56, 72, 60, 67.2)),
    ]),
    GuideStep('Add an eye, a gill line and a mouth 👁️', [
      _circle(70, 47, 4),
      _dot(71, 47, 2.2),
      _smooth(const [Offset(63, 39), Offset(59.5, 51), Offset(63, 63)]),
      _smooth(const [Offset(81, 52.5), Offset(77.5, 54.5), Offset(74, 53.5)]),
    ]),
    GuideStep('Draw a little fin on the side 🪶', [
      GuideShape(fin),
      _line(const [Offset(45.5, 53), Offset(55, 57.5)]),
      _line(const [Offset(45.5, 53), Offset(53, 60)]),
    ]),
    GuideStep('Draw little bumps for scales 🐟', [
      ..._scallops(body, const Rect.fromLTRB(28, 40, 58, 64), 5, avoid: fin),
    ]),
    GuideStep('Add bubbles and seaweed 🫧', [
      _circle(88, 38, 3),
      _circle(92, 28, 2.4),
      _circle(87, 19, 3.4),
      _smooth(const [Offset(84, 96), Offset(81, 86), Offset(85, 76), Offset(82, 66)]),
      _smooth(const [Offset(89, 96), Offset(86, 86), Offset(90, 76), Offset(87, 68)]),
      _line(const [Offset(0, 96), Offset(100, 96)]),
    ]),
  ]);
}

DrawingGuide _flower() {
  const c = Offset(50, 30);
  return DrawingGuide('Flower', '🌻', [
    GuideStep('Draw a circle for the middle ⭕', [_circle(c.dx, c.dy, 9)]),
    GuideStep('Draw pointy petals all around 🌻', [
      for (int i = 0; i < 14; i++)
        _leaf(_on(c.dx, c.dy, 9, 9, i * 2 * math.pi / 14 + 0.22),
            _on(c.dx, c.dy, 24, 24, i * 2 * math.pi / 14 + 0.22), 4.6),
    ]),
    GuideStep('Fill the middle with seeds 🌰', [
      _dot(c.dx, c.dy, 0.9),
      for (final o in ringPoints(c.dx, c.dy, 3.4, 6)) _dot(o.dx, o.dy, 0.9),
      for (final o in ringPoints(c.dx, c.dy, 6.4, 10, start: 0.3)) _dot(o.dx, o.dy, 0.9),
    ]),
    GuideStep('Draw a long stem 🌱', [
      _smooth(const [Offset(48.6, 52), Offset(48, 70), Offset(49, 92)]),
      _smooth(const [Offset(51.4, 52), Offset(52, 70), Offset(53, 92)]),
    ]),
    GuideStep('Add two big leaves 🍃', [
      _leaf(const Offset(48.2, 72), const Offset(28, 62), 8),
      ..._veins(const Offset(48.2, 72), const Offset(28, 62), 8),
      _leaf(const Offset(52.4, 80), const Offset(72, 70), 8),
      ..._veins(const Offset(52.4, 80), const Offset(72, 70), 8),
    ]),
    GuideStep('Add grass and a buzzy bee 🐝', [
      _line(const [Offset(4, 92), Offset(49, 92)]),
      _line(const [Offset(53, 92), Offset(96, 92)]),
      ..._tufts(const [Offset(14, 92), Offset(30, 92), Offset(70, 92), Offset(86, 92)]),
      _oval(82, 30, 4.6, 3),
      _line(const [Offset(80.5, 27.3), Offset(80.5, 32.7)]),
      _line(const [Offset(83.5, 27.3), Offset(83.5, 32.7)]),
      _oval(80.5, 24.2, 2, 3, angle: -0.4),
      _oval(84, 24.2, 2, 3, angle: 0.4),
    ]),
  ]);
}

DrawingGuide _iceCream() => DrawingGuide('Ice cream', '🍦', [
      GuideStep('Draw a cone pointing down 🔻', [
        _line(const [Offset(35, 59), Offset(50, 97), Offset(65, 59)]),
      ]),
      GuideStep('Draw a band across the top of the cone ➖', [
        _round(32, 51, 68, 59, 2.5),
      ]),
      GuideStep('Draw crossing lines on the cone ✖️', [
        for (final t in [0.0, 0.25, 0.5]) ...[
          _line([Offset(35 + 15 * t, 59 + 38 * t), Offset(65 - 15 * (t + 0.3), 59 + 38 * (t + 0.3))]),
          _line([Offset(65 - 15 * t, 59 + 38 * t), Offset(35 + 15 * (t + 0.3), 59 + 38 * (t + 0.3))]),
        ],
      ]),
      GuideStep('Draw a big scoop with drips 🍨', [
        _smooth(const [
          Offset(30, 49), Offset(28, 41), Offset(33, 33), Offset(42, 29),
          Offset(50, 30), Offset(58, 29), Offset(67, 33), Offset(72, 41),
          Offset(70, 49), Offset(66, 50.5), Offset(63, 48.5), Offset(60, 51),
          Offset(56, 49), Offset(52, 51), Offset(48, 49), Offset(44, 51),
          Offset(40, 49), Offset(36, 51), Offset(33, 49.5),
        ], close: true),
      ]),
      GuideStep('Draw another scoop on top 🍦', [
        _smooth(const [
          Offset(38.5, 30.6), Offset(37, 23), Offset(42, 16), Offset(50, 13.5),
          Offset(58, 16), Offset(63, 23), Offset(61.5, 30.6),
        ]),
      ]),
      GuideStep('Put a cherry on top 🍒', [
        _circle(50, 9.6, 3.8),
        _smooth(const [Offset(50.5, 5.8), Offset(51.5, 3), Offset(54, 1)]),
      ]),
      GuideStep('Add sprinkles ✨', [
        for (final (x, y) in const [
          (36.0, 40.0), (44.0, 36.0), (56.0, 38.0), (64.0, 42.0), (48.0, 44.0),
          (46.0, 22.0), (54.0, 20.0), (50.0, 27.0),
        ])
          _line([Offset(x, y), Offset(x + 2, y + 1)]),
      ]),
    ]);

DrawingGuide _car() {
  final body = Path.combine(
    PathOperation.difference,
    smoothPath(const [
      Offset(9, 71), Offset(8, 62), Offset(11, 55), Offset(24, 52),
      Offset(34, 40), Offset(44, 37.5), Offset(58, 38), Offset(66, 42),
      Offset(73, 51), Offset(86, 54), Offset(92, 58), Offset(93, 66),
      Offset(91, 72), Offset(70, 72.5), Offset(30, 72.5),
    ], close: true),
    Path.combine(PathOperation.union, circlePath(26, 73, 11), circlePath(74, 73, 11)),
  );
  return DrawingGuide('Car', '🚗', [
    GuideStep('Draw the car with two round holes for wheels 🚗', [GuideShape(body)]),
    GuideStep('Add two windows and a mirror 🪟', [
      _line(const [Offset(30, 51), Offset(37, 42), Offset(46, 40), Offset(46, 51)], close: true),
      _line(const [Offset(49, 51), Offset(49, 40), Offset(58, 40.5), Offset(64, 43), Offset(69, 51)], close: true),
      _oval(68, 48.5, 2.2, 1.6),
    ]),
    GuideStep('Draw two big wheels ⭕⭕', [
      _circle(26, 73, 9),
      _circle(74, 73, 9),
    ]),
    GuideStep('Add circles and spokes in the wheels 🛞', [
      for (final x in [26.0, 74.0]) ...[
        _circle(x, 73, 5),
        _dot(x, 73, 1.6),
        for (int i = 0; i < 5; i++)
          _line([_on(x, 73, 1.6, 1.6, i * 2 * math.pi / 5), _on(x, 73, 5, 5, i * 2 * math.pi / 5)]),
      ],
    ]),
    GuideStep('Draw the doors and handles 🚪', [
      _line(const [Offset(47.5, 51), Offset(47.5, 70)]),
      _smooth(const [Offset(28.5, 53), Offset(33, 64), Offset(37.2, 69)]),
      _smooth(const [Offset(70.5, 52), Offset(68, 63), Offset(62.8, 69)]),
      _round(38, 55, 43, 56.8, 0.9),
      _round(56, 55, 61, 56.8, 0.9),
    ]),
    GuideStep('Add a headlight and a back light 💡', [
      _smooth(const [Offset(86, 56.5), Offset(91, 58), Offset(91.5, 62), Offset(87, 61)], close: true),
      _round(9, 57, 12.5, 63, 1),
    ]),
    GuideStep('Draw the road and zoom lines 💨', [
      _line(const [Offset(0, 82), Offset(100, 82)]),
      _line(const [Offset(0, 58), Offset(5, 58)]),
      _line(const [Offset(0, 64), Offset(6, 64)]),
      _line(const [Offset(1, 70), Offset(6, 70)]),
    ]),
  ]);
}

/// Same shape flipped left to right (for wings, ears, legs).
GuideShape _flip(GuideShape s) => GuideShape(
    s.path.transform(
        (Matrix4.translationValues(100, 0, 0) * Matrix4.diagonal3Values(-1, 1, 1))
            .storage),
    fill: s.fill);

/// Tapered curly arm along [center], [w] wide at the start. Open at the base.
GuideShape _tentacle(List<Offset> center, double w) {
  final n = center.length;
  final left = <Offset>[];
  final right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final d = center[math.min(i + 1, n - 1)] - center[math.max(i - 1, 0)];
    final normal = Offset(-d.dy, d.dx) / d.distance;
    final half = w / 2 * (1 - 0.8 * i / (n - 1));
    left.add(center[i] + normal * half);
    right.add(center[i] - normal * half);
  }
  final tip = center[n - 1] + (center[n - 1] - center[n - 2]) / (center[n - 1] - center[n - 2]).distance * 0.8;
  return _smooth([...left, tip, ...right.reversed]);
}

/// Parts of an ellipse outline that are not inside [hide].
List<GuideShape> _ellipseOutside(
    double cx, double cy, double rx, double ry, double angle, Path hide) {
  final runs = <List<Offset>>[];
  List<Offset>? run;
  for (int i = 0; i <= 120; i++) {
    final a = i * 2 * math.pi / 120;
    final p0 = Offset(rx * math.cos(a), ry * math.sin(a));
    final p = Offset(cx + p0.dx * math.cos(angle) - p0.dy * math.sin(angle),
        cy + p0.dx * math.sin(angle) + p0.dy * math.cos(angle));
    if (hide.contains(p)) {
      run = null;
    } else {
      if (run == null) runs.add(run = []);
      run.add(p);
    }
  }
  return [for (final r in runs) if (r.length > 1) _line(r)];
}

DrawingGuide _train() => DrawingGuide('Train', '🚂', [
      GuideStep('Draw a tall box at the back for the cab 🟥', [
        _line(const [Offset(14, 32), Offset(14, 70), Offset(34, 70), Offset(34, 32)]),
        _round(11, 28, 37, 32, 1.2),
        _round(18, 37, 30, 47, 2),
      ]),
      GuideStep('Draw a long round body in front 🟦', [
        GuideShape(Path()
          ..moveTo(34, 48)
          ..lineTo(70, 48)
          ..quadraticBezierTo(76, 59, 70, 70)
          ..lineTo(34, 70)),
        _line(const [Offset(46, 48), Offset(46, 70)]),
        _line(const [Offset(58, 48), Offset(58, 70)]),
      ]),
      GuideStep('Add a chimney and a bump on top 🎩', [
        _line(const [Offset(61, 48), Offset(61, 39), Offset(57.5, 32), Offset(69.5, 32), Offset(66, 39), Offset(66, 48)]),
        _arc(51.5, 48, 4, math.pi, math.pi),
      ]),
      GuideStep('Add a light and a pointy front 🔦', [
        _round(70.5, 42, 76.5, 48, 1),
        _line(const [Offset(70, 70), Offset(80, 84), Offset(68.4, 84)]),
        _line(const [Offset(71.6, 72.3), Offset(70.4, 84)]),
        _line(const [Offset(74.8, 76.8), Offset(74.2, 84)]),
      ]),
      GuideStep('Draw two big wheels and a small one ⭕', [
        _circle(24, 78, 8),
        _circle(44, 78, 8),
        _circle(62, 80, 5.4),
        _line(const [Offset(62, 70), Offset(62, 74.6)]),
      ]),
      GuideStep('Join the big wheels with a bar 🔩', [
        _line(const [Offset(24, 78), Offset(44, 78)]),
        _dot(24, 78, 1.6),
        _dot(44, 78, 1.6),
        _dot(62, 80, 1.3),
      ]),
      GuideStep('Draw puffs of smoke 💨', [
        GuideShape([
          circlePath(65, 26, 4), circlePath(71, 20, 5), circlePath(79, 13, 6),
          circlePath(89, 9, 5),
        ].reduce((a, b) => Path.combine(PathOperation.union, a, b))),
      ]),
      GuideStep('Draw the track 🛤️', [
        _line(const [Offset(0, 86), Offset(100, 86)]),
        for (final x in [2.0, 14.0, 26.0, 38.0, 50.0, 62.0, 74.0, 86.0])
          _line([Offset(x, 86), Offset(x, 89), Offset(x + 6, 89), Offset(x + 6, 86)]),
      ]),
    ]);

DrawingGuide _rocket() {
  const pivot = Offset(50, 54);
  final m = Matrix4.translationValues(pivot.dx, pivot.dy, 0) *
      Matrix4.rotationZ(0.3) *
      Matrix4.translationValues(-pivot.dx, -pivot.dy, 0);
  List<GuideShape> tilt(List<GuideShape> shapes) => [
        for (final s in shapes) GuideShape(s.path.transform(m.storage), fill: s.fill),
      ];
  final planet = circlePath(80, 20, 8);
  return DrawingGuide('Rocket', '🚀', [
    GuideStep('Draw a tall rocket body with a pointy top 🚀', tilt([
      _smooth(const [
        Offset(50, 12), Offset(56, 20), Offset(59, 34), Offset(60, 50),
        Offset(59, 66), Offset(56, 74), Offset(44, 74), Offset(41, 66),
        Offset(40, 50), Offset(41, 34), Offset(44, 20),
      ], close: true),
    ])),
    GuideStep('Draw lines for the nose and a stripe ➖', tilt([
      _smooth(const [Offset(42.6, 27), Offset(50, 25.6), Offset(57.4, 27)]),
      _line(const [Offset(40.1, 49), Offset(59.9, 49)]),
      _line(const [Offset(40.2, 54), Offset(59.8, 54)]),
    ])),
    GuideStep('Add a round window ⭕', tilt([
      _circle(50, 37, 7.5),
      _circle(50, 37, 5),
      _arc(50, 37, 3.2, 3.6, 1.3),
    ])),
    GuideStep('Draw three fins 🔺', tilt([
      _smooth(const [Offset(40.6, 56), Offset(34, 64), Offset(31, 77), Offset(36, 76), Offset(42.2, 70)]),
      _smooth(const [Offset(59.4, 56), Offset(66, 64), Offset(69, 77), Offset(64, 76), Offset(57.8, 70)]),
      _oval(50, 66, 2.2, 7),
    ])),
    GuideStep('Add the engine and a big flame 🔥', tilt([
      _line(const [Offset(44.6, 73.6), Offset(42, 79), Offset(58, 79), Offset(55.4, 73.6)]),
      _smooth(const [Offset(43, 79), Offset(45, 86), Offset(50, 97), Offset(55, 86), Offset(57, 79)]),
      _smooth(const [Offset(46.5, 79), Offset(48, 85), Offset(50, 90), Offset(52, 85), Offset(53.5, 79)]),
    ])),
    GuideStep('Add little bolts ⚙️', tilt([
      for (final (x, y) in const [(45.0, 31.0), (55.0, 31.0), (44.0, 60.0), (56.0, 60.0)])
        _dot(x, y, 0.8),
    ])),
    GuideStep('Draw stars and a planet with a ring 🪐', [
      GuideShape(planet),
      ..._ellipseOutside(80, 20, 15, 4, -0.35,
          Path.combine(PathOperation.intersect, planet, rectPath(60, 0, 100, 20))),
      _star(14, 16, 4),
      _star(16, 80, 3.6),
      _star(86, 84, 4),
      _star(88, 52, 3),
      _dot(30, 40, 1),
      _dot(72, 92, 1),
    ]),
  ]);
}

DrawingGuide _octopus() {
  const arms = [
    [Offset(38.3, 57), Offset(31, 65), Offset(21, 71), Offset(13, 69), Offset(11, 63)],
    [Offset(43, 57), Offset(39, 70), Offset(31, 82), Offset(24, 86), Offset(21, 82)],
    [Offset(47.7, 57), Offset(45.5, 70), Offset(39, 83), Offset(35, 91), Offset(39, 93.5)],
  ];
  final left = [for (final a in arms) _tentacle(a, 4.6)];
  return DrawingGuide('Octopus', '🐙', [
    GuideStep('Draw a big round head 🐙', [
      _smooth(const [
        Offset(36, 57), Offset(28, 44), Offset(28, 28), Offset(38, 16),
        Offset(50, 12), Offset(62, 16), Offset(72, 28), Offset(72, 44),
        Offset(64, 57),
      ]),
    ]),
    GuideStep('Add two big eyes 👀', [
      _oval(41, 42, 4.4, 5),
      _oval(59, 42, 4.4, 5),
      GuideShape(roundRectPath(38.6, 41, 43.4, 43.6, 1.2), fill: true),
      GuideShape(roundRectPath(56.6, 41, 61.4, 43.6, 1.2), fill: true),
    ]),
    GuideStep('Add a smile and some spots 😊', [
      _arc(50, 49, 3.4, 0.4, math.pi - 0.8),
      _oval(40, 26, 2.4, 1.6),
      _oval(55, 21, 2, 1.4),
      _oval(63, 31, 2.2, 1.5),
    ]),
    GuideStep('Draw three curly arms on this side 🌀', left),
    GuideStep('Draw three more on the other side 🌀', [for (final a in left) _flip(a)]),
    GuideStep('Add little suckers on the arms ⚪', [
      for (final a in arms.take(2))
        for (final p in [a[1], a[2]]) ...[
          _circle(p.dx, p.dy, 0.9),
          _flip(_circle(p.dx, p.dy, 0.9)),
        ],
    ]),
    GuideStep('Add bubbles 🫧', [
      _circle(84, 22, 4),
      _circle(90, 12, 3),
      _circle(15, 24, 3.4),
      _circle(10, 34, 2.4),
    ]),
  ]);
}

DrawingGuide _butterfly() {
  final upperVeins = [
    _smooth(const [Offset(47, 42), Offset(36, 32), Offset(22, 20)]),
    _smooth(const [Offset(47.6, 44), Offset(30, 38), Offset(14, 28)]),
  ];
  final lowerVeins = [
    _smooth(const [Offset(48, 52), Offset(34, 58), Offset(22, 66)]),
    _smooth(const [Offset(47.8, 56), Offset(36, 66), Offset(28, 76)]),
  ];
  return DrawingGuide('Butterfly', '🦋', [
    GuideStep('Draw the body: a head, a short oval and a long one 🐛', [
      _circle(50, 33.5, 3),
      _oval(50, 41.5, 3.2, 5),
      _oval(50, 59.5, 2.6, 13),
      for (final y in [52.0, 56.0, 60.0, 64.0, 68.0])
        _line([Offset(47.8, y), Offset(52.2, y)]),
    ]),
    GuideStep('Add two curly feelers 〰️', [
      _smooth(const [Offset(48.6, 30.8), Offset(46, 24), Offset(42.6, 19)]),
      _circle(41.6, 17.8, 1.6),
      _smooth(const [Offset(51.4, 30.8), Offset(54, 24), Offset(57.4, 19)]),
      _circle(58.4, 17.8, 1.6),
    ]),
    GuideStep('Draw two big wings on top 🦋', [
      for (final s in [
        _smooth(const [
          Offset(47.7, 38), Offset(40, 24), Offset(28, 14), Offset(14, 12),
          Offset(8, 18), Offset(10, 30), Offset(18, 42), Offset(32, 48),
          Offset(48.4, 46.4),
        ]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Draw two smaller wings below', [
      for (final s in [
        _smooth(const [
          Offset(48.5, 49), Offset(36, 50.5), Offset(22, 56), Offset(16, 66),
          Offset(20, 76), Offset(30, 80), Offset(40, 74), Offset(47.6, 64),
        ]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Draw lines on the wings 〰️', [
      for (final s in [...upperVeins, ...lowerVeins]) ...[s, _flip(s)],
    ]),
    GuideStep('Add big spots on each wing 🔵', [
      for (final s in [
        _oval(28, 28, 6, 3.6, angle: 0.6),
        _oval(32, 64, 4.6, 3.6, angle: -0.4),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Add little dots near the edges ⚪', [
      for (final (x, y) in const [
        (14.0, 17.0), (12.0, 24.0), (15.0, 32.0), (21.0, 16.0),
        (21.0, 68.0), (25.0, 75.0), (32.0, 77.0),
      ]) ...[_circle(x, y, 1.8), _flip(_circle(x, y, 1.8))],
    ]),
  ]);
}

DrawingGuide _bird() => DrawingGuide('Bird', '🐦', [
      GuideStep('Draw a round head and a plump body 🐦', [
        GuideShape(Path.combine(
          PathOperation.union,
          circlePath(62, 34, 11),
          smoothPath(const [
            Offset(40, 44), Offset(52, 40), Offset(64, 44), Offset(70, 56),
            Offset(64, 68), Offset(50, 72), Offset(36, 68), Offset(28, 58),
            Offset(30, 48),
          ], close: true),
        )),
      ]),
      GuideStep('Add a pointy beak 🔺', [
        _line(const [Offset(72.6, 31), Offset(82, 34.5), Offset(72.6, 37)]),
        _line(const [Offset(73, 34.2), Offset(79, 34.5)]),
      ]),
      GuideStep('Add a shiny eye 👁️', [
        _circle(66, 31, 2.6),
        _dot(66.6, 31, 1.4),
      ]),
      GuideStep('Draw a wing with feathers 🪶', [
        _smooth(const [
          Offset(40, 52), Offset(52, 48), Offset(62, 53), Offset(60, 61),
          Offset(50, 65), Offset(40, 61),
        ], close: true),
        _smooth(const [Offset(43, 59), Offset(50, 61), Offset(57, 58)]),
        _smooth(const [Offset(45, 55), Offset(51, 56.5), Offset(57, 54)]),
      ]),
      GuideStep('Add long tail feathers 🪶', [
        _smooth(const [Offset(29.6, 54), Offset(18, 60), Offset(9, 68), Offset(13, 71), Offset(33, 65)]),
        _line(const [Offset(30, 60), Offset(13, 68.5)]),
      ]),
      GuideStep('Draw a branch to sit on 🌿', [
        _smooth(const [Offset(2, 80), Offset(40, 79), Offset(70, 81), Offset(98, 79)]),
        _smooth(const [Offset(2, 85), Offset(40, 84), Offset(70, 86), Offset(98, 84)]),
      ]),
      GuideStep('Add two legs holding the branch 🦶', [
        _line(const [Offset(47, 71.5), Offset(46, 79.3)]),
        _line(const [Offset(56, 70.8), Offset(56, 79.6)]),
        _arc(46, 81.5, 2.2, 3.4, 2.6),
        _arc(56, 81.7, 2.2, 3.4, 2.6),
      ]),
      GuideStep('Add some leaves 🍃', [
        _leaf(const Offset(86, 79.5), const Offset(94, 70), 5),
        _leaf(const Offset(16, 84.8), const Offset(8, 94), 5),
        _leaf(const Offset(74, 85.6), const Offset(80, 95), 4.4),
      ]),
    ]);

DrawingGuide _turtle() {
  const cx = 48.0, cy = 51.0, rx = 22.0, ry = 17.0;
  Offset rim(double a) => _on(cx, cy, rx, ry, a);
  double innerY(double x, double sign) =>
      cy + sign * 14.5 * math.sqrt(1 - math.pow((x - cx) / 19, 2));
  Path hex(double hx) => polyPath([
        for (int i = 0; i < 6; i++) _on(hx, cy, 5.5, 5.5, i * math.pi / 3),
      ]);
  final front = _smooth([rim(-1.15), const Offset(54, 26), const Offset(48, 14), const Offset(53, 15), const Offset(61, 26), rim(-0.75)]);
  final back = _smooth([rim(math.pi + 0.5), const Offset(22, 36), const Offset(18, 30), const Offset(24, 30), rim(math.pi + 0.85)]);
  GuideShape flipY(GuideShape s) => GuideShape(s.path.transform(
      (Matrix4.translationValues(0, 2 * cy, 0) * Matrix4.diagonal3Values(1, -1, 1)).storage));
  return DrawingGuide('Turtle', '🐢', [
    GuideStep('Draw a big oval for the shell 🥚', [_oval(cx, cy, rx, ry)]),
    GuideStep('Draw a smaller oval inside it 🥚', [_oval(cx, cy, 19, 14.5)]),
    GuideStep('Draw three shapes with six sides 🔷', [
      for (final hx in [37.0, 48.0, 59.0]) GuideShape(hex(hx)),
      for (final x in [34.25, 45.25, 50.75, 61.75]) ...[
        _line([Offset(x, cy - 4.76), Offset(x, innerY(x, -1))]),
        _line([Offset(x, cy + 4.76), Offset(x, innerY(x, 1))]),
      ],
      _line(const [Offset(31.5, cy), Offset(29, cy)]),
      _line(const [Offset(64.5, cy), Offset(67, cy)]),
    ]),
    GuideStep('Add little lines around the edge ➖', [
      for (int i = 0; i < 16; i++)
        _line([
          _on(cx, cy, 19, 14.5, i * math.pi / 8 + math.pi / 16),
          _on(cx, cy, rx, ry, i * math.pi / 8 + math.pi / 16),
        ]),
    ]),
    GuideStep('Draw the head with two eyes 🐢', [
      _smooth([rim(-0.28), const Offset(74, 44), const Offset(80, 46), const Offset(83, 51), const Offset(80, 56), const Offset(74, 58), rim(0.28)]),
      _dot(77.5, 47.6, 1.2),
      _dot(77.5, 54.4, 1.2),
    ]),
    GuideStep('Draw two big front flippers 🌊', [front, flipY(front)]),
    GuideStep('Add back flippers and a little tail 🦶', [
      back,
      flipY(back),
      _line([rim(math.pi - 0.1), const Offset(19, cy), rim(math.pi + 0.1)]),
    ]),
    GuideStep('Add bubbles 🫧', [
      _circle(88, 40, 2.6),
      _circle(92, 31, 2),
      _circle(88, 22, 3),
    ]),
  ]);
}

DrawingGuide _cat() => DrawingGuide('Cat', '🐱', [
      GuideStep('Draw a round head with chubby cheeks ⭕', [
        _smooth(const [
          Offset(50, 21), Offset(60, 23), Offset(68, 30), Offset(70, 38),
          Offset(66, 46), Offset(58, 51), Offset(50, 52), Offset(42, 51),
          Offset(34, 46), Offset(30, 38), Offset(32, 30), Offset(40, 23),
        ], close: true),
      ]),
      GuideStep('Draw two pointy ears 🔺🔺', [
        for (final s in [
          _line(const [Offset(32.4, 29.6), Offset(29, 10), Offset(44.5, 22.2)]),
          _line(const [Offset(33.6, 25.6), Offset(31.5, 15), Offset(40.6, 22.8)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add two eyes like lemons 🍋', [
        for (final s in [
          _smooth(const [Offset(36, 33), Offset(41, 29.5), Offset(46, 33), Offset(41, 36.5)], close: true),
          GuideShape(ellipsePath(41, 33, 1.3, 2.8), fill: true),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add a nose, a mouth and whiskers 〰️', [
        _line(const [Offset(47, 39), Offset(53, 39), Offset(50, 42.5)], close: true),
        _smooth(const [Offset(50, 42.5), Offset(50, 45), Offset(46.5, 47)]),
        _smooth(const [Offset(50, 45), Offset(53.5, 47)]),
        for (final s in [
          _smooth(const [Offset(44, 43), Offset(34, 41), Offset(22, 40)]),
          _smooth(const [Offset(44, 44.6), Offset(33, 45), Offset(22, 46.5)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Draw the body under the head 🐈', [
        _smooth(const [Offset(39.5, 50.4), Offset(33, 58), Offset(30, 70), Offset(31, 82), Offset(36, 88)]),
        _smooth(const [Offset(60.5, 50.4), Offset(67, 58), Offset(70, 70), Offset(69, 82), Offset(64, 88)]),
        _line(const [Offset(36, 88), Offset(40.9, 88)]),
        _line(const [Offset(59.1, 88), Offset(64, 88)]),
      ]),
      GuideStep('Draw front legs and round paws 🐾', [
        for (final s in [
          _line(const [Offset(41.5, 62), Offset(41.5, 85.4)]),
          _line(const [Offset(48.5, 62), Offset(48.5, 85.4)]),
          _oval(45, 87, 4.4, 2.8),
          _line(const [Offset(44, 85.6), Offset(44, 88.2)]),
          _line(const [Offset(46, 85.6), Offset(46, 88.2)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add a long curly tail 🌀', [
        _smooth(const [
          Offset(69.4, 81), Offset(77, 80), Offset(82, 71), Offset(82, 61),
          Offset(78, 56), Offset(75, 58), Offset(77, 64), Offset(76, 72),
          Offset(70, 75.6),
        ]),
      ]),
      GuideStep('Add stripes on the head 🐯', [
        _line(const [Offset(50, 23), Offset(50, 28)]),
        _line(const [Offset(46, 24), Offset(47, 28)]),
        _line(const [Offset(54, 24), Offset(53, 28)]),
        _smooth(const [Offset(31, 36), Offset(34, 37), Offset(36, 40)]),
        _flip(_smooth(const [Offset(31, 36), Offset(34, 37), Offset(36, 40)])),
      ]),
    ]);

DrawingGuide _bunny() => DrawingGuide('Bunny', '🐰', [
      GuideStep('Draw an oval for the head 🥚', [_oval(50, 40, 15, 13)]),
      GuideStep('Draw two long ears 🐰', [
        for (final s in [
          _smooth(const [Offset(41.2, 29.5), Offset(37, 18), Offset(36, 6), Offset(40.5, 2), Offset(45, 9), Offset(46.6, 27.3)]),
          _smooth(const [Offset(42.4, 26), Offset(39.6, 16), Offset(40.4, 7.4), Offset(42.8, 10), Offset(44.4, 25.6)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add two eyes and a little nose 👀', [
        _dot(44, 38, 2.4),
        _dot(56, 38, 2.4),
        _line(const [Offset(48, 45), Offset(52, 45), Offset(50, 47.5)], close: true),
      ]),
      GuideStep('Add a smile, teeth and whiskers 😁', [
        _smooth(const [Offset(50, 47.5), Offset(47.5, 49.5), Offset(45, 48.5)]),
        _smooth(const [Offset(50, 47.5), Offset(52.5, 49.5), Offset(55, 48.5)]),
        _rect(48.2, 49.4, 51.8, 52.4),
        _line(const [Offset(50, 49.4), Offset(50, 52.4)]),
        for (final s in [
          _line(const [Offset(42, 45), Offset(26, 42)]),
          _line(const [Offset(42, 47), Offset(26, 49)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Draw a round body and big feet 🦶', [
        _smooth(const [Offset(40, 49.7), Offset(32, 60), Offset(29, 74), Offset(30, 84), Offset(33, 88.5)]),
        _smooth(const [Offset(60, 49.7), Offset(68, 60), Offset(71, 74), Offset(70, 84), Offset(67, 88.5)]),
        _line(const [Offset(41, 92), Offset(59, 92)]),
        _oval(33, 92, 8, 3.5),
        _oval(67, 92, 8, 3.5),
      ]),
      GuideStep('Add little front paws 🐾', [
        for (final s in [
          _smooth(const [Offset(39, 60), Offset(41, 71), Offset(42.4, 82)]),
          _oval(45, 84, 3.4, 2.4),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add grass and a crunchy carrot 🥕', [
        ..._tufts(const [Offset(8, 96), Offset(20, 98), Offset(90, 97)]),
        _line(const [Offset(76, 96), Offset(94, 92.5), Offset(77, 91)], close: true),
        _line(const [Offset(80, 95.2), Offset(81, 93)]),
        _line(const [Offset(85, 94.2), Offset(84.4, 92)]),
        _line(const [Offset(94, 92.5), Offset(98, 89)]),
        _line(const [Offset(94, 92.5), Offset(99, 93)]),
      ]),
    ]);

DrawingGuide _dog() => DrawingGuide('Dog', '🐶', [
      GuideStep('Draw a round head 🐶', [
        _smooth(const [
          Offset(50, 18), Offset(62, 21), Offset(68, 30), Offset(68, 42),
          Offset(62, 52), Offset(50, 56), Offset(38, 52), Offset(32, 42),
          Offset(32, 30), Offset(38, 21),
        ], close: true),
      ]),
      GuideStep('Draw two floppy ears 👂', [
        for (final s in [
          _smooth(const [Offset(35.4, 24.4), Offset(26, 24), Offset(20, 34), Offset(20, 50), Offset(24, 56), Offset(29, 52), Offset(32, 41)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add eyes, eyebrows and a spot 👀', [
        _dot(43, 35, 2.6),
        _dot(57, 35, 2.6),
        _arc(43, 35, 5, 3.7, 1.4),
        _arc(57, 35, 5, 4.3, 1.4),
        _smooth(const [Offset(53, 29), Offset(61, 28), Offset(64, 35), Offset(60, 40.5), Offset(53, 39)], close: true),
      ]),
      GuideStep('Draw a snout and a big nose 👃', [
        _oval(50, 48, 9, 6.5),
        _smooth(const [Offset(46.5, 43), Offset(53.5, 43), Offset(50, 46.6)], close: true),
      ]),
      GuideStep('Add a smiling mouth and a tongue 👅', [
        _line(const [Offset(50, 46.6), Offset(50, 49)]),
        _smooth(const [Offset(50, 49), Offset(46, 50.5), Offset(43, 49)]),
        _smooth(const [Offset(50, 49), Offset(54, 50.5), Offset(57, 49)]),
        _smooth(const [Offset(47.6, 50.4), Offset(47.8, 53), Offset(50, 54), Offset(52.2, 53), Offset(52.4, 50.4)]),
      ]),
      GuideStep('Draw the body, legs and paws 🐾', [
        _smooth(const [Offset(39, 52.6), Offset(33, 62), Offset(31, 76), Offset(32, 90)]),
        _smooth(const [Offset(61, 52.6), Offset(67, 62), Offset(69, 76), Offset(68, 90)]),
        _line(const [Offset(32, 90), Offset(37, 90)]),
        _line(const [Offset(47, 90), Offset(53, 90)]),
        _line(const [Offset(63, 90), Offset(68, 90)]),
        for (final s in [
          _line(const [Offset(38, 66), Offset(38, 88.4)]),
          _line(const [Offset(46, 66), Offset(46, 88.4)]),
          _oval(42, 90, 5, 2.6),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add a collar with a tag 🏷️', [
        _smooth(const [Offset(38, 55.6), Offset(50, 60), Offset(62, 55.6)]),
        _smooth(const [Offset(36.6, 58.6), Offset(50, 63), Offset(63.4, 58.6)]),
        _circle(50, 65.5, 2.5),
      ]),
      GuideStep('Add a wagging tail 🐕', [
        _smooth(const [Offset(68.8, 80), Offset(78, 75), Offset(84, 64), Offset(81, 62), Offset(76, 70), Offset(68.6, 74)]),
        _arc(84, 70, 6, -0.5, 1),
        _arc(84, 70, 9, -0.5, 1),
      ]),
    ]);

DrawingGuide _penguin() => DrawingGuide('Penguin', '🐧', [
      GuideStep('Draw a tall egg shape for the body 🥚', [
        _smooth(const [
          Offset(50, 12), Offset(62, 16), Offset(68, 30), Offset(72, 50),
          Offset(70, 70), Offset(62, 84), Offset(50, 88), Offset(38, 84),
          Offset(30, 70), Offset(28, 50), Offset(32, 30), Offset(38, 16),
        ], close: true),
      ]),
      GuideStep('Draw a heart shaped face 🤍', [
        _smooth(const [
          Offset(50, 22), Offset(57, 19.5), Offset(61, 26), Offset(58, 34),
          Offset(50, 38), Offset(42, 34), Offset(39, 26), Offset(43, 19.5),
        ], close: true),
      ]),
      GuideStep('Draw a big round tummy ⚪', [
        _smooth(const [
          Offset(50, 40.5), Offset(60, 46), Offset(63, 62), Offset(58, 78),
          Offset(50, 82), Offset(42, 78), Offset(37, 62), Offset(40, 46),
        ], close: true),
      ]),
      GuideStep('Add two eyes and a beak 🔻', [
        _dot(45, 27, 1.8),
        _dot(55, 27, 1.8),
        _line(const [Offset(47.5, 31), Offset(52.5, 31), Offset(50, 36)], close: true),
      ]),
      GuideStep('Draw two flippers 🪽', [
        for (final s in [
          _smooth(const [Offset(29.4, 40), Offset(22, 50), Offset(16, 64), Offset(20, 66), Offset(28.6, 60)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Add two orange feet 🦶', [
        for (final s in [
          _line(const [Offset(40.6, 85.4), Offset(36, 91), Offset(41, 92), Offset(44, 90), Offset(47, 92), Offset(48, 87.7)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Draw the ice and snowflakes ❄️', [
        _line(const [Offset(4, 92), Offset(36, 92)]),
        _line(const [Offset(64, 92), Offset(96, 92)]),
        for (final (x, y) in const [(12.0, 18.0), (86.0, 26.0), (14.0, 60.0), (88.0, 66.0)]) ...[
          _line([Offset(x - 2, y), Offset(x + 2, y)]),
          _line([Offset(x - 1, y - 1.7), Offset(x + 1, y + 1.7)]),
          _line([Offset(x - 1, y + 1.7), Offset(x + 1, y - 1.7)]),
        ],
      ]),
    ]);

DrawingGuide _giraffe() => DrawingGuide('Giraffe', '🦒', [
      GuideStep('Draw a big body 🦒', [
        _smooth(const [
          Offset(30, 56), Offset(44, 52), Offset(62, 52), Offset(74, 56),
          Offset(76, 66), Offset(70, 72), Offset(52, 73), Offset(34, 72),
          Offset(26, 66),
        ], close: true),
      ]),
      GuideStep('Draw a long, long neck ⬆️', [
        _smooth(const [Offset(72.6, 55.2), Offset(76, 40), Offset(78.4, 25.6)]),
        _smooth(const [Offset(64, 52.6), Offset(68, 38), Offset(70.4, 26.6)]),
      ]),
      GuideStep('Draw the head with a long nose 🐴', [
        _smooth(const [
          Offset(68, 22), Offset(72, 15), Offset(80, 13), Offset(90, 16),
          Offset(94, 21), Offset(91, 25), Offset(82, 26), Offset(74, 27),
        ], close: true),
      ]),
      GuideStep('Add two little horns and an ear 👂', [
        _line(const [Offset(74, 14.4), Offset(73, 8.4)]),
        _circle(72.8, 7, 1.4),
        _line(const [Offset(78, 13.4), Offset(78, 8)]),
        _circle(78, 6.6, 1.4),
        _leaf(const Offset(70.6, 16.6), const Offset(63, 13), 3.4),
      ]),
      GuideStep('Add an eye, a nose and a smile 😊', [
        _dot(82, 18, 1.4),
        _dot(91, 19.6, 0.7),
        _smooth(const [Offset(87, 23.4), Offset(90, 24), Offset(93, 23)]),
      ]),
      GuideStep('Draw four long legs with hooves 🦵', [
        for (final x in [32.0, 40.0, 62.0, 69.0]) ...[
          _line([Offset(x, x < 50 ? 71.6 : 72.4), Offset(x, 92)]),
          _line([Offset(x + 3.4, x < 50 ? 72.2 : 72.6), Offset(x + 3.4, 92)]),
          _rect(x - 0.4, 92, x + 3.8, 95),
        ],
      ]),
      GuideStep('Add a tail and a mane on the neck 〰️', [
        _line(const [Offset(26.6, 61), Offset(18, 74)]),
        _leaf(const Offset(18, 74), const Offset(15, 81), 3),
        _line(const [Offset(70, 28), Offset(67.6, 31), Offset(69.2, 34), Offset(66.6, 37.4), Offset(68, 41), Offset(65.4, 44.6), Offset(66.8, 48), Offset(64.6, 51)]),
      ]),
      GuideStep('Add patches all over 🟫', [
        for (final (x, y) in const [
          (36.0, 61.0), (46.0, 58.0), (56.0, 61.0), (66.0, 60.0), (44.0, 67.0),
          (58.0, 67.5), (32.0, 67.0), (73.0, 45.0), (75.0, 34.0),
        ])
          _smooth([
            Offset(x - 2.6, y - 1), Offset(x, y - 2.4), Offset(x + 2.6, y - 0.8),
            Offset(x + 2, y + 2), Offset(x - 1.4, y + 2.2),
          ], close: true),
      ]),
    ]);

DrawingGuide _snowman() => DrawingGuide('Snowman', '⛄', [
      GuideStep('Draw a big circle at the bottom ⭕', [_circle(50, 76, 16)]),
      GuideStep('Draw a smaller circle on top of it ⭕', [_circle(50, 48, 12)]),
      GuideStep('Draw a small head and a tall hat 🎩', [
        _arc(50, 27, 9, -0.891, math.pi + 1.782),
        _rect(39, 17.5, 61, 20),
        _line(const [Offset(43, 17.5), Offset(43, 4), Offset(57, 4), Offset(57, 17.5)]),
        _line(const [Offset(43, 14), Offset(57, 14)]),
      ]),
      GuideStep('Add eyes, a carrot nose and a smile 🥕', [
        _dot(46.5, 25, 1.6),
        _dot(53.5, 25, 1.6),
        _line(const [Offset(50, 27.5), Offset(62, 30), Offset(50, 31.5)], close: true),
        _line(const [Offset(54, 28.6), Offset(54.3, 30.6)]),
        _line(const [Offset(58, 29.3), Offset(58.2, 30.6)]),
        for (final (x, y) in const [(45.5, 32.4), (47.6, 33.6), (50.0, 34.0), (52.4, 33.6), (54.5, 32.4)])
          _dot(x, y, 0.7),
      ]),
      GuideStep('Add round buttons ⚫', [
        for (final y in const [42.0, 48.0, 54.0, 70.0, 80.0]) _dot(50, y, 1.8),
      ]),
      GuideStep('Draw two stick arms 🌿', [
        for (final s in [
          _line(const [Offset(38.7, 43.9), Offset(22, 34)]),
          _line(const [Offset(22, 34), Offset(18, 29.6)]),
          _line(const [Offset(22, 34), Offset(16.6, 34.6)]),
          _line(const [Offset(29, 38.2), Offset(27.6, 33.4)]),
        ]) ...[s, _flip(s)],
      ]),
      GuideStep('Draw the snowy ground and snowflakes ❄️', [
        _line(const [Offset(4, 92), Offset(96, 92)]),
        for (final (x, y) in const [(12.0, 14.0), (84.0, 10.0), (14.0, 60.0), (88.0, 56.0), (24.0, 84.0), (80.0, 82.0)]) ...[
          _line([Offset(x - 2, y), Offset(x + 2, y)]),
          _line([Offset(x - 1, y - 1.7), Offset(x + 1, y + 1.7)]),
          _line([Offset(x - 1, y + 1.7), Offset(x + 1, y - 1.7)]),
        ],
      ]),
    ]);

DrawingGuide _lv(int level, DrawingGuide g) =>
    DrawingGuide(g.name, g.emoji, g.steps, level: level);

/// Grouped by level (1 easy, 2 medium, 3 harder); easiest first inside each.
final List<DrawingGuide> drawingGuides = [
  // Easy
  _lv(1, _sun()),
  _lv(1, _apple()),
  _lv(1, _moon()),
  _lv(1, _house()),
  _lv(1, _tree()),
  _lv(1, _mushroom()),
  _lv(1, _robot()),
  _lv(1, _sailboat()),
  // Medium
  _lv(2, _fish()),
  _lv(2, _flower()),
  _lv(2, _iceCream()),
  _lv(2, _car()),
  _lv(2, _train()),
  _lv(2, _rocket()),
  _lv(2, _octopus()),
  // Harder
  _lv(3, _butterfly()),
  _lv(3, _bird()),
  _lv(3, _turtle()),
  _lv(3, _cat()),
  _lv(3, _bunny()),
  _lv(3, _dog()),
  _lv(3, _penguin()),
  _lv(3, _giraffe()),
  _lv(3, _snowman()),
];
