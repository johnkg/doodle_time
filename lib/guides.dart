import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shapes.dart';

/// How a lesson shape is drawn in the reference picture.
enum GuideKind {
  /// A pencil outline: the real drawing.
  line,

  /// A small solid shape (eyes, buttons, nose).
  dot,

  /// A white highlight on top of a dot (the shine in an eye).
  shine,

  /// A light helper line (circle, cross) that is rubbed out in the last step.
  guide,

  /// Thin pencil strokes for fur and shadows.
  shade,
}

/// One shape of a "how to draw" lesson, in a 100 x 100 design space.
class GuideShape {
  GuideShape(this.path,
      {bool fill = false, GuideKind? kind, this.tone, this.toneDepth = 1})
      : kind = kind ?? (fill ? GuideKind.dot : GuideKind.line);
  final Path path;
  final GuideKind kind;

  /// For hatching: the area it covers. The painter lays soft graphite tone
  /// under the strokes so shading reads as a gradient, not just lines.
  final Path? tone;

  /// How dark the tone is (cross-hatching is darker).
  final double toneDepth;

  bool get fill => kind == GuideKind.dot || kind == GuideKind.shine;

  /// The same shape moved or scaled by [m] (a column-major 4x4 matrix).
  GuideShape transformed(Matrix4 m) => GuideShape(path.transform(m.storage),
      kind: kind, tone: tone?.transform(m.storage), toneDepth: toneDepth);
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

GuideShape _oval(double cx, double cy, double rx, double ry,
        {double angle = 0}) =>
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
        Offset(x - s / 2, y),
        Offset(x, y + s / 2),
        Offset(x + s / 2, y),
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

// ---- sketch helpers ---------------------------------------------------------
// Lessons are built like a pencil sketch: light helper shapes first (circles,
// a cross), then the outline on top of them, then the details, and in the last
// step the helpers are rubbed out and fur and shadows are added.

GuideShape _helpCircle(double cx, double cy, double r) =>
    GuideShape(circlePath(cx, cy, r), kind: GuideKind.guide);

GuideShape _helpOval(double cx, double cy, double rx, double ry,
        {double angle = 0}) =>
    GuideShape(ellipsePath(cx, cy, rx, ry, angle: angle),
        kind: GuideKind.guide);

/// Helper line or curve through [pts].
GuideShape _helpLine(List<Offset> pts) =>
    GuideShape(smoothPath(pts), kind: GuideKind.guide);

GuideShape _shine(double cx, double cy, double r) =>
    GuideShape(circlePath(cx, cy, r), kind: GuideKind.shine);

/// A lifelike eye: shaded iris with a ring around it, a dark pupil, and a
/// bright highlight (plus a small second one) so it looks wet and alive.
List<GuideShape> _eye(double cx, double cy, double r) => [
      _circle(cx, cy, r),
      _hatch(_minus(circlePath(cx, cy, r), circlePath(cx, cy, r * 0.5)),
          angle: 0.9, gap: math.max(0.3, r * 0.22), seed: 5),
      _dot(cx, cy, r * 0.52),
      _shine(cx + r * 0.3, cy - r * 0.3, r * 0.26),
      _shine(cx - r * 0.3, cy + r * 0.38, r * 0.1),
    ];

/// One thin pencil stroke (fur, a crease, a blush mark).
GuideShape _fine(List<Offset> pts) =>
    GuideShape(smoothPath(pts), kind: GuideKind.shade);

/// Rosy cheek: three short slanted strokes around (cx, cy).
GuideShape _blush(double cx, double cy) {
  final p = Path();
  for (int i = -1; i <= 1; i++) {
    p
      ..moveTo(cx + i * 1.3 - 0.5, cy + 0.9)
      ..lineTo(cx + i * 1.3 + 0.5, cy - 0.9);
  }
  return GuideShape(p, kind: GuideKind.shade);
}

/// Pencil shading: parallel strokes at [angle], [gap] apart, inside [area].
/// The stroke ends are a little ragged, like a real pencil. [cross] adds a
/// second layer of strokes across the first for a darker tone.
GuideShape _hatch(Path area,
    {double angle = 1.0, double gap = 1.3, int seed = 1, bool cross = false}) {
  final out = _hatchPath(area, angle, gap, seed);
  if (cross) {
    out.addPath(
        _hatchPath(area, angle + 0.9, gap * 1.3, seed + 7), Offset.zero);
  }
  return GuideShape(out,
      kind: GuideKind.shade, tone: area, toneDepth: cross ? 1.8 : 1);
}

Path _hatchPath(Path area, double angle, double gap, int seed) {
  final b = area.getBounds();
  final c = b.center;
  final d = Offset(math.cos(angle), math.sin(angle));
  final n = Offset(-d.dy, d.dx);
  final reach = (b.width + b.height) / 2 + 1;
  final rnd = math.Random(seed);
  final out = Path();
  const dt = 0.3;
  for (double k = -reach; k <= reach; k += gap) {
    Offset? start, prev;
    for (double t = -reach; t <= reach + dt; t += dt) {
      final p = c + n * k + d * t;
      final inside = t <= reach && area.contains(p);
      if (inside) {
        start ??= p;
        prev = p;
      } else if (start != null) {
        final a = start + d * (0.2 + rnd.nextDouble() * 0.7);
        final e = prev! - d * (0.2 + rnd.nextDouble() * 0.7);
        if ((e - a).distance > 0.5 &&
            (e - start).distance > (a - start).distance) {
          out
            ..moveTo(a.dx, a.dy)
            ..lineTo(e.dx, e.dy);
        }
        start = null;
      }
    }
  }
  return out;
}

/// Short fur strokes scattered inside [area], leaning along [angle], or
/// pointing away from [from] when it is given (a lion's mane).
GuideShape _furStrokes(Path area, int count,
    {double len = 2.4,
    double angle = math.pi / 2,
    Offset? from,
    int seed = 2}) {
  final b = area.getBounds();
  final rnd = math.Random(seed);
  final out = Path();
  int made = 0;
  for (int tries = 0; made < count && tries < count * 40; tries++) {
    final p = Offset(b.left + rnd.nextDouble() * b.width,
        b.top + rnd.nextDouble() * b.height);
    final base = from == null ? angle : (p - from).direction;
    final a = base + (rnd.nextDouble() - 0.5) * 0.6;
    final l = len * (0.6 + rnd.nextDouble() * 0.6);
    final e = p + Offset(math.cos(a), math.sin(a)) * l;
    final m = (p + e) / 2 + Offset(-math.sin(a), math.cos(a)) * l * 0.12;
    if (!area.contains(p) || !area.contains(e)) continue;
    out
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(m.dx, m.dy, e.dx, e.dy);
    made++;
  }
  return GuideShape(out, kind: GuideKind.shade);
}

/// Fluffy outline: the smooth curve through [pts] with little pointed tufts
/// along it, [every] apart and [depth] long, pointing away from [inside].
GuideShape _fluffy(List<Offset> pts,
    {required Path inside,
    double every = 3.2,
    double depth = 1.6,
    bool close = false}) {
  final base = smoothPath(pts, close: close);
  final out = Path();
  for (final m in base.computeMetrics()) {
    final count = math.max(1, (m.length / every).round());
    final step = m.length / count;
    Offset at(double d) =>
        m.getTangentForOffset(d.clamp(0, m.length))!.position;
    Offset normal(double d) {
      final v = m.getTangentForOffset(d.clamp(0, m.length))!.vector;
      final n = Offset(-v.dy, v.dx);
      return inside.contains(at(d) + n * 0.6) ? -n : n;
    }

    final s = at(0);
    out.moveTo(s.dx, s.dy);
    for (int i = 0; i < count; i++) {
      final t0 = i * step;
      final tip = at(t0 + step * 0.9) + normal(t0 + step * 0.9) * depth;
      final c1 = at(t0 + step * 0.45) + normal(t0 + step * 0.45) * depth * 0.55;
      final end = at(t0 + step);
      final c2 = at(t0 + step * 0.95);
      out
        ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, end.dx, end.dy);
    }
    if (close) out.close();
  }
  return GuideShape(out);
}

/// Irregular, closely packed patches over [area] like a giraffe's coat: a
/// slightly jittered hex lattice (rows along [angle]) of rough polygons, each
/// a bit smaller than its cell so thin pale gaps stay between them. Patches
/// that would cross the edge of [area] are left out.
GuideShape _patchGrid(Path area,
    {double spacing = 10, double r = 4.4, double angle = 0, int seed = 1}) {
  final rnd = math.Random(seed);
  final b = area.getBounds();
  final c = b.center;
  final u = Offset(math.cos(angle), math.sin(angle));
  final v = Offset(-u.dy, u.dx);
  final reach = b.longestSide;
  final out = Path();
  final rows = (reach / (spacing * 0.866)).ceil();
  for (int j = -rows; j <= rows; j++) {
    for (int i = -rows; i <= rows; i++) {
      final off = (j.isOdd ? 0.5 : 0.0);
      final p = c +
          u *
              ((i + off) * spacing +
                  (rnd.nextDouble() - 0.5) * spacing * 0.14) +
          v * (j * spacing * 0.866 + (rnd.nextDouble() - 0.5) * spacing * 0.14);
      final size = r * (0.85 + rnd.nextDouble() * 0.3);
      final sides = 6 + rnd.nextInt(2);
      final pts = [
        for (int k = 0; k < sides; k++)
          p +
              Offset.fromDirection(
                k * 2 * math.pi / sides + rnd.nextDouble() * 0.5,
                size * (0.8 + rnd.nextDouble() * 0.3),
              ),
      ];
      final core = [p, for (final q in pts) p + (q - p) * 0.75];
      if (core.every(area.contains)) out.addPolygon(pts, true);
    }
  }
  return GuideShape(out);
}

/// Turns an outline-only lesson into a sketch lesson: helper lines first and
/// shading at the end. Each gets its own step when there is room (at most 8
/// steps); otherwise the helpers join the first step and the shading the last.
DrawingGuide _sketch(DrawingGuide g,
    {String helpText = '',
    required List<GuideShape> help,
    required List<GuideShape> shade}) {
  final first = g.steps.first;
  final steps = [
    if (g.steps.length < 8) ...[GuideStep(helpText, help), first] else
      GuideStep(first.text, [...help, ...first.shapes]),
    ...g.steps.skip(1),
  ];
  if (steps.length < 8) {
    steps.add(GuideStep('Rub out the helper lines and add shading ✏️', shade));
  } else {
    final last = steps.removeLast();
    steps.add(GuideStep(last.text, [...last.shapes, ...shade]));
  }
  return DrawingGuide(g.name, g.emoji, steps, level: g.level);
}

Path _minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);

Path _mirror(Path p) => p.transform(
    (Matrix4.translationValues(100, 0, 0) * Matrix4.diagonal3Values(-1, 1, 1))
        .storage);

// ---- lessons (easiest first) ---------------------------------------------------

DrawingGuide _sun() => _sketch(
      DrawingGuide('Sun', '☀️', [
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
      ]),
      helpText: 'Draw a big helper circle and a cross ⭕',
      help: [
        _helpCircle(50, 50, 33),
        _helpLine(const [Offset(17, 50), Offset(83, 50)]),
        _helpLine(const [Offset(50, 17), Offset(50, 83)]),
      ],
      shade: [
        _hatch(_minus(circlePath(50, 50, 16), circlePath(47.5, 47.5, 16)),
            angle: 1.1, gap: 1.1),
        _hatch(
            [
              for (int i = 0; i < 8; i++)
                polyPath([
                  _on(50, 50, 19, 19, i * math.pi / 4 - 0.17),
                  _on(50, 50, 33, 33, i * math.pi / 4),
                  _on(50, 50, 19, 19, i * math.pi / 4 + 0.17),
                ]),
            ].reduce((a, b) => Path.combine(PathOperation.union, a, b)),
            angle: 0.8,
            gap: 1.1,
            seed: 2),
      ],
    );

DrawingGuide _apple() => _sketch(
      DrawingGuide('Apple', '🍎', [
        GuideStep('Draw a round apple with a dip on top 🍎', [
          _smooth(const [
            Offset(50, 34),
            Offset(60, 28),
            Offset(72, 32),
            Offset(78, 46),
            Offset(76, 64),
            Offset(68, 78),
            Offset(58, 82),
            Offset(50, 79),
            Offset(42, 82),
            Offset(32, 78),
            Offset(24, 64),
            Offset(22, 46),
            Offset(28, 32),
            Offset(40, 28),
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
            (60.0, 44.0),
            (66.0, 54.0),
            (56.0, 62.0),
            (44.0, 66.0),
            (64.0, 68.0),
            (52.0, 50.0),
            (40.0, 56.0),
          ])
            _dot(x, y, 0.8),
        ]),
        GuideStep('Draw a shadow under the apple 🌑', [
          _smooth(const [Offset(28, 88), Offset(50, 91), Offset(72, 88)]),
        ]),
      ]),
      helpText: 'Draw a big helper circle and a line down the middle ⭕',
      help: [
        _helpCircle(50, 56, 27),
        _helpLine(const [Offset(50, 14), Offset(50, 86)]),
      ],
      shade: [
        for (final apple in [
          blobPath(const [
            Offset(50, 34),
            Offset(60, 28),
            Offset(72, 32),
            Offset(78, 46),
            Offset(76, 64),
            Offset(68, 78),
            Offset(58, 82),
            Offset(50, 79),
            Offset(42, 82),
            Offset(32, 78),
            Offset(24, 64),
            Offset(22, 46),
            Offset(28, 32),
            Offset(40, 28),
          ]),
        ])
          _hatch(_minus(apple, apple.shift(const Offset(-5, -4))),
              angle: 1.1, gap: 1.1),
        _hatch(_leaf(const Offset(52.4, 25), const Offset(70, 16), 6).path,
            angle: 1.3, gap: 1.4, seed: 2),
        _hatch(ellipsePath(50, 89.6, 21, 2.2), angle: 0.3, gap: 0.9, seed: 3),
      ],
    );

DrawingGuide _moon() => _sketch(
      DrawingGuide('Moon', '🌙', [
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
      ]),
      helpText: 'Draw two helper circles that overlap ⭕',
      help: [_helpCircle(50, 50, 30), _helpCircle(64, 42, 26)],
      shade: [
        for (final moon in [
          Path.combine(PathOperation.difference, circlePath(50, 50, 30),
              circlePath(64, 42, 26)),
        ])
          _hatch(_minus(moon, moon.shift(const Offset(-3.5, 2.5))),
              angle: 1.1, gap: 1.1),
        _hatch(
            Path.combine(
                PathOperation.intersect,
                Path.combine(PathOperation.union, circlePath(14, 88, 6),
                    circlePath(31, 88, 6)),
                rectPath(0, 90, 100, 100)),
            angle: 0.4,
            gap: 1.2,
            seed: 2),
      ],
    );

DrawingGuide _house() {
  final roof = polyPath(const [Offset(20, 48), Offset(50, 22), Offset(80, 48)]);
  final chimney = rectPath(59.5, 17, 67.5, 48);
  return _sketch(
    DrawingGuide('House', '🏠', [
      GuideStep('Draw the walls like a box with no lid ⬜', [
        _line(const [
          Offset(26, 48),
          Offset(26, 82),
          Offset(74, 82),
          Offset(74, 48)
        ]),
      ]),
      GuideStep('Draw a big triangle roof 🔺', [GuideShape(roof)]),
      GuideStep('Add a chimney with curly smoke 💨', [
        _line(const [
          Offset(60, 30.7),
          Offset(60, 20),
          Offset(67, 20),
          Offset(67, 36.7)
        ]),
        _rect(58.5, 17, 68.5, 20),
        _smooth(const [
          Offset(64, 15),
          Offset(66.5, 11),
          Offset(62.5, 7.5),
          Offset(66, 3)
        ]),
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
        ..._scallops(roof, const Rect.fromLTRB(20, 31, 80, 46), 4.4,
            avoid: chimney),
      ]),
      GuideStep('Add the ground, a path and some grass 🌱', [
        _line(const [Offset(4, 82), Offset(26, 82)]),
        _line(const [Offset(74, 82), Offset(96, 82)]),
        _line(const [Offset(45, 82), Offset(39, 97)]),
        _line(const [Offset(55, 82), Offset(61, 97)]),
        _oval(48, 86.5, 2.8, 1.5),
        _oval(52, 92, 3.4, 1.8),
        ..._tufts(const [
          Offset(12, 90),
          Offset(24, 94),
          Offset(78, 92),
          Offset(90, 88)
        ]),
      ]),
    ]),
    helpText: 'Draw a line down the middle and one for the ground ➖',
    help: [
      _helpLine(const [Offset(50, 12), Offset(50, 96)]),
      _helpLine(const [Offset(4, 82), Offset(96, 82)]),
    ],
    shade: [
      _hatch(_minus(roof, chimney), angle: 1.1, gap: 1.5),
      _hatch(rectPath(44.6, 68, 55.4, 81.6), angle: 0.9, gap: 1.1, seed: 2),
      _hatch(rectPath(70, 49, 74, 81.6), angle: 1.1, gap: 1.1, seed: 3),
      for (final x in [31.0, 59.0])
        _hatch(rectPath(x, 56, x + 10, 66), angle: -0.8, gap: 2.4, seed: 4),
      _hatch(rectPath(60, 20, 67, 36), angle: 1.1, gap: 1.2, seed: 5),
    ],
  );
}

DrawingGuide _tree() => _sketch(
      DrawingGuide('Tree', '🌳', [
        GuideStep('Draw a big bumpy cloud shape for the leaves 🌳', [
          GuideShape([
            circlePath(50, 32, 16),
            circlePath(34, 40, 13),
            circlePath(66, 40, 13),
            circlePath(40, 54, 11),
            circlePath(60, 54, 11),
            circlePath(50, 50, 13),
          ].reduce((a, b) => Path.combine(PathOperation.union, a, b))),
        ]),
        GuideStep('Draw the trunk getting wider at the bottom 🪵', [
          _smooth(const [
            Offset(45, 62),
            Offset(44, 74),
            Offset(42, 84),
            Offset(35, 90)
          ]),
          _smooth(const [
            Offset(55, 62),
            Offset(56, 74),
            Offset(58, 84),
            Offset(65, 90)
          ]),
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
          for (final (x, y) in const [
            (44.0, 30.0),
            (60.0, 34.0),
            (36.0, 50.0),
            (58.0, 54.0)
          ]) ...[
            _circle(x, y, 2.6),
            _line([Offset(x, y - 2.6), Offset(x + 0.8, y - 4.2)]),
          ],
        ]),
        GuideStep('Add grass and a flying bird 🐦', [
          ..._tufts(const [
            Offset(14, 90),
            Offset(26, 90),
            Offset(76, 90),
            Offset(88, 90)
          ]),
          ..._gull(84, 12),
        ]),
      ]),
      helpText: 'Draw a big helper circle and a line down the middle ⭕',
      help: [
        _helpCircle(50, 42, 22),
        _helpLine(const [Offset(50, 18), Offset(50, 90)]),
      ],
      shade: [
        for (final crown in [
          [
            circlePath(50, 32, 16),
            circlePath(34, 40, 13),
            circlePath(66, 40, 13),
            circlePath(40, 54, 11),
            circlePath(60, 54, 11),
            circlePath(50, 50, 13),
          ].reduce((a, b) => Path.combine(PathOperation.union, a, b)),
        ])
          _hatch(_minus(crown, crown.shift(const Offset(-4, -4))),
              angle: 1.1, gap: 1.1),
        for (final trunk in [
          blobPath(const [
            Offset(45, 62),
            Offset(44, 74),
            Offset(42, 84),
            Offset(35, 90),
            Offset(65, 90),
            Offset(58, 84),
            Offset(56, 74),
            Offset(55, 62),
          ]),
        ])
          _hatch(_minus(trunk, trunk.shift(const Offset(-3.5, 0))),
              angle: 1.2, gap: 1.1, seed: 2),
        _hatch(ellipsePath(50, 92.6, 24, 1.8), angle: 0.3, gap: 0.9, seed: 3),
      ],
    );

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

  return _sketch(
    DrawingGuide('Mushroom', '🍄', [
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
          _line([
            Offset(x, capY(x)),
            Offset(x + (x < 50 ? 1 : -1), gillY(x + (x < 50 ? 1 : -1)))
          ]),
      ]),
      GuideStep('Draw a thick stem with a round bottom 🟫', [
        _smooth([
          Offset(40, gillY(40)),
          const Offset(39, 70),
          const Offset(37, 84)
        ]),
        _smooth([
          Offset(60, gillY(60)),
          const Offset(61, 70),
          const Offset(63, 84)
        ]),
        _smooth(const [
          Offset(37, 84),
          Offset(34, 87),
          Offset(40, 90),
          Offset(60, 90),
          Offset(66, 87),
          Offset(63, 84),
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
        ..._tufts(const [
          Offset(12, 90),
          Offset(26, 90),
          Offset(68, 90),
          Offset(92, 90)
        ]),
      ]),
    ]),
    helpText: 'Draw a tall helper oval and a line down the middle 🥚',
    help: [
      _helpOval(50, 52, 36, 38),
      _helpLine(const [Offset(50, 10), Offset(50, 94)]),
    ],
    shade: [
      for (final cap in [
        Path()
          ..moveTo(14, 52)
          ..cubicTo(14, 24, 34, 14, 50, 14)
          ..cubicTo(66, 14, 86, 24, 86, 52)
          ..quadraticBezierTo(50, 44, 14, 52)
          ..close(),
      ])
        _hatch(_minus(cap, cap.shift(const Offset(-4, -3))),
            angle: 1.1, gap: 1.1),
      _hatch(
          Path()
            ..moveTo(16, 51.6)
            ..quadraticBezierTo(50, 44, 84, 51.6)
            ..quadraticBezierTo(50, 60, 16, 52.5)
            ..close(),
          angle: 0.5,
          gap: 0.9,
          seed: 2,
          cross: true),
      for (final stem in [
        blobPath(const [
          Offset(40, 56),
          Offset(39, 70),
          Offset(37, 84),
          Offset(40, 89.6),
          Offset(60, 89.6),
          Offset(63, 84),
          Offset(61, 70),
          Offset(60, 56),
        ]),
      ])
        _hatch(_minus(stem, stem.shift(const Offset(-3.5, 0))),
            angle: 1.2, gap: 1.1, seed: 3),
    ],
  );
}

DrawingGuide _robot() => _sketch(
      DrawingGuide('Robot', '🤖', [
        GuideStep('Draw a square head with round corners ⬜',
            [_round(32, 16, 68, 44, 4)]),
        GuideStep('Add two round eyes 👀', [
          _circle(42, 27, 5),
          _circle(58, 27, 5),
          _dot(42, 27, 2.2),
          _dot(58, 27, 2.2),
        ]),
        GuideStep('Draw a mouth with stripes 😬', [
          _rect(40, 35, 60, 40),
          for (final x in [44.0, 48.0, 52.0, 56.0])
            _line([Offset(x, 35), Offset(x, 40)]),
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
      ]),
      help: [
        _helpLine(const [Offset(50, 3), Offset(50, 98)]),
      ],
      shade: [
        _hatch(rectPath(62.5, 17, 67.5, 43.5), angle: 1.1, gap: 1.1),
        _hatch(rectPath(64.5, 49, 69.5, 79.5), angle: 1.1, gap: 1.1, seed: 2),
        _hatch(rectPath(40.6, 35.4, 59.4, 39.6), angle: 0.9, gap: 0.9, seed: 3),
        for (final x in [33.0, 51.0])
          _hatch(roundRectPath(x, 92, x + 16, 97, 2),
              angle: 1.1, gap: 1.1, seed: 4),
        for (final x in [18.0, 70.0])
          _hatch(rectPath(x, 55, x + 12, 58), angle: 1.1, gap: 1, seed: 5),
      ],
    );

DrawingGuide _sailboat() => _sketch(
      DrawingGuide('Sailboat', '⛵', [
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
          _line(const [
            Offset(54, 64),
            Offset(54, 58.5),
            Offset(68, 58.5),
            Offset(68, 64)
          ]),
          _circle(58, 61.3, 1.3),
          _circle(64, 61.3, 1.3),
        ]),
        GuideStep('Draw wavy water 🌊', [
          _smooth([
            for (int i = 0; i <= 10; i++) Offset(i * 10.0, i.isEven ? 84 : 81)
          ]),
          _smooth([
            for (int i = 0; i <= 8; i++)
              Offset(6 + i * 11.0, i.isEven ? 93 : 90)
          ]),
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
      ]),
      help: [
        _helpLine(const [Offset(50, 4), Offset(50, 82)]),
        _helpLine(const [Offset(4, 82), Offset(96, 82)]),
      ],
      shade: [
        _hatch(
            Path.combine(
                PathOperation.intersect,
                rectPath(0, 69.6, 100, 100),
                Path()
                  ..moveTo(16, 64)
                  ..lineTo(86, 64)
                  ..quadraticBezierTo(80, 77, 72, 80)
                  ..lineTo(32, 80)
                  ..quadraticBezierTo(22, 77, 16, 64)
                  ..close()),
            angle: 1.1,
            gap: 1.1,
            cross: true),
        for (final sail in [
          Path()
            ..moveTo(52, 15)
            ..quadraticBezierTo(66, 32, 76, 53)
            ..lineTo(52, 53)
            ..close(),
        ])
          _hatch(_minus(sail, sail.shift(const Offset(-4, 0))),
              angle: 1.2, gap: 1.1, seed: 2),
      ],
    );

DrawingGuide _fish() {
  final body = smoothPath(const [
    Offset(81, 52),
    Offset(76, 43),
    Offset(64, 36),
    Offset(48, 36),
    Offset(34, 42),
    Offset(25, 49),
    Offset(25, 55),
    Offset(34, 61),
    Offset(48, 67),
    Offset(64, 67),
    Offset(76, 61),
  ], close: true);
  final fin = ellipsePath(51, 56, 7, 3.3, angle: 0.5);
  final tail = Path()
    ..moveTo(25.6, 48.6)
    ..quadraticBezierTo(18, 40, 7, 36)
    ..quadraticBezierTo(12, 46, 15, 52)
    ..quadraticBezierTo(12, 58, 7, 68)
    ..quadraticBezierTo(18, 64, 25.6, 55.4);
  final topFin = Path()
    ..moveTo(38, 40)
    ..quadraticBezierTo(42, 26, 56, 22)
    ..quadraticBezierTo(62, 28, 66, 37);
  final bottomFin = Path()
    ..moveTo(44, 65.6)
    ..quadraticBezierTo(46, 74, 52, 76)
    ..quadraticBezierTo(56, 72, 60, 67.2);
  return DrawingGuide('Fish', '🐟', [
    GuideStep('Draw a long oval and a line through the middle 🥚', [
      _helpOval(53, 51.5, 28, 15.5),
      _helpLine(const [Offset(20, 52), Offset(86, 52)]),
    ]),
    GuideStep('Draw the body with a pointy nose 🐟', [GuideShape(body)]),
    GuideStep('Add a tail with two points 🐠', [
      GuideShape(tail),
      _line(const [Offset(23, 52), Offset(12, 42)]),
      _line(const [Offset(23, 52), Offset(12, 62)]),
    ]),
    GuideStep('Draw a fin on top and one below 🌊', [
      GuideShape(topFin),
      GuideShape(bottomFin),
    ]),
    GuideStep('Add a big shiny eye, a gill line and a smile 👁️', [
      _circle(70, 47, 4.6),
      ..._eye(70.6, 47.4, 3.2),
      _smooth(const [Offset(63, 39), Offset(59.5, 51), Offset(63, 63)]),
      _smooth(const [Offset(81, 52.5), Offset(77.5, 54.5), Offset(74, 53.5)]),
      _blush(70, 57),
    ]),
    GuideStep('Add a side fin and little bumps for scales 🐟', [
      GuideShape(fin),
      _line(const [Offset(45.5, 53), Offset(55, 57.5)]),
      _line(const [Offset(45.5, 53), Offset(53, 60)]),
      ..._scallops(body, const Rect.fromLTRB(28, 40, 58, 64), 5, avoid: fin),
    ]),
    GuideStep('Rub out the helper lines, shade and add bubbles 🫧', [
      _hatch(_minus(body, body.shift(const Offset(0, 5))),
          angle: 1.1, gap: 1.1),
      for (final (i, f) in [tail, topFin, bottomFin].indexed)
        _hatch(f, angle: 0.3 + i, gap: 1.3, seed: i + 2),
      _circle(88, 38, 3),
      _circle(92, 28, 2.4),
      _circle(87, 19, 3.4),
      _shine(88.9, 37, 0.9),
      _shine(88.1, 17.8, 1),
      _smooth(const [
        Offset(84, 96),
        Offset(81, 86),
        Offset(85, 76),
        Offset(82, 66)
      ]),
      _smooth(const [
        Offset(89, 96),
        Offset(86, 86),
        Offset(90, 76),
        Offset(87, 68)
      ]),
      _fine(const [Offset(0, 96), Offset(100, 96)]),
    ]),
  ]);
}

DrawingGuide _flower() {
  const c = Offset(50, 30);
  return _sketch(
    DrawingGuide('Flower', '🌻', [
      GuideStep('Draw a circle for the middle ⭕', [_circle(c.dx, c.dy, 9)]),
      GuideStep('Draw pointy petals all around 🌻', [
        for (int i = 0; i < 14; i++)
          _leaf(_on(c.dx, c.dy, 9, 9, i * 2 * math.pi / 14 + 0.22),
              _on(c.dx, c.dy, 24, 24, i * 2 * math.pi / 14 + 0.22), 4.6),
      ]),
      GuideStep('Fill the middle with seeds 🌰', [
        _dot(c.dx, c.dy, 0.9),
        for (final o in ringPoints(c.dx, c.dy, 3.4, 6)) _dot(o.dx, o.dy, 0.9),
        for (final o in ringPoints(c.dx, c.dy, 6.4, 10, start: 0.3))
          _dot(o.dx, o.dy, 0.9),
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
        ..._tufts(const [
          Offset(14, 92),
          Offset(30, 92),
          Offset(70, 92),
          Offset(86, 92)
        ]),
        _oval(82, 30, 4.6, 3),
        _line(const [Offset(80.5, 27.3), Offset(80.5, 32.7)]),
        _line(const [Offset(83.5, 27.3), Offset(83.5, 32.7)]),
        _oval(80.5, 24.2, 2, 3, angle: -0.4),
        _oval(84, 24.2, 2, 3, angle: 0.4),
      ]),
    ]),
    helpText: 'Draw a big helper circle and a line down the middle ⭕',
    help: [
      _helpCircle(50, 30, 24),
      _helpLine(const [Offset(50, 6), Offset(50, 92)]),
    ],
    shade: [
      _hatch(circlePath(c.dx, c.dy, 8.6), angle: 0.8, gap: 1.2, cross: true),
      _hatch(
          Path.combine(
              PathOperation.intersect,
              circlePath(c.dx, c.dy, 15),
              [
                for (int i = 0; i < 14; i++)
                  _leaf(
                          _on(c.dx, c.dy, 9, 9, i * 2 * math.pi / 14 + 0.22),
                          _on(c.dx, c.dy, 24, 24, i * 2 * math.pi / 14 + 0.22),
                          4.6)
                      .path,
              ].reduce((a, b) => Path.combine(PathOperation.union, a, b))),
          angle: 1.1,
          gap: 1.1,
          seed: 2),
      _hatch(_leaf(const Offset(48.2, 72), const Offset(28, 62), 8).path,
          angle: 1.1, gap: 1.4, seed: 3),
      _hatch(_leaf(const Offset(52.4, 80), const Offset(72, 70), 8).path,
          angle: 1.1, gap: 1.4, seed: 4),
    ],
  );
}

DrawingGuide _iceCream() => _sketch(
      DrawingGuide('Ice cream', '🍦', [
        GuideStep('Draw a cone pointing down 🔻', [
          _line(const [Offset(35, 59), Offset(50, 97), Offset(65, 59)]),
        ]),
        GuideStep('Draw a band across the top of the cone ➖', [
          _round(32, 51, 68, 59, 2.5),
        ]),
        GuideStep('Draw crossing lines on the cone ✖️', [
          for (final t in [0.0, 0.25, 0.5]) ...[
            _line([
              Offset(35 + 15 * t, 59 + 38 * t),
              Offset(65 - 15 * (t + 0.3), 59 + 38 * (t + 0.3))
            ]),
            _line([
              Offset(65 - 15 * t, 59 + 38 * t),
              Offset(35 + 15 * (t + 0.3), 59 + 38 * (t + 0.3))
            ]),
          ],
        ]),
        GuideStep('Draw a big scoop with drips 🍨', [
          _smooth(const [
            Offset(30, 49),
            Offset(28, 41),
            Offset(33, 33),
            Offset(42, 29),
            Offset(50, 30),
            Offset(58, 29),
            Offset(67, 33),
            Offset(72, 41),
            Offset(70, 49),
            Offset(66, 50.5),
            Offset(63, 48.5),
            Offset(60, 51),
            Offset(56, 49),
            Offset(52, 51),
            Offset(48, 49),
            Offset(44, 51),
            Offset(40, 49),
            Offset(36, 51),
            Offset(33, 49.5),
          ], close: true),
        ]),
        GuideStep('Draw another scoop on top 🍦', [
          _smooth(const [
            Offset(38.5, 30.6),
            Offset(37, 23),
            Offset(42, 16),
            Offset(50, 13.5),
            Offset(58, 16),
            Offset(63, 23),
            Offset(61.5, 30.6),
          ]),
        ]),
        GuideStep('Put a cherry on top 🍒', [
          _circle(50, 9.6, 3.8),
          _smooth(const [Offset(50.5, 5.8), Offset(51.5, 3), Offset(54, 1)]),
        ]),
        GuideStep('Add sprinkles ✨', [
          for (final (x, y) in const [
            (36.0, 40.0),
            (44.0, 36.0),
            (56.0, 38.0),
            (64.0, 42.0),
            (48.0, 44.0),
            (46.0, 22.0),
            (54.0, 20.0),
            (50.0, 27.0),
          ])
            _line([Offset(x, y), Offset(x + 2, y + 1)]),
        ]),
      ]),
      helpText: 'Draw a helper circle and a line down the middle ⭕',
      help: [
        _helpCircle(50, 38, 22),
        _helpLine(const [Offset(50, 2), Offset(50, 98)]),
      ],
      shade: [
        for (final scoop in [
          blobPath(const [
            Offset(30, 49),
            Offset(28, 41),
            Offset(33, 33),
            Offset(42, 29),
            Offset(50, 30),
            Offset(58, 29),
            Offset(67, 33),
            Offset(72, 41),
            Offset(70, 49),
            Offset(50, 50.6),
          ]),
        ])
          _hatch(_minus(scoop, scoop.shift(const Offset(-3, -4))),
              angle: 1.1, gap: 1.1),
        for (final top in [
          blobPath(const [
            Offset(38.5, 30.6),
            Offset(37, 23),
            Offset(42, 16),
            Offset(50, 13.5),
            Offset(58, 16),
            Offset(63, 23),
            Offset(61.5, 30.6),
            Offset(50, 30),
          ]),
        ])
          _hatch(_minus(top, top.shift(const Offset(-3, -3))),
              angle: 1.1, gap: 1.1, seed: 2),
        _hatch(_minus(circlePath(50, 9.6, 3.8), circlePath(48.6, 8.2, 3.8)),
            angle: 1.1, gap: 0.8, seed: 3),
        _hatch(rectPath(62, 51.4, 67.6, 58.6), angle: 1.1, gap: 1.1, seed: 4),
      ],
    );

DrawingGuide _car() {
  final body = Path.combine(
    PathOperation.difference,
    smoothPath(const [
      Offset(9, 71),
      Offset(8, 62),
      Offset(11, 55),
      Offset(24, 52),
      Offset(34, 40),
      Offset(44, 37.5),
      Offset(58, 38),
      Offset(66, 42),
      Offset(73, 51),
      Offset(86, 54),
      Offset(92, 58),
      Offset(93, 66),
      Offset(91, 72),
      Offset(70, 72.5),
      Offset(30, 72.5),
    ], close: true),
    Path.combine(
        PathOperation.union, circlePath(26, 73, 11), circlePath(74, 73, 11)),
  );
  return _sketch(
    DrawingGuide('Car', '🚗', [
      GuideStep('Draw the car with two round holes for wheels 🚗',
          [GuideShape(body)]),
      GuideStep('Add two windows and a mirror 🪟', [
        _line(const [
          Offset(30, 51),
          Offset(37, 42),
          Offset(46, 40),
          Offset(46, 51)
        ], close: true),
        _line(const [
          Offset(49, 51),
          Offset(49, 40),
          Offset(58, 40.5),
          Offset(64, 43),
          Offset(69, 51)
        ], close: true),
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
            _line([
              _on(x, 73, 1.6, 1.6, i * 2 * math.pi / 5),
              _on(x, 73, 5, 5, i * 2 * math.pi / 5)
            ]),
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
        _smooth(const [
          Offset(86, 56.5),
          Offset(91, 58),
          Offset(91.5, 62),
          Offset(87, 61)
        ], close: true),
        _round(9, 57, 12.5, 63, 1),
      ]),
      GuideStep('Draw the road and zoom lines 💨', [
        _line(const [Offset(0, 82), Offset(100, 82)]),
        _line(const [Offset(0, 58), Offset(5, 58)]),
        _line(const [Offset(0, 64), Offset(6, 64)]),
        _line(const [Offset(1, 70), Offset(6, 70)]),
      ]),
    ]),
    helpText: 'Draw a line for the road and two helper circles ⭕',
    help: [
      _helpLine(const [Offset(0, 82), Offset(100, 82)]),
      _helpCircle(26, 73, 11),
      _helpCircle(74, 73, 11),
    ],
    shade: [
      for (final glass in [
        polyPath(const [
          Offset(30, 51),
          Offset(37, 42),
          Offset(46, 40),
          Offset(46, 51)
        ]),
        polyPath(const [
          Offset(49, 51),
          Offset(49, 40),
          Offset(58, 40.5),
          Offset(64, 43),
          Offset(69, 51),
        ]),
      ])
        _hatch(glass, angle: -0.9, gap: 2.6, seed: 2),
      for (final x in [26.0, 74.0])
        _hatch(_minus(circlePath(x, 73, 9), circlePath(x, 73, 5)),
            angle: 1.1, gap: 1, cross: true, seed: 3),
      _hatch(
          _minus(
              Path.combine(
                  PathOperation.intersect, body, rectPath(0, 65, 100, 80)),
              Path.combine(PathOperation.union, circlePath(26, 73, 9.6),
                  circlePath(74, 73, 9.6))),
          angle: 1.1,
          gap: 1.2,
          seed: 4),
    ],
  );
}

/// Same shape flipped left to right (for wings, ears, legs).
GuideShape _flip(GuideShape s) => s.transformed(
    Matrix4.translationValues(100, 0, 0) * Matrix4.diagonal3Values(-1, 1, 1));

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
  final tip = center[n - 1] +
      (center[n - 1] - center[n - 2]) /
          (center[n - 1] - center[n - 2]).distance *
          0.8;
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
  return [
    for (final r in runs)
      if (r.length > 1) _line(r)
  ];
}

DrawingGuide _train() => _sketch(
      DrawingGuide('Train', '🚂', [
        GuideStep('Draw a tall box at the back for the cab 🟥', [
          _line(const [
            Offset(14, 32),
            Offset(14, 70),
            Offset(34, 70),
            Offset(34, 32)
          ]),
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
          _line(const [
            Offset(61, 48),
            Offset(61, 39),
            Offset(57.5, 32),
            Offset(69.5, 32),
            Offset(66, 39),
            Offset(66, 48)
          ]),
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
            circlePath(65, 26, 4),
            circlePath(71, 20, 5),
            circlePath(79, 13, 6),
            circlePath(89, 9, 5),
          ].reduce((a, b) => Path.combine(PathOperation.union, a, b))),
        ]),
        GuideStep('Draw the track 🛤️', [
          _line(const [Offset(0, 86), Offset(100, 86)]),
          for (final x in [2.0, 14.0, 26.0, 38.0, 50.0, 62.0, 74.0, 86.0])
            _line([
              Offset(x, 86),
              Offset(x, 89),
              Offset(x + 6, 89),
              Offset(x + 6, 86)
            ]),
        ]),
      ]),
      help: [
        _helpLine(const [Offset(0, 86), Offset(100, 86)]),
      ],
      shade: [
        for (final (x, r) in const [(24.0, 8.0), (44.0, 8.0), (62.0, 5.4)])
          _hatch(
              _minus(circlePath(x, x == 62 ? 80 : 78, r),
                  circlePath(x, x == 62 ? 80 : 78, r - 2.2)),
              angle: 1.1,
              gap: 1,
              seed: 2),
        _hatch(roundRectPath(18, 37, 30, 47, 2),
            angle: -0.9, gap: 2.4, seed: 3),
        _hatch(rectPath(34.6, 64, 70.6, 69.6), angle: 1.1, gap: 1.1, seed: 4),
        _hatch(rectPath(14.6, 62, 33.4, 69.6), angle: 1.1, gap: 1.1, seed: 5),
      ],
    );

DrawingGuide _rocket() {
  const pivot = Offset(50, 54);
  final m = Matrix4.translationValues(pivot.dx, pivot.dy, 0) *
      Matrix4.rotationZ(0.3) *
      Matrix4.translationValues(-pivot.dx, -pivot.dy, 0);
  List<GuideShape> tilt(List<GuideShape> shapes) => [
        for (final s in shapes) s.transformed(m),
      ];
  final planet = circlePath(80, 20, 8);
  return _sketch(
    DrawingGuide('Rocket', '🚀', [
      GuideStep(
          'Draw a tall rocket body with a pointy top 🚀',
          tilt([
            _smooth(const [
              Offset(50, 12),
              Offset(56, 20),
              Offset(59, 34),
              Offset(60, 50),
              Offset(59, 66),
              Offset(56, 74),
              Offset(44, 74),
              Offset(41, 66),
              Offset(40, 50),
              Offset(41, 34),
              Offset(44, 20),
            ], close: true),
          ])),
      GuideStep(
          'Draw lines for the nose and a stripe ➖',
          tilt([
            _smooth(
                const [Offset(42.6, 27), Offset(50, 25.6), Offset(57.4, 27)]),
            _line(const [Offset(40.1, 49), Offset(59.9, 49)]),
            _line(const [Offset(40.2, 54), Offset(59.8, 54)]),
          ])),
      GuideStep(
          'Add a round window ⭕',
          tilt([
            _circle(50, 37, 7.5),
            _circle(50, 37, 5),
            _arc(50, 37, 3.2, 3.6, 1.3),
          ])),
      GuideStep(
          'Draw three fins 🔺',
          tilt([
            _smooth(const [
              Offset(40.6, 56),
              Offset(34, 64),
              Offset(31, 77),
              Offset(36, 76),
              Offset(42.2, 70)
            ]),
            _smooth(const [
              Offset(59.4, 56),
              Offset(66, 64),
              Offset(69, 77),
              Offset(64, 76),
              Offset(57.8, 70)
            ]),
            _oval(50, 66, 2.2, 7),
          ])),
      GuideStep(
          'Add the engine and a big flame 🔥',
          tilt([
            _line(const [
              Offset(44.6, 73.6),
              Offset(42, 79),
              Offset(58, 79),
              Offset(55.4, 73.6)
            ]),
            _smooth(const [
              Offset(43, 79),
              Offset(45, 86),
              Offset(50, 97),
              Offset(55, 86),
              Offset(57, 79)
            ]),
            _smooth(const [
              Offset(46.5, 79),
              Offset(48, 85),
              Offset(50, 90),
              Offset(52, 85),
              Offset(53.5, 79)
            ]),
          ])),
      GuideStep(
          'Add little bolts ⚙️',
          tilt([
            for (final (x, y) in const [
              (45.0, 31.0),
              (55.0, 31.0),
              (44.0, 60.0),
              (56.0, 60.0)
            ])
              _dot(x, y, 0.8),
          ])),
      GuideStep('Draw stars and a planet with a ring 🪐', [
        GuideShape(planet),
        ..._ellipseOutside(
            80,
            20,
            15,
            4,
            -0.35,
            Path.combine(
                PathOperation.intersect, planet, rectPath(60, 0, 100, 20))),
        _star(14, 16, 4),
        _star(16, 80, 3.6),
        _star(86, 84, 4),
        _star(88, 52, 3),
        _dot(30, 40, 1),
        _dot(72, 92, 1),
      ]),
    ]),
    helpText: 'Draw a long slanted helper line ✏️',
    help: tilt([
      _helpLine(const [Offset(50, 8), Offset(50, 98)])
    ]),
    shade: [
      ...tilt([
        for (final body in [
          blobPath(const [
            Offset(50, 12),
            Offset(56, 20),
            Offset(59, 34),
            Offset(60, 50),
            Offset(59, 66),
            Offset(56, 74),
            Offset(44, 74),
            Offset(41, 66),
            Offset(40, 50),
            Offset(41, 34),
            Offset(44, 20),
          ]),
        ])
          _hatch(_minus(body, body.shift(const Offset(-4, 0))),
              angle: 1.4, gap: 1.1),
        _hatch(
            blobPath(const [
              Offset(40.6, 56),
              Offset(34, 64),
              Offset(31, 77),
              Offset(36, 76),
              Offset(42.2, 70),
            ]),
            angle: 1.1,
            gap: 1.1,
            seed: 2),
        _hatch(
            blobPath(const [
              Offset(59.4, 56),
              Offset(66, 64),
              Offset(69, 77),
              Offset(64, 76),
              Offset(57.8, 70),
            ]),
            angle: 1.1,
            gap: 1.1,
            seed: 3),
      ]),
      _hatch(_minus(planet, planet.shift(const Offset(-3, -3))),
          angle: 1.1, gap: 1, seed: 4),
    ],
  );
}

DrawingGuide _octopus() {
  const arms = [
    [
      Offset(38.3, 57),
      Offset(31, 65),
      Offset(21, 71),
      Offset(13, 69),
      Offset(11, 63)
    ],
    [
      Offset(43, 57),
      Offset(39, 70),
      Offset(31, 82),
      Offset(24, 86),
      Offset(21, 82)
    ],
    [
      Offset(47.7, 57),
      Offset(45.5, 70),
      Offset(39, 83),
      Offset(35, 91),
      Offset(39, 93.5)
    ],
  ];
  final left = [for (final a in arms) _tentacle(a, 4.6)];
  final head = blobPath(const [
    Offset(36, 57),
    Offset(28, 44),
    Offset(28, 28),
    Offset(38, 16),
    Offset(50, 12),
    Offset(62, 16),
    Offset(72, 28),
    Offset(72, 44),
    Offset(64, 57),
    Offset(50, 58),
  ]);
  final armArea = [
    for (final a in left) ...[a.path, _flip(a).path],
  ].reduce((a, b) => Path.combine(PathOperation.union, a, b));
  return DrawingGuide('Octopus', '🐙', [
    GuideStep('Draw a big circle and a line across it ⭕', [
      _helpCircle(50, 35, 22),
      _helpLine(const [Offset(28, 40), Offset(72, 40)]),
    ]),
    GuideStep('Draw a big round head over the circle 🐙', [
      _smooth(const [
        Offset(36, 57),
        Offset(28, 44),
        Offset(28, 28),
        Offset(38, 16),
        Offset(50, 12),
        Offset(62, 16),
        Offset(72, 28),
        Offset(72, 44),
        Offset(64, 57),
      ]),
    ]),
    GuideStep('Add big shiny eyes, a smile and rosy cheeks 👀', [
      _oval(41, 40, 4.8, 5.2),
      _oval(59, 40, 4.8, 5.2),
      ..._eye(41.4, 40.8, 3.6),
      ..._eye(59.4, 40.8, 3.6),
      _arc(50, 47, 3.4, 0.4, math.pi - 0.8),
      _blush(35, 48),
      _blush(65, 48),
    ]),
    GuideStep('Draw three curly arms on this side 🌀', left),
    GuideStep('Draw three more on the other side 🌀',
        [for (final a in left) _flip(a)]),
    GuideStep('Add spots on the head and suckers on the arms ⚪', [
      _oval(40, 25, 2.6, 1.8),
      _oval(54, 19, 2.2, 1.5),
      _oval(63, 29, 2.4, 1.6),
      for (final a in arms.take(2))
        for (final p in [a[1], a[2]]) ...[
          _circle(p.dx, p.dy, 0.9),
          _flip(_circle(p.dx, p.dy, 0.9)),
        ],
    ]),
    GuideStep('Rub out the helper lines, shade and add bubbles 🫧', [
      _hatch(_minus(head, head.shift(const Offset(-4, 3))),
          angle: 1.1, gap: 1.1),
      _hatch(_minus(head, head.shift(const Offset(3, 3))),
          angle: 1.9, gap: 1.4, seed: 2),
      _hatch(_minus(armArea, rectPath(0, 0, 100, 74)),
          angle: 1.1, gap: 1.2, seed: 3),
      _circle(84, 22, 4),
      _circle(90, 12, 3),
      _circle(15, 24, 3.4),
      _circle(10, 34, 2.4),
      _shine(85.4, 20.6, 1),
      _shine(16.2, 22.8, 0.9),
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
  final upper = blobPath(const [
    Offset(47.7, 38),
    Offset(40, 24),
    Offset(28, 14),
    Offset(14, 12),
    Offset(8, 18),
    Offset(10, 30),
    Offset(18, 42),
    Offset(32, 48),
    Offset(48.4, 46.4),
  ]);
  final lower = blobPath(const [
    Offset(48.5, 49),
    Offset(36, 50.5),
    Offset(22, 56),
    Offset(16, 66),
    Offset(20, 76),
    Offset(30, 80),
    Offset(40, 74),
    Offset(47.6, 64),
  ]);
  final spotUp = ellipsePath(28, 28, 6, 3.6, angle: 0.6);
  final spotLow = ellipsePath(32, 64, 4.6, 3.6, angle: -0.4);
  // Dark band along the outer edge of each wing.
  final edge = Path.combine(
      PathOperation.union,
      _minus(upper, ellipsePath(34, 34, 19, 13, angle: 0.5)),
      _minus(lower, ellipsePath(38, 62, 14, 11, angle: -0.6)));
  return DrawingGuide('Butterfly', '🦋', [
    GuideStep('Draw a line down the middle and four circles 🦋', [
      _helpLine(const [Offset(50, 14), Offset(50, 76)]),
      _helpCircle(29, 30, 18),
      _helpCircle(71, 30, 18),
      _helpCircle(34, 64, 14),
      _helpCircle(66, 64, 14),
    ]),
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
          Offset(47.7, 38),
          Offset(40, 24),
          Offset(28, 14),
          Offset(14, 12),
          Offset(8, 18),
          Offset(10, 30),
          Offset(18, 42),
          Offset(32, 48),
          Offset(48.4, 46.4),
        ]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Draw two smaller wings below', [
      for (final s in [
        _smooth(const [
          Offset(48.5, 49),
          Offset(36, 50.5),
          Offset(22, 56),
          Offset(16, 66),
          Offset(20, 76),
          Offset(30, 80),
          Offset(40, 74),
          Offset(47.6, 64),
        ]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Draw lines and big spots on the wings 〰️', [
      for (final s in [
        ...upperVeins,
        ...lowerVeins,
        GuideShape(spotUp),
        GuideShape(spotLow),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Add little dots near the edges ⚪', [
      for (final (x, y) in const [
        (14.0, 17.0),
        (12.0, 24.0),
        (15.0, 32.0),
        (21.0, 16.0),
        (21.0, 68.0),
        (25.0, 75.0),
        (32.0, 77.0),
      ]) ...[_circle(x, y, 1.8), _flip(_circle(x, y, 1.8))],
    ]),
    GuideStep('Rub out the helper lines and shade the wings ✏️', [
      for (final (i, a) in [edge, _mirror(edge)].indexed)
        _hatch(a, angle: 1.1, gap: 1, seed: i, cross: true),
      for (final (i, a)
          in [spotUp, spotLow, _mirror(spotUp), _mirror(spotLow)].indexed)
        _hatch(a, angle: 0.4, gap: 0.9, seed: i + 3),
      _hatch(ellipsePath(50, 59.5, 2.6, 13), angle: 0.2, gap: 0.9, seed: 8),
    ]),
  ]);
}

DrawingGuide _bird() {
  final body = blobPath(const [
    Offset(60, 24),
    Offset(68, 26.6),
    Offset(72.4, 34),
    Offset(71, 43),
    Offset(68, 52),
    Offset(63, 61),
    Offset(54, 67.6),
    Offset(44, 69.4),
    Offset(35, 66.4),
    Offset(30, 60),
    Offset(30.4, 52.4),
    Offset(35, 46),
    Offset(43, 41.6),
    Offset(50, 37.6),
    Offset(52.4, 29.6),
  ]);
  final wing = blobPath(const [
    Offset(37, 52),
    Offset(47, 47.4),
    Offset(57, 49.4),
    Offset(61.6, 55.6),
    Offset(56, 62),
    Offset(45, 62.6),
    Offset(37.4, 58.6),
  ]);
  final tummy = ellipsePath(61, 50, 16, 15.5, angle: -0.6);
  return DrawingGuide('Bird', '🐦', [
    GuideStep('Draw a circle for the head and an oval for the body ⭕', [
      _helpCircle(61, 36, 11.5),
      _helpOval(49, 55, 20, 14, angle: -0.3),
    ]),
    GuideStep('Draw one smooth line around both shapes ✏️', [GuideShape(body)]),
    GuideStep('Add a pointy beak and a shiny eye 👀', [
      _line(const [Offset(72.2, 32.6), Offset(80.4, 35.6), Offset(71.8, 38.6)]),
      _line(const [Offset(72.4, 35.6), Offset(77, 35.6)]),
      ..._eye(64.4, 33.2, 2.6),
      _blush(66, 39.6),
    ]),
    GuideStep('Draw a wing with feathers 🪶', [
      GuideShape(wing),
      _smooth(const [Offset(44, 57.8), Offset(51, 59.4), Offset(57.6, 57)]),
      _smooth(const [Offset(46, 53.6), Offset(52, 54.6), Offset(58.4, 53)]),
    ]),
    GuideStep('Add long tail feathers 🪶', [
      _smooth(const [
        Offset(30.6, 54.6),
        Offset(22, 49.6),
        Offset(13.6, 47.6),
        Offset(15.6, 52),
        Offset(22, 56.2),
        Offset(14.4, 57.4),
        Offset(19, 61.4),
        Offset(30.6, 61.4),
      ]),
      _fine(const [Offset(29, 57), Offset(20, 53.6)]),
    ]),
    GuideStep('Draw a branch to sit on 🌿', [
      _smooth(const [
        Offset(2, 80),
        Offset(30, 79.2),
        Offset(60, 80.6),
        Offset(98, 78.6)
      ]),
      _smooth(const [
        Offset(2, 85.4),
        Offset(30, 84.6),
        Offset(60, 86),
        Offset(98, 84)
      ]),
      _leaf(const Offset(84, 79.2), const Offset(93, 69.4), 4.6),
      _leaf(const Offset(16, 84.8), const Offset(8, 94), 4.6),
    ]),
    GuideStep('Add two legs holding the branch 🦶', [
      _line(const [Offset(46, 69.2), Offset(45.4, 79.6)]),
      _line(const [Offset(54, 67.6), Offset(54.4, 80.2)]),
      _arc(45.4, 81.8, 2.2, 3.4, 2.6),
      _arc(54.4, 82.4, 2.2, 3.4, 2.6),
    ]),
    GuideStep('Rub out the helper lines and shade the back ✏️', [
      _hatch(_minus(_minus(body, tummy), wing), angle: 1.1, gap: 1.2),
      _hatch(_minus(wing, wing.shift(const Offset(0, -3))),
          angle: 1.1, gap: 1.2, seed: 2),
      _furStrokes(
          Path.combine(PathOperation.intersect, body, _minus(tummy, wing)), 14,
          len: 2, angle: 2.2, seed: 3),
      for (final x in [12.0, 28.0, 66.0, 80.0])
        _fine([Offset(x, 81.6), Offset(x + 6, 82.2)]),
    ]),
  ]);
}

DrawingGuide _turtle() {
  // Seen from above, head up. The shell is an oval; its edge is the one place
  // every other part (head, flippers, tail) starts and ends.
  const cx = 50.0, cy = 52.0, rx = 21.0, ry = 27.0;
  const rix = 17.0, riy = 23.0; // the ring of edge plates ends here
  Offset shell(double y, {bool left = true, double r = 1}) {
    final k = math.sqrt(math.max(0, 1 - math.pow((y - cy) / (ry * r), 2)));
    return Offset(cx + (left ? -1 : 1) * rx * r * k, y);
  }

  Offset ring(double y, {bool left = true}) {
    final k = math.sqrt(math.max(0, 1 - math.pow((y - cy) / riy, 2)));
    return Offset(cx + (left ? -1 : 1) * rix * k, y);
  }

  // Central row of five plates; neighbours share their top/bottom edge.
  const ys = [28.5, 38.5, 48.5, 58.5, 67.5, 74.5];
  const junction = [4.2, 5.4, 5.6, 5.0, 3.8, 2.2]; // half width at each level
  const middle = [7.0, 8.2, 7.8, 6.6, 4.6]; // half width mid plate
  Path vertebral(int i) => polyPath([
        Offset(cx - junction[i], ys[i]),
        Offset(cx + junction[i], ys[i]),
        Offset(cx + middle[i], (ys[i] + ys[i + 1]) / 2),
        Offset(cx + junction[i + 1], ys[i + 1]),
        Offset(cx - junction[i + 1], ys[i + 1]),
        Offset(cx - middle[i], (ys[i] + ys[i + 1]) / 2),
      ]);
  // Side plates sit between the central row and the edge ring; lines from the
  // central row's corners run out and slightly back to the ring.
  Offset ringAt(int i, bool left) => ring(ys[i] + 3, left: left);
  Path costal(int i, bool left) {
    final s = left ? -1.0 : 1.0;
    final top = Offset(cx + s * junction[i], ys[i]);
    final mid = Offset(cx + s * middle[i], (ys[i] + ys[i + 1]) / 2);
    final bottom = Offset(cx + s * junction[i + 1], ys[i + 1]);
    final b0 = ringAt(i, left);
    final b1 = i == 4 ? ring(ys[5] - 1, left: left) : ringAt(i + 1, left);
    final edge = [
      for (int k = 1; k < 4; k++)
        ring(b1.dy + (b0.dy - b1.dy) * k / 4, left: left),
    ];
    return polyPath([top, mid, bottom, b1, ...edge, b0]);
  }

  final plates = [
    for (int i = 0; i < 5; i++) vertebral(i),
    for (int i = 0; i < 5; i++) ...[costal(i, true), costal(i, false)],
  ];
  final shellArea = ellipsePath(cx, cy, rx, ry);
  final edgeBand = _minus(shellArea, ellipsePath(cx, cy, rix, riy));

  final headL = shell(26.4, left: true, r: 1);
  final headR = shell(26.4, left: false, r: 1);
  final head = [
    headL,
    const Offset(42.4, 20.5),
    const Offset(44.4, 14.2),
    const Offset(50, 11.4),
    const Offset(55.6, 14.2),
    const Offset(57.6, 20.5),
    headR,
  ];
  final headArea = blobPath(head);

  List<Offset> flipper(double y0, double y1, List<Offset> through) =>
      [shell(y0), ...through, shell(y1)];
  final frontL = flipper(37, 47.5, const [
    Offset(24, 32.6),
    Offset(14.5, 30.4),
    Offset(5.4, 33.6),
    Offset(8.4, 39.6),
    Offset(17.4, 44.6),
  ]);
  final hindL = flipper(66, 72.5, const [
    Offset(30.6, 72),
    Offset(26.6, 78),
    Offset(29.4, 81),
    Offset(35, 78),
  ]);
  GuideShape mirrored(List<Offset> pts) => _flip(_smooth(pts));
  final tail = _smooth([
    shell(78.6, left: true),
    const Offset(50, 85),
    shell(78.6, left: false)
  ]);

  Path flipperArea(List<Offset> pts) => blobPath(pts);

  return DrawingGuide('Turtle', '🐢', [
    GuideStep(
        'Draw a tall oval, a line down the middle and a little circle on top ⭕',
        [
          _helpOval(cx, cy, rx, ry),
          _helpLine(const [Offset(50, 8), Offset(50, 88)]),
          _helpCircle(50, 18, 8.4),
        ]),
    GuideStep('Draw over the oval for the shell 🐢', [GuideShape(shellArea)]),
    GuideStep('Draw the head with eyes and a smile 👀', [
      _smooth(head),
      ..._eye(46, 17, 1.7),
      ..._eye(54, 17, 1.7),
      _dot(48.9, 21.2, 0.35),
      _dot(51.1, 21.2, 0.35),
      _smooth(const [Offset(46.6, 23.4), Offset(50, 24.8), Offset(53.4, 23.4)]),
    ]),
    GuideStep('Draw four flippers and a tiny tail 🌊', [
      _smooth(frontL),
      mirrored(frontL),
      _smooth(hindL),
      mirrored(hindL),
      tail,
    ]),
    GuideStep('Draw a smaller oval inside and little lines around the edge ➖', [
      GuideShape(ellipsePath(cx, cy, rix, riy)),
      for (int i = 0; i < 22; i++)
        if (i != 0 && i != 11)
          _line([
            _on(cx, cy, rix, riy, i * 2 * math.pi / 22 + 0.14),
            _on(cx, cy, rx, ry, i * 2 * math.pi / 22 + 0.14),
          ]),
    ]),
    GuideStep('Draw five plates down the middle 🔶', [
      for (int i = 0; i < 5; i++) GuideShape(vertebral(i)),
    ]),
    GuideStep('Draw the plates on both sides 🔷', [
      for (int i = 0; i < 5; i++) ...[
        GuideShape(costal(i, true)),
        GuideShape(costal(i, false)),
      ],
    ]),
    GuideStep('Rub out the helper lines, add scales and shade the shell ✏️', [
      for (int i = 0; i < plates.length; i++)
        _hatch(plates[i],
            angle: 1.1 + (i % 3) * 0.12,
            gap: 1.25,
            seed: i,
            cross: i < 5 && i % 2 == 0),
      _hatch(edgeBand, angle: 0.5, gap: 1.7, seed: 20),
      for (final (i, f) in [frontL, hindL].indexed) ...[
        _hatch(flipperArea(f), angle: 0.7, gap: 1.6, seed: 30 + i),
        _hatch(_mirror(flipperArea(f)), angle: 2.4, gap: 1.6, seed: 40 + i),
      ],
      _hatch(_minus(headArea, headArea.shift(const Offset(2, 3))),
          angle: 1.1, gap: 0.8, seed: 8),
      _fine(const [Offset(8, 66), Offset(13, 70), Offset(12, 76)]),
      _fine(const [Offset(92, 66), Offset(87, 70), Offset(88, 76)]),
      _fine(const [Offset(20, 90), Offset(30, 92), Offset(40, 91)]),
      _fine(const [Offset(60, 91), Offset(70, 92), Offset(80, 90)]),
    ]),
  ]);
}

DrawingGuide _cat() {
  final head = circlePath(50, 35, 17);
  const ear = [
    Offset(35, 27),
    Offset(31.6, 17),
    Offset(30.6, 9),
    Offset(37.5, 12.6),
    Offset(45, 18.8),
  ];
  const innerEar = [Offset(35.4, 22.6), Offset(33.6, 14), Offset(41, 18.2)];
  const side = [
    Offset(29.6, 85),
    Offset(27.2, 77),
    Offset(27.6, 67),
    Offset(31, 57.5),
    Offset(36, 50.6),
  ];
  final bodyArea = blobPath([
    ...side.reversed,
    const Offset(44, 53),
    const Offset(56, 53),
    for (final p in side) Offset(100 - p.dx, p.dy),
    const Offset(60, 90),
    const Offset(40, 90),
  ]);
  final hindPaw = _smooth(const [
    Offset(29.6, 85),
    Offset(26.6, 87.6),
    Offset(27.8, 90.6),
    Offset(33.5, 91.4),
    Offset(40.4, 90.6),
  ]);
  final frontPaw = _smooth(const [
    Offset(41, 86.6),
    Offset(39.8, 89.6),
    Offset(42.6, 92),
    Offset(45.4, 91.2),
    Offset(48, 92),
    Offset(50, 90.4),
  ]);
  return DrawingGuide('Cat', '🐱', [
    GuideStep('Draw a circle for the head and a cross in it ⭕', [
      _helpCircle(50, 35, 17),
      _helpLine(const [Offset(50, 17), Offset(50, 53)]),
      _helpLine(const [Offset(33, 37), Offset(67, 37)]),
    ]),
    GuideStep('Draw a big round shape for the body 🥚', [
      _helpOval(50, 71, 22, 19),
    ]),
    GuideStep('Draw pointy ears and fluffy cheeks 🐱', [
      for (final s in [
        _smooth(ear),
        _smooth(innerEar),
        _smooth(const [Offset(35, 27), Offset(33, 32), Offset(32.6, 38)]),
      ]) ...[s, _flip(s)],
      _smooth(const [Offset(45, 18.8), Offset(50, 18.1), Offset(55, 18.8)]),
      _fluffy(const [
        Offset(32.6, 38),
        Offset(33.4, 45),
        Offset(38.6, 50.6),
        Offset(50, 53.4),
        Offset(61.4, 50.6),
        Offset(66.6, 45),
        Offset(67.4, 38),
      ], inside: head, every: 5, depth: 2.2),
    ]),
    GuideStep('Add two big shiny eyes 👀', [
      for (final x in [42.0, 58.0]) ...[
        _oval(x, 37, 4.8, 5),
        _dot(x + 0.3, 37.6, 3.6),
        _shine(x + 1.6, 35.8, 1.4),
        _shine(x - 1, 39.2, 0.6),
      ],
    ]),
    GuideStep('Add a little nose, a smile and whiskers 〰️', [
      _smooth(const [
        Offset(47.8, 43.6),
        Offset(50, 43.1),
        Offset(52.2, 43.6),
        Offset(50, 45.8),
      ], close: true),
      _line(const [Offset(50, 45.8), Offset(50, 47.2)]),
      for (final s in [
        _smooth(
            const [Offset(50, 47.2), Offset(48.2, 48.6), Offset(46.2, 47.8)]),
        _fine(const [Offset(43, 46.4), Offset(34, 45), Offset(24, 45.6)]),
        _fine(const [Offset(43, 48), Offset(34, 48.8), Offset(25, 51.4)]),
        _fine(const [Offset(43.4, 44.8), Offset(36, 42.4), Offset(28, 41)]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Draw the body with two front legs 🐈', [
      for (final s in [
        _smooth(side),
        hindPaw,
        _smooth(const [
          Offset(40.4, 64),
          Offset(40.8, 74),
          Offset(41, 82),
          Offset(41, 86.6)
        ]),
        frontPaw,
        _fine(const [Offset(43.3, 89), Offset(43.4, 91)]),
        _fine(const [Offset(46.6, 89), Offset(46.7, 91)]),
      ]) ...[s, _flip(s)],
      _smooth(const [Offset(50, 64), Offset(50, 76), Offset(50, 90.4)]),
    ]),
    GuideStep('Add a curly tail 🌀', [
      _smooth(const [
        Offset(72.6, 82),
        Offset(80, 84.4),
        Offset(87, 80.5),
        Offset(89.5, 73),
        Offset(87.5, 68.5),
        Offset(84.4, 69.2),
        Offset(85.6, 74),
        Offset(82.5, 78.8),
        Offset(72.8, 78),
      ]),
    ]),
    GuideStep('Rub out the helper lines and add soft fur ✏️', [
      for (final x in [46.6, 50.0, 53.4])
        _fine([Offset(x, 19.6), Offset(x + (50 - x) * 0.15, 25.6)]),
      _furStrokes(blobPath([...innerEar, const Offset(39, 22)]), 5,
          len: 2.4, angle: -1.9),
      _furStrokes(_mirror(blobPath([...innerEar, const Offset(39, 22)])), 5,
          len: 2.4, angle: -1.2, seed: 3),
      _furStrokes(_minus(bodyArea, circlePath(50, 35, 19)), 34,
          len: 2.8, seed: 4),
      _hatch(_minus(bodyArea, bodyArea.shift(const Offset(3, -2))),
          angle: 1.2, gap: 1.2),
      _hatch(_minus(bodyArea, bodyArea.shift(const Offset(-3, -2))),
          angle: 1.9, gap: 1.2, seed: 5),
      _hatch(ellipsePath(50, 93.6, 24, 1.8), angle: 0.3, gap: 1, seed: 6),
      for (final p in const [
        Offset(45.4, 46.2),
        Offset(44.4, 47.6),
        Offset(54.6, 46.2),
        Offset(55.6, 47.6),
      ])
        _dot(p.dx, p.dy, 0.35),
    ]),
  ]);
}

DrawingGuide _bunny() {
  final head = circlePath(50, 38, 14);
  const ear = [
    Offset(41, 27),
    Offset(37.5, 17),
    Offset(36.6, 7),
    Offset(40, 3),
    Offset(44.4, 7.6),
    Offset(45.6, 18),
    Offset(45.2, 25.2),
  ];
  const innerEar = [
    Offset(41.2, 22),
    Offset(39.6, 13),
    Offset(40.6, 7.6),
    Offset(42.6, 12),
    Offset(43, 21),
  ];
  const side = [
    Offset(40.5, 50.6),
    Offset(35, 57),
    Offset(32, 67),
    Offset(32.4, 78),
    Offset(35, 84.5),
  ];
  final bodyArea = blobPath([
    ...side,
    const Offset(42, 90),
    const Offset(58, 90),
    for (final p in side.reversed) Offset(100 - p.dx, p.dy),
    const Offset(50, 52),
  ]);
  return DrawingGuide('Bunny', '🐰', [
    GuideStep('Draw a circle for the head and a cross in it ⭕', [
      _helpCircle(50, 38, 14),
      _helpLine(const [Offset(50, 24), Offset(50, 52)]),
      _helpLine(const [Offset(36, 39), Offset(64, 39)]),
    ]),
    GuideStep('Draw a big oval for the body 🥚', [_helpOval(50, 71, 18, 17)]),
    GuideStep('Draw two long ears and fluffy cheeks 🐰', [
      for (final s in [
        _smooth(ear),
        _smooth(innerEar),
        _smooth(const [Offset(41, 27), Offset(37.2, 31), Offset(36, 38)]),
      ]) ...[s, _flip(s)],
      _smooth(const [Offset(45.2, 25.2), Offset(50, 24.4), Offset(54.8, 25.2)]),
      _fluffy(const [
        Offset(36, 38),
        Offset(37, 45),
        Offset(42, 50.6),
        Offset(50, 52.4),
        Offset(58, 50.6),
        Offset(63, 45),
        Offset(64, 38),
      ], inside: head, every: 4.6, depth: 1.8),
    ]),
    GuideStep('Add shiny eyes, a little nose and a smile 👀', [
      ..._eye(44, 39, 3),
      ..._eye(56, 39, 3),
      _smooth(const [
        Offset(48.4, 44.4),
        Offset(50, 43.8),
        Offset(51.6, 44.4),
        Offset(50, 45.8),
      ], close: true),
      _line(const [Offset(50, 45.8), Offset(50, 47.2)]),
      for (final s in [
        _smooth(
            const [Offset(50, 47.2), Offset(48.4, 48.4), Offset(46.8, 47.6)]),
        _fine(const [Offset(45, 45.6), Offset(38, 44.6), Offset(31, 45)]),
        _fine(const [Offset(45, 47), Offset(38, 48), Offset(32, 50)]),
      ]) ...[s, _flip(s)],
      _blush(40.5, 44),
      _blush(59.5, 44),
    ]),
    GuideStep('Draw the body and two big feet 🦶', [
      _smooth(side),
      _flip(_smooth(side)),
      _oval(34, 88, 8, 3.6),
      _oval(66, 88, 8, 3.6),
      _line(const [Offset(42, 91.2), Offset(58, 91.2)]),
    ]),
    GuideStep('Add little front paws 🐾', [
      for (final s in [
        _smooth(const [Offset(41.6, 64), Offset(42.6, 74), Offset(43.4, 82.8)]),
        _oval(46, 84.6, 3.4, 2.4),
        _fine(const [Offset(45.4, 83.4), Offset(45.4, 85.6)]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Add a round fluffy tail 🐇', [
      _fluffy(const [
        Offset(67.6, 76.6),
        Offset(71.4, 75.2),
        Offset(75, 77.6),
        Offset(75.4, 81.6),
        Offset(72, 84.4),
        Offset(67.6, 83.6),
      ], inside: circlePath(71.4, 80, 3.6), every: 2.6, depth: 1.3),
    ]),
    GuideStep('Rub out the helper lines and add soft fur ✏️', [
      _hatch(blobPath(innerEar), angle: 1.4, gap: 1),
      _hatch(_mirror(blobPath(innerEar)), angle: 1.7, gap: 1, seed: 2),
      _furStrokes(_minus(bodyArea, circlePath(50, 38, 15)), 30,
          len: 2.6, seed: 3),
      _hatch(_minus(bodyArea, bodyArea.shift(const Offset(3, -2))),
          angle: 1.2, gap: 1.2, seed: 4),
      _hatch(_minus(bodyArea, bodyArea.shift(const Offset(-3, -2))),
          angle: 1.9, gap: 1.2, seed: 5),
      _hatch(ellipsePath(50, 94, 26, 1.8), angle: 0.3, gap: 1, seed: 6),
      _furStrokes(
          blobPath(const [
            Offset(44, 26),
            Offset(50, 25.2),
            Offset(56, 26),
            Offset(53, 31),
            Offset(47, 31),
          ]),
          5,
          len: 2,
          angle: -1.57,
          seed: 7),
    ]),
  ]);
}

DrawingGuide _lion() {
  const ear = [
    Offset(34.5, 30),
    Offset(31, 25),
    Offset(31.6, 19.6),
    Offset(36.6, 18.6),
    Offset(41.5, 22.6),
  ];
  const cx = 50.0, cy = 46.0;
  // Close to the face at the sides, room for the ears on top, long at the chin.
  double reach(double a) {
    final down = math.sin(a);
    return 28.5 +
        4.5 * math.pow(math.max(0.0, -down), 2).toDouble() +
        9 * math.pow(math.max(0.0, down), 3).toDouble();
  }

  Offset at(double a, double r) =>
      Offset(cx + r * math.cos(a), cy + r * math.sin(a));
  final mane = Path();
  const locks = 26;
  final rnd = math.Random(5);
  const step = 2 * math.pi / locks;
  final first = at(-math.pi / 2, reach(-math.pi / 2));
  mane.moveTo(first.dx, first.dy);
  for (int i = 0; i < locks; i++) {
    final a = -math.pi / 2 + i * step;
    final tip =
        at(a + step * 1.05, reach(a + step) + 3.5 + rnd.nextDouble() * 3);
    final c1 = at(a + step * 0.5, reach(a + step * 0.5) + 2.5);
    final c2 = at(a + step * 0.9, reach(a + step) + 1);
    final end = at(a + step, reach(a + step));
    mane
      ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, end.dx, end.dy);
  }
  mane.close();
  final face = blobPath(const [
    Offset(41.5, 22.6),
    Offset(50, 21.4),
    Offset(58.5, 22.6),
    Offset(65.5, 30),
    Offset(67.8, 38),
    Offset(67, 47),
    Offset(63.5, 55),
    Offset(58, 62),
    Offset(50, 66),
    Offset(42, 62),
    Offset(36.5, 55),
    Offset(33, 47),
    Offset(32.2, 38),
    Offset(34.5, 30),
  ]);
  final ears =
      Path.combine(PathOperation.union, blobPath(ear), _mirror(blobPath(ear)));
  // Hair strands, skipping the top where the ears are.
  final strands = [
    for (int i = 0; i < 20; i++)
      if (math.atan2(math.sin(i * math.pi / 10), math.cos(i * math.pi / 10))
          case final a when a < -2.6 || a > -0.55)
        _smooth([at(a, 22.5), at(a + 0.06, 26), at(a + 0.14, reach(a) - 0.5)]),
  ];
  return DrawingGuide('Lion', '🦁', [
    GuideStep('Draw a big circle and a cross in it ⭕', [
      _helpCircle(cx, 44, 20),
      _helpLine(const [Offset(50, 22), Offset(50, 68)]),
      _helpLine(const [Offset(29, 42), Offset(71, 42)]),
    ]),
    GuideStep('Add two round ears and the face 🦁', [
      _smooth(ear),
      _flip(_smooth(ear)),
      _smooth(const [Offset(34.6, 26.4), Offset(34.6, 22.4), Offset(38, 21.8)]),
      _flip(_smooth(
          const [Offset(34.6, 26.4), Offset(34.6, 22.4), Offset(38, 21.8)])),
      _smooth(const [Offset(41.5, 22.6), Offset(50, 21.4), Offset(58.5, 22.6)]),
      for (final s in [
        _smooth(const [
          Offset(34.5, 30),
          Offset(32.2, 38),
          Offset(33, 47),
          Offset(36.5, 55),
          Offset(42, 62),
          Offset(50, 66),
        ]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Add eyes and eyebrows 👀', [
      for (final s in [
        _smooth(
            const [Offset(37.2, 41.8), Offset(41, 39.2), Offset(45.4, 41.4)]),
        _smooth(
            const [Offset(38.4, 42.8), Offset(41.6, 43.8), Offset(44.8, 42.2)]),
        _fine(const [Offset(36.4, 37.4), Offset(41, 35.2), Offset(45.4, 36.4)]),
      ]) ...[s, _flip(s)],
      for (final x in [41.6, 58.4]) ...[
        _dot(x, 41.5, 1.8),
        _shine(x + 0.6, 40.9, 0.6),
      ],
    ]),
    GuideStep('Draw a big nose and a smile 👃', [
      _smooth(const [
        Offset(45, 51),
        Offset(50, 50),
        Offset(55, 51),
        Offset(54, 53.8),
        Offset(50, 56.4),
        Offset(46, 53.8),
      ], close: true),
      _line(const [Offset(50, 56.4), Offset(50, 59)]),
      for (final s in [
        _smooth(const [Offset(50, 59), Offset(46.6, 61), Offset(42.6, 60)]),
        _fine(const [Offset(43.2, 45), Offset(44, 50.5), Offset(45.6, 54)]),
      ]) ...[s, _flip(s)],
      _smooth(const [Offset(46, 63), Offset(50, 64.2), Offset(54, 63)]),
    ]),
    GuideStep('Draw a big spiky mane all around 🌞', [GuideShape(mane)]),
    GuideStep('Add hair lines in the mane 〰️', strands),
    GuideStep('Rub out the helper lines and add lots of fur ✏️', [
      _furStrokes(_minus(_minus(mane, face), ears), 150,
          len: 3.6, from: const Offset(cx, cy), seed: 7),
      _furStrokes(
          blobPath(const [
            Offset(44, 64.6),
            Offset(50, 67),
            Offset(56, 64.6),
            Offset(52, 72),
            Offset(48, 72),
          ]),
          8,
          len: 3,
          seed: 8),
      _hatch(_minus(face, face.shift(const Offset(2.4, 1))),
          angle: 1.2, gap: 1.2),
      _hatch(_minus(face, face.shift(const Offset(-2.4, 1))),
          angle: 1.9, gap: 1.2, seed: 2),
      _hatch(
          blobPath(const [
            Offset(46, 53.8),
            Offset(50, 52.6),
            Offset(54, 53.8),
            Offset(50, 56.2),
          ]),
          angle: 0.5,
          gap: 0.7,
          cross: true,
          seed: 3),
      _furStrokes(blobPath(ear), 5, len: 2, angle: -2, seed: 9),
      _furStrokes(_mirror(blobPath(ear)), 5, len: 2, angle: -1.1, seed: 10),
      for (final p in const [
        Offset(43, 57.2),
        Offset(41.4, 58.6),
        Offset(44.4, 59)
      ]) ...[
        _dot(p.dx, p.dy, 0.4),
        _dot(100 - p.dx, p.dy, 0.4),
      ],
    ]),
  ]);
}

DrawingGuide _dog() {
  const ear = [
    Offset(35.5, 25.5),
    Offset(28, 24.5),
    Offset(21, 29),
    Offset(17, 40),
    Offset(18, 52),
    Offset(22.5, 57.5),
    Offset(27.5, 55),
    Offset(30.5, 47),
    Offset(33.2, 39),
  ];
  const neck = [
    Offset(28, 56.2),
    Offset(26.4, 66),
    Offset(23.4, 77),
    Offset(19, 88)
  ];
  final neckArea = blobPath([
    ...neck,
    for (final p in neck.reversed) Offset(100 - p.dx, p.dy),
    const Offset(62, 64),
    const Offset(50, 70),
    const Offset(38, 64),
  ]);
  final nose = blobPath(const [
    Offset(44.4, 51),
    Offset(50, 49.4),
    Offset(55.6, 51),
    Offset(55, 54.4),
    Offset(50, 56.4),
    Offset(45, 54.4),
  ]);
  return DrawingGuide('Dog', '🐶', [
    GuideStep('Draw a circle and a cross in it ⭕', [
      _helpCircle(50, 38, 18),
      _helpLine(const [Offset(50, 18), Offset(50, 70)]),
      _helpLine(const [Offset(32, 40), Offset(68, 40)]),
    ]),
    GuideStep('Draw a cup shape under it for the snout 🐶', [
      GuideShape(
          polyPath(const [
            Offset(35, 48),
            Offset(40, 68),
            Offset(60, 68),
            Offset(65, 48)
          ], close: false),
          kind: GuideKind.guide),
    ]),
    GuideStep('Draw the head and the round cheeks ✏️', [
      _smooth(const [
        Offset(35.5, 25.5),
        Offset(42, 21),
        Offset(50, 20),
        Offset(58, 21),
        Offset(64.5, 25.5),
      ]),
      for (final s in [
        _smooth(const [
          Offset(33.2, 39),
          Offset(33.6, 46),
          Offset(36, 53.5),
          Offset(40, 60)
        ]),
        _smooth(const [
          Offset(40, 60),
          Offset(43.6, 64.2),
          Offset(47.8, 64.2),
          Offset(50, 61.6)
        ]),
        _smooth(const [Offset(43.4, 64.4), Offset(45.6, 68), Offset(50, 69.2)]),
      ]) ...[s, _flip(s)],
    ]),
    GuideStep('Add two big floppy ears 👂', [
      _smooth(ear),
      _flip(_smooth(ear)),
    ]),
    GuideStep('Add a big nose and a mouth 👃', [
      GuideShape(nose),
      _dot(47.6, 53.4, 0.9),
      _dot(52.4, 53.4, 0.9),
      _line(const [Offset(50, 56.4), Offset(50, 61.6)]),
    ]),
    GuideStep('Add kind eyes and eyebrows 👀', [
      for (final s in [
        _smooth(const [Offset(37, 40.4), Offset(41, 37.8), Offset(45, 40)]),
        _smooth(const [Offset(37.6, 41.4), Offset(41, 43), Offset(44.6, 41.2)]),
        _fine(const [Offset(37, 35.4), Offset(41, 33.8), Offset(45, 34.8)]),
      ]) ...[s, _flip(s)],
      for (final x in [41.0, 59.0]) ...[
        _dot(x, 40.4, 2.1),
        _shine(x + 0.7, 39.6, 0.7),
      ],
    ]),
    GuideStep('Draw the neck and a fluffy chest 🐕', [
      _smooth(neck),
      _flip(_smooth(neck)),
      _fluffy(const [
        Offset(32, 76),
        Offset(41, 81),
        Offset(50, 82.5),
        Offset(59, 81),
        Offset(68, 76),
      ], inside: circlePath(50, 62, 19), every: 7, depth: 2.6),
    ]),
    GuideStep('Rub out the helper lines and add fur ✏️', [
      _hatch(nose, angle: 0.6, gap: 0.8, cross: true),
      _furStrokes(blobPath(ear), 16, len: 3.2, angle: 1.8, seed: 3),
      _furStrokes(_mirror(blobPath(ear)), 16, len: 3.2, angle: 1.3, seed: 4),
      _furStrokes(_minus(neckArea, circlePath(50, 60, 12)), 30,
          len: 3.4, angle: 1.7, seed: 5),
      _furStrokes(
          blobPath(const [
            Offset(40, 23),
            Offset(50, 21.6),
            Offset(60, 23),
            Offset(56, 31),
            Offset(44, 31),
          ]),
          9,
          len: 2.6,
          angle: -1.57,
          seed: 6),
      _fine(const [Offset(50, 24), Offset(50, 31)]),
      for (final p in const [
        Offset(44.2, 57.6),
        Offset(42.6, 59),
        Offset(45.4, 59.6)
      ]) ...[
        _dot(p.dx, p.dy, 0.4),
        _dot(100 - p.dx, p.dy, 0.4),
      ],
      _hatch(_minus(ellipsePath(50, 68, 13, 5), ellipsePath(50, 65, 13, 5)),
          angle: 1.2, gap: 1.2),
    ]),
  ]);
}

DrawingGuide _penguin() {
  final body = blobPath(const [
    Offset(50, 13),
    Offset(61, 15.5),
    Offset(67.5, 24),
    Offset(68.5, 34),
    Offset(71, 44),
    Offset(74, 56),
    Offset(74.5, 68),
    Offset(70, 80),
    Offset(61, 88),
    Offset(50, 89.5),
    Offset(39, 88),
    Offset(30, 80),
    Offset(25.5, 68),
    Offset(26, 56),
    Offset(29, 44),
    Offset(31.5, 34),
    Offset(32.5, 24),
    Offset(39, 15.5),
  ]);
  final front = blobPath(const [
    Offset(50, 22.5),
    Offset(56.5, 18.5),
    Offset(63, 21),
    Offset(66, 28),
    Offset(65, 37),
    Offset(62.5, 45),
    Offset(67.5, 56),
    Offset(69.5, 68),
    Offset(66.5, 79),
    Offset(59, 85.5),
    Offset(50, 87),
    Offset(41, 85.5),
    Offset(33.5, 79),
    Offset(30.5, 68),
    Offset(32.5, 56),
    Offset(37.5, 45),
    Offset(35, 37),
    Offset(34, 28),
    Offset(37, 21),
    Offset(43.5, 18.5),
  ]);
  const wing = [
    Offset(29.2, 45),
    Offset(22.5, 53),
    Offset(18.5, 63),
    Offset(18, 71),
    Offset(20.5, 73.5),
    Offset(24, 69),
    Offset(25.8, 62),
  ];
  final foot = _smooth(const [
    Offset(39.5, 88.3),
    Offset(35.5, 91.5),
    Offset(36.5, 94),
    Offset(40, 92.6),
    Offset(42.5, 94.6),
    Offset(45.5, 92.8),
    Offset(47.5, 94),
    Offset(47.6, 89.4),
  ]);
  return DrawingGuide('Penguin', '🐧', [
    GuideStep('Draw a circle for the head ⭕', [
      _helpCircle(50, 31, 17),
      _helpLine(const [Offset(33, 31), Offset(67, 31)]),
    ]),
    GuideStep('Draw a big oval under it and a line down the middle 🥚', [
      _helpOval(50, 64, 24, 25),
      _helpLine(const [Offset(50, 12), Offset(50, 91)]),
    ]),
    GuideStep('Draw one smooth line around both shapes ✏️', [GuideShape(body)]),
    GuideStep('Add two flippers and two feet 🪽', [
      _smooth(wing),
      _flip(_smooth(wing)),
      foot,
      _flip(foot),
    ]),
    GuideStep('Draw a big shape for the face and the tummy 🤍', [
      GuideShape(front),
    ]),
    GuideStep('Add shiny eyes, a beak and rosy cheeks 👀', [
      ..._eye(43, 31, 3.1),
      ..._eye(57, 31, 3.1),
      _smooth(const [
        Offset(46.2, 35.6),
        Offset(50, 33.8),
        Offset(53.8, 35.6),
        Offset(50, 39.4),
      ], close: true),
      _smooth(const [Offset(46.8, 35.9), Offset(50, 36.8), Offset(53.2, 35.9)]),
      _blush(38.5, 37),
      _blush(61.5, 37),
    ]),
    GuideStep('Rub out the helper lines and shade the back dark ✏️', [
      _hatch(_minus(body, front), angle: 1.1, gap: 1.1, cross: true),
      _hatch(blobPath(wing), angle: 1.1, gap: 1.1, seed: 2),
      _hatch(_mirror(blobPath(wing)), angle: 1.1, gap: 1.1, seed: 3),
      _hatch(_minus(front, front.shift(const Offset(0, -5))),
          angle: -0.5, gap: 1.8, seed: 4),
      _smooth(const [Offset(50, 13), Offset(48.6, 9.4), Offset(46, 7.6)]),
      _smooth(const [Offset(50, 13), Offset(51.2, 8.6), Offset(54, 6.8)]),
      _fine(const [Offset(26, 95), Offset(34, 95.4)]),
      _fine(const [Offset(52, 95.6), Offset(64, 95)]),
      _fine(const [Offset(68, 93.4), Offset(75, 93)]),
    ]),
  ]);
}

DrawingGuide _giraffe() {
  // A portrait: long spotted neck coming up from the bottom, head turned to
  // the right. The neck lines and the head line meet at the back of the head
  // and at the throat.
  const backNeck = [
    Offset(40, 33),
    Offset(37, 43),
    Offset(33, 56),
    Offset(29, 70),
    Offset(24, 86),
    Offset(19.4, 99),
  ];
  const headLine = [
    Offset(40, 33),
    Offset(43, 24),
    Offset(48, 17.4),
    Offset(54, 16),
    Offset(62, 18.2),
    Offset(70, 21.4),
    Offset(78, 24),
    Offset(85, 28),
    Offset(90.4, 32.6),
    Offset(92.4, 38),
    Offset(89.6, 43.4),
    Offset(83, 45.8),
    Offset(76, 45.6),
    Offset(70, 46.6),
    Offset(65, 50),
  ];

  const frontNeck = [
    Offset(65, 50),
    Offset(62.6, 58),
    Offset(61, 67),
    Offset(61, 77),
    Offset(63, 88),
    Offset(65.6, 99),
  ];

  final silhouette = blobPath([
    ...backNeck.reversed,
    ...headLine.skip(1),
    ...frontNeck.skip(1),
  ]);
  // Patches cover the neck and the back of the head, not the face.
  final coat = _minus(
      _minus(silhouette, rectPath(71, 0, 100, 100)), circlePath(62, 25, 7.5));
  final patches = _patchGrid(coat, spacing: 9.2, r: 4.6, angle: -1.18, seed: 4);
  final back = smoothPath(backNeck).computeMetrics().first;
  // Kept inside the picture: the smooth outline bulges a little past the
  // bottom edge.
  final throat = Path.combine(
      PathOperation.intersect,
      _minus(silhouette, silhouette.shift(const Offset(-5, -4))),
      rectPath(0, 0, 100, 99));

  GuideShape mane(double t) {
    final p = back.getTangentForOffset(back.length * t)!.position;
    return GuideShape(Path()
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(p.dx - 1.5, p.dy - 2.4, p.dx - 4.4, p.dy - 2.4));
  }

  return DrawingGuide('Giraffe', '🦒', [
    GuideStep(
        'Draw a long slanted neck with two lines and an oval for the head 🥚', [
      _helpOval(66, 29, 27, 14, angle: 0.28),
      _helpLine(const [Offset(24, 100), Offset(36, 52), Offset(50, 24)]),
      _helpLine(const [Offset(60, 100), Offset(60, 66), Offset(66, 44)]),
    ]),
    GuideStep('Draw the head with a long, soft nose 🦒', [_smooth(headLine)]),
    GuideStep('Draw the neck down from the head ⬇️', [
      _smooth(backNeck),
      _smooth(frontNeck),
    ]),
    GuideStep('Add two little horns with round tips and an ear 👂', [
      _line(const [Offset(50, 15.6), Offset(47.6, 7)]),
      _circle(47.2, 5.4, 1.9),
      _line(const [Offset(57, 15.4), Offset(55.4, 6.4)]),
      _circle(55.2, 4.8, 1.9),
      _leaf(const Offset(45, 23), const Offset(34, 17), 3.6),
      _smooth(const [Offset(44.6, 22.6), Offset(38, 19.6), Offset(36.4, 18.2)]),
    ]),
    GuideStep('Add a gentle eye with long lashes, a nose and a smile 😊', [
      ..._eye(63.6, 25.4, 3.4),
      _smooth(const [
        Offset(58.6, 24.6),
        Offset(61, 21.6),
        Offset(65.6, 21.2),
        Offset(68.6, 23.6)
      ]),
      for (final (x, y, dx, dy) in const <(double, double, double, double)>[
        (60.2, 22.6, -1.8, -1.8),
        (62.6, 21.6, -0.8, -2.4),
        (65, 21.4, 0.6, -2.4),
        (67.4, 22.4, 1.6, -1.8),
      ])
        _fine([Offset(x, y), Offset(x + dx, y + dy)]),
      _oval(87.4, 31.4, 1.5, 0.9, angle: 0.7),
      _smooth(const [Offset(89.4, 40.2), Offset(84, 39.4), Offset(78, 39.8)]),
      _smooth(const [Offset(60, 33), Offset(66, 38.4), Offset(70, 41.8)]),
    ]),
    GuideStep(
        'Draw patches like a net all over the neck and head 🟫', [patches]),
    GuideStep('Add little hairs along the back of the neck 〰️', [
      for (int i = 0; i < 9; i++) mane(0.05 + 0.1 * i),
      _fine(const [Offset(64, 20), Offset(68, 21)]),
    ]),
    GuideStep('Rub out the helper lines and shade the patches ✏️', [
      _hatch(patches.path, angle: 1.1, gap: 0.75, seed: 3),
      _hatch(throat, angle: 0.5, gap: 1.2, seed: 5),
      _hatch(_minus(ellipsePath(80, 36, 9, 6), ellipsePath(80, 32, 9, 6)),
          angle: 0.4, gap: 0.9, seed: 6),
      _hatch(ellipsePath(87.4, 31.4, 1.4, 0.8), angle: 0.7, gap: 0.5, seed: 7),
    ]),
  ]);
}

DrawingGuide _snowman() => _sketch(
      DrawingGuide('Snowman', '⛄', [
        GuideStep('Draw a big circle at the bottom ⭕', [_circle(50, 76, 16)]),
        GuideStep(
            'Draw a smaller circle on top of it ⭕', [_circle(50, 48, 12)]),
        GuideStep('Draw a small head and a tall hat 🎩', [
          _arc(50, 27, 9, -0.891, math.pi + 1.782),
          _rect(39, 17.5, 61, 20),
          _line(const [
            Offset(43, 17.5),
            Offset(43, 4),
            Offset(57, 4),
            Offset(57, 17.5)
          ]),
          _line(const [Offset(43, 14), Offset(57, 14)]),
        ]),
        GuideStep('Add eyes, a carrot nose and a smile 🥕', [
          ..._eye(46.5, 25, 1.8),
          ..._eye(53.5, 25, 1.8),
          _line(const [Offset(50, 27.5), Offset(62, 30), Offset(50, 31.5)],
              close: true),
          _line(const [Offset(54, 28.6), Offset(54.3, 30.6)]),
          _line(const [Offset(58, 29.3), Offset(58.2, 30.6)]),
          for (final (x, y) in const [
            (45.5, 32.4),
            (47.6, 33.6),
            (50.0, 34.0),
            (52.4, 33.6),
            (54.5, 32.4)
          ])
            _dot(x, y, 0.7),
        ]),
        GuideStep('Add round buttons ⚫', [
          for (final y in const [42.0, 48.0, 54.0, 70.0, 80.0])
            _dot(50, y, 1.8),
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
          for (final (x, y) in const [
            (12.0, 14.0),
            (84.0, 10.0),
            (14.0, 60.0),
            (88.0, 56.0),
            (24.0, 84.0),
            (80.0, 82.0)
          ]) ...[
            _line([Offset(x - 2, y), Offset(x + 2, y)]),
            _line([Offset(x - 1, y - 1.7), Offset(x + 1, y + 1.7)]),
            _line([Offset(x - 1, y + 1.7), Offset(x + 1, y - 1.7)]),
          ],
        ]),
      ]),
      helpText: 'Draw a line down the middle and one for the ground ➖',
      help: [
        _helpLine(const [Offset(50, 2), Offset(50, 94)]),
        _helpLine(const [Offset(4, 92), Offset(96, 92)]),
      ],
      shade: [
        for (final (y, r) in const [(76.0, 16.0), (48.0, 12.0), (27.0, 9.0)])
          _hatch(_minus(circlePath(50, y, r), circlePath(47.4, y - 2, r)),
              angle: 1.1, gap: 1.1, seed: y.toInt()),
        _hatch(rectPath(43, 4, 57, 14),
            angle: 1.1, gap: 1, cross: true, seed: 2),
        _hatch(rectPath(39, 17.5, 61, 20), angle: 1.1, gap: 0.9, seed: 3),
        _hatch(ellipsePath(50, 94.2, 20, 1.6), angle: 0.3, gap: 0.9, seed: 4),
      ],
    );

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
  _lv(3, _lion()),
  _lv(3, _penguin()),
  _lv(3, _giraffe()),
  _lv(3, _snowman()),
];

/// A themed chain of lessons. The first lesson is open; finishing one opens
/// the next (see `unlock.dart`).
class LessonTrack {
  LessonTrack(this.name, this.emoji, List<String> lessonNames)
      : guides = [
          for (final n in lessonNames)
            drawingGuides.firstWhere((g) => g.name == n),
        ];
  final String name;
  final String emoji;
  final List<DrawingGuide> guides;
}

/// Every lesson is in exactly one track, easiest first.
final List<LessonTrack> lessonTracks = [
  LessonTrack(
      'Nature', '🌳', ['Sun', 'Moon', 'Tree', 'Mushroom', 'Flower', 'Snowman']),
  LessonTrack('Things', '🏠', [
    'Apple',
    'House',
    'Sailboat',
    'Ice cream',
    'Car',
    'Train',
    'Robot',
    'Rocket',
  ]),
  LessonTrack('Animals', '🐾', [
    'Fish',
    'Bird',
    'Turtle',
    'Octopus',
    'Butterfly',
    'Penguin',
    'Cat',
    'Bunny',
    'Dog',
    'Giraffe',
    'Lion',
  ]),
];
