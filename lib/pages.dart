import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shapes.dart';

/// A colorable area. Paths live in a 100 x 100 design space.
class Region {
  const Region(this.path, {this.details = const []});
  final Path path;

  /// Thin texture lines (fur, scales, bricks) drawn inside this region only.
  /// They are not tappable; a tap on them fills the region.
  final List<Path> details;
}

class ColoringPage {
  const ColoringPage(this.name, this.emoji, this.regions);
  final String name;
  final String emoji;

  /// Draw order: later regions sit on top of earlier ones.
  final List<Region> regions;
}

/// Maps the 100 x 100 design space into a centered square inside [size].
Matrix4 pageMatrix(Size size) {
  final s = math.min(size.width, size.height) / 100;
  final dx = (size.width - 100 * s) / 2;
  final dy = (size.height - 100 * s) / 2;
  return Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(s, s, 1);
}

// ---- builders -----------------------------------------------------------------

Path _union(Iterable<Path> paths) =>
    paths.reduce((a, b) => Path.combine(PathOperation.union, a, b));

Path _minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);

Path _within(Path a, Path b) => Path.combine(PathOperation.intersect, a, b);

/// Clouds, bushes, smoke: overlapping circles merged into one outline.
Path _puffs(List<(double, double, double)> circles) =>
    _union([for (final (x, y, r) in circles) circlePath(x, y, r)]);

/// Ground, hills or sea: a smooth top edge filled down to the page bottom.
Path _below(List<Offset> top) => smoothPath(top)
  ..lineTo(top.last.dx, 100)
  ..lineTo(top.first.dx, 100)
  ..close();

Path _seg(double x1, double y1, double x2, double y2) =>
    polyPath([Offset(x1, y1), Offset(x2, y2)], close: false);

Path _wave(List<Offset> pts) => smoothPath(pts);

/// Leaf from [base] to [tip], [w] wide, bulging evenly on both sides.
Path _leaf(Offset base, Offset tip, double w) {
  final mid = (base + tip) / 2;
  final d = tip - base;
  final n = Offset(-d.dy, d.dx) / d.distance * w;
  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy)
    ..close();
}

/// Middle vein plus side veins for a leaf made by [_leaf].
List<Path> _veins(Offset base, Offset tip, double w) {
  final d = tip - base;
  final n = Offset(-d.dy, d.dx) / d.distance * w * 0.45;
  return [
    _seg(base.dx, base.dy, tip.dx, tip.dy),
    for (final t in [0.3, 0.5, 0.7])
      for (final side in [1.0, -1.0])
        _seg(base.dx + d.dx * t, base.dy + d.dy * t,
            base.dx + d.dx * (t + 0.15) + n.dx * side,
            base.dy + d.dy * (t + 0.15) + n.dy * side),
  ];
}

/// Brick pattern for a wall.
List<Path> _bricks(double l, double t, double r, double b,
    {double h = 4, double w = 8}) {
  final out = <Path>[];
  int row = 0;
  for (double y = t; y < b; y += h, row++) {
    if (y > t) out.add(_seg(l, y, r, y));
    for (double x = l + (row.isOdd ? w / 2 : w); x < r; x += w) {
      out.add(_seg(x, y, x, math.min(y + h, b)));
    }
  }
  return out;
}

/// Rows of little arcs: roof tiles, fish scales, feathers.
List<Path> _scallops(double l, double t, double r, double b, double s) {
  final out = <Path>[];
  int row = 0;
  for (double y = t; y < b; y += s * 0.6, row++) {
    for (double x = l + (row.isOdd ? s / 2 : 0); x < r + s; x += s) {
      out.add(arcPath(x, y, s / 2, 0, math.pi));
    }
  }
  return out;
}

/// Short lines pointing out from a circle, like sun rays.
List<Path> _rays(double cx, double cy, double r1, double r2, int n) => [
      for (int i = 0; i < n; i++)
        _seg(
            cx + r1 * math.cos(i * 2 * math.pi / n),
            cy + r1 * math.sin(i * 2 * math.pi / n),
            cx + r2 * math.cos(i * 2 * math.pi / n),
            cy + r2 * math.sin(i * 2 * math.pi / n)),
    ];

/// Round-petal flower head: [n] petals of a circle with radius [r].
Path _blossom(double cx, double cy, double r, int n) => _union([
      for (final o in ringPoints(cx, cy, r * 0.58, n)) circlePath(o.dx, o.dy, r * 0.42),
      circlePath(cx, cy, r * 0.6),
    ]);

/// Little grass tufts along a line.
List<Path> _tufts(List<Offset> spots) => [
      for (final p in spots)
        polyPath([
          p + const Offset(-1.6, -0.2),
          p + const Offset(-0.6, -3),
          p + const Offset(0, -0.4),
          p + const Offset(0.8, -3.4),
          p + const Offset(1.6, -0.2),
        ], close: false),
    ];

/// Lines crossing a shape both ways: waffle cone, seed head, net.
List<Path> _hatch(double l, double t, double r, double b, double gap) => [
      for (double k = l - (b - t); k < r; k += gap) ...[
        _seg(k, t, k + (b - t), b),
        _seg(k + (b - t), t, k, b),
      ],
    ];

Path _rotate(Path p, double angle, Offset c) {
  final m = Matrix4.translationValues(c.dx, c.dy, 0) *
      Matrix4.rotationZ(angle) *
      Matrix4.translationValues(-c.dx, -c.dy, 0);
  return p.transform(m.storage);
}

Region _turned(Region r, double angle, Offset c) => Region(
      _rotate(r.path, angle, c),
      details: [for (final d in r.details) _rotate(d, angle, c)],
    );

// ---- pages ----------------------------------------------------------------------

ColoringPage _housePage() => ColoringPage('House', '🏠', [
      Region(rectPath(0, 0, 100, 100), details: _rays(86, 13, 9.5, 13.5, 12)),
      Region(circlePath(86, 13, 7.5)), // sun
      Region(_puffs(const [(14, 15, 5), (21, 12, 6.5), (28, 15, 5), (21, 17, 5)])),
      Region(_puffs(const [(50, 9, 3.5), (55, 7, 4.5), (60, 9, 3.5)])),
      Region(_below(const [
        Offset(0, 58), Offset(20, 51), Offset(45, 57), Offset(72, 49),
        Offset(100, 56),
      ])), // far hills
      Region(_below(const [
        Offset(0, 75), Offset(30, 73), Offset(62, 76), Offset(100, 73),
      ]), details: _tufts(const [
        Offset(8, 84), Offset(18, 92), Offset(28, 80), Offset(70, 94),
        Offset(80, 82), Offset(92, 90), Offset(12, 97),
      ])), // lawn
      Region(polyPath(const [
        Offset(45, 78), Offset(53, 78), Offset(61, 100), Offset(37, 100),
      ]), details: [
        ovalPath(45, 80, 51, 83),
        ovalPath(43, 85, 50, 88),
        ovalPath(50, 86, 56, 89),
        ovalPath(41, 92, 48, 96),
        ovalPath(49, 93, 57, 97),
      ]), // stone path
      Region(rectPath(58, 22, 65, 40), details: _bricks(58, 22, 65, 40, w: 3.5)),
      Region(rectPath(57, 19, 66, 23)), // chimney top
      Region(_puffs(const [(63, 14, 2.8), (67, 10, 3.4), (72, 6, 3.6)])), // smoke
      Region(rectPath(28, 46, 70, 78), details: _bricks(28, 46, 70, 78)), // wall
      Region(polyPath(const [Offset(22, 48), Offset(49, 24), Offset(76, 48)]),
          details: _scallops(20, 30, 78, 48, 5)), // roof
      Region(circlePath(49, 38, 3.8), details: [
        _seg(45, 38, 53, 38),
        _seg(49, 34, 49, 42),
      ]), // attic window
      Region(Path()
        ..moveTo(44, 78)
        ..lineTo(44, 63)
        ..arcToPoint(const Offset(54, 63), radius: const Radius.circular(5))
        ..lineTo(54, 78)
        ..close(), details: [
        roundRectPath(46, 63, 52, 69, 1),
        roundRectPath(46, 71, 52, 76, 1),
        circlePath(52.6, 70, 0.8),
      ]), // door
      Region(rectPath(32, 52, 41, 62), details: [
        _seg(36.5, 52, 36.5, 62),
        _seg(32, 57, 41, 57),
      ]), // window left
      Region(rectPath(31, 62, 42, 64.5)), // sill
      Region(rectPath(57, 52, 66, 62), details: [
        _seg(61.5, 52, 61.5, 62),
        _seg(57, 57, 66, 57),
      ]), // window right
      Region(rectPath(56, 62, 67, 64.5)), // sill
      Region(polyPath(const [
        Offset(84, 56), Offset(88, 56), Offset(89, 74), Offset(91, 77),
        Offset(81, 77), Offset(83, 74),
      ]), details: [
        _wave(const [Offset(85, 60), Offset(85.6, 66), Offset(85, 72)]),
        _wave(const [Offset(87, 62), Offset(87.4, 68)]),
      ]), // trunk
      Region(_puffs(const [
        (80, 46, 7), (86, 38, 8), (93, 46, 6), (86, 50, 7), (78, 52, 5),
      ]), details: [
        arcPath(82, 42, 3, 3.6, 1.6),
        arcPath(90, 46, 3, 3.6, 1.6),
        arcPath(84, 51, 2.5, 3.6, 1.6),
      ]), // tree top
      Region(_puffs(const [(8, 72, 5), (14, 70, 6), (20, 73, 4.5)])), // bush
      for (final (x, y) in const [(29.0, 86.0), (35.0, 91.0), (66.0, 89.0), (73.0, 85.0)])
        Region(_blossom(x, y, 3.6, 5), details: [circlePath(x, y, 1.2)]), // flowers
    ]);

ColoringPage _fishPage() {
  final body = blobPath(const [
    Offset(81, 52), Offset(76, 43), Offset(64, 36), Offset(48, 36),
    Offset(34, 42), Offset(25, 49), Offset(25, 55), Offset(34, 61),
    Offset(48, 67), Offset(64, 67), Offset(76, 61),
  ]);
  return ColoringPage('Fish', '🐟', [
    Region(rectPath(0, 0, 100, 100), details: [
      _wave(const [Offset(4, 8), Offset(12, 6), Offset(20, 8), Offset(28, 6)]),
      _wave(const [Offset(60, 6), Offset(68, 4), Offset(76, 6)]),
      _wave(const [Offset(36, 16), Offset(44, 14), Offset(52, 16)]),
    ]), // water
    Region(blobPath(const [
      Offset(6, 88), Offset(4, 76), Offset(8, 66), Offset(5, 56),
      Offset(9, 46), Offset(12, 56), Offset(10, 66), Offset(13, 76),
      Offset(12, 88),
    ]), details: [
      _wave(const [Offset(9, 86), Offset(8, 72), Offset(8, 58), Offset(9, 50)]),
    ]), // seaweed
    Region(blobPath(const [
      Offset(88, 88), Offset(86, 78), Offset(90, 70), Offset(87, 62),
      Offset(91, 56), Offset(94, 64), Offset(92, 72), Offset(95, 80),
      Offset(94, 88),
    ])), // seaweed
    Region(blobPath(const [
      Offset(94, 88), Offset(96, 80), Offset(99, 74), Offset(100, 82),
      Offset(99, 89),
    ])), // seaweed
    Region(_below(const [
      Offset(0, 87), Offset(25, 84), Offset(55, 88), Offset(80, 85),
      Offset(100, 87),
    ]), details: [
      _wave(const [Offset(50, 94), Offset(58, 92), Offset(66, 94)]),
      _wave(const [Offset(4, 96), Offset(12, 94), Offset(20, 96)]),
      ovalPath(60, 97, 63, 99),
      ovalPath(30, 90, 33, 92),
    ]), // sand
    Region(blobPath(const [
      Offset(66, 93), Offset(68, 85), Offset(76, 81), Offset(85, 82),
      Offset(90, 89), Offset(88, 95), Offset(72, 96),
    ]), details: [
      _wave(const [Offset(74, 85), Offset(77, 88), Offset(76, 92)]),
    ]), // rock
    Region(blobPath(starPoints(22, 92, 5.8, 2.6, 5)),
        details: [circlePath(22, 92, 1)]), // starfish
    Region(Path()
      ..moveTo(40, 96)
      ..lineTo(36, 91)
      ..arcToPoint(const Offset(46, 91), radius: const Radius.circular(5.2))
      ..close(), details: [
      _seg(40, 96, 37.5, 89), _seg(40, 96, 40, 86.5), _seg(40, 96, 43, 87.5),
    ]), // shell
    Region(polyPath(const [Offset(13, 22), Offset(7, 17), Offset(7, 27)])),
    Region(ellipsePath(19, 22, 7, 3.6), details: [
      circlePath(23, 21, 0.9),
      _wave(const [Offset(16, 19.5), Offset(15, 22), Offset(16, 24.5)]),
    ]), // little fish
    Region(Path()
      ..moveTo(28, 47)
      ..quadraticBezierTo(18, 40, 7, 36)
      ..quadraticBezierTo(12, 46, 15, 52)
      ..quadraticBezierTo(12, 58, 7, 68)
      ..quadraticBezierTo(18, 64, 28, 57)
      ..close(), details: [
      _seg(26, 52, 10, 39), _seg(26, 52, 13, 46),
      _seg(26, 52, 13, 58), _seg(26, 52, 10, 65),
    ]), // tail
    Region(Path()
      ..moveTo(38, 42)
      ..quadraticBezierTo(42, 26, 56, 22)
      ..quadraticBezierTo(62, 28, 68, 40)
      ..close(), details: [
      _seg(44, 40, 46, 29), _seg(50, 40, 52, 25), _seg(56, 40, 58, 27),
      _seg(62, 40, 62, 32),
    ]), // top fin
    Region(Path()
      ..moveTo(44, 62)
      ..quadraticBezierTo(46, 72, 52, 75)
      ..quadraticBezierTo(56, 70, 60, 64)
      ..close(), details: [_seg(50, 64, 51, 72), _seg(55, 64, 54, 71)]),
    Region(body, details: [
      ..._scallops(32, 40, 62, 66, 5),
      _wave(const [Offset(69, 40), Offset(65, 52), Offset(69, 64)]),
      _wave(const [Offset(81, 52.5), Offset(77.5, 54.5), Offset(74, 53.5)]),
    ]),
    Region(ellipsePath(55, 56, 7.5, 3.6, angle: 0.5), details: [
      _seg(49, 52, 59, 58), _seg(49, 52, 57, 60), _seg(49, 52, 60, 56),
    ]), // side fin
    Region(circlePath(72, 47, 3.8)), // eye
    Region(circlePath(73, 47, 2.2), details: [circlePath(73.6, 46.2, 0.5)]),
    Region(circlePath(87, 38, 3)), // bubbles
    Region(circlePath(91, 28, 2.4)),
    Region(circlePath(86, 18, 3.4), details: [arcPath(86, 18, 2.2, 3.6, 1.2)]),
  ]);
}

ColoringPage _flowerPage() {
  const c = Offset(40, 31);
  return ColoringPage('Flower', '🌻', [
    Region(rectPath(0, 0, 100, 100), details: [
      ..._rays(88, 12, 8, 11.5, 10),
    ]), // sky
    Region(circlePath(88, 12, 6)), // sun
    Region(_puffs(const [(10, 12, 4.5), (17, 9, 6), (24, 12, 4.5), (17, 14, 4)])),
    Region(_below(const [
      Offset(0, 70), Offset(30, 63), Offset(65, 70), Offset(100, 62),
    ])), // hills
    Region(_below(const [
      Offset(0, 82), Offset(40, 80), Offset(70, 83), Offset(100, 80),
    ]), details: [
      ..._tufts(const [
        Offset(6, 90), Offset(26, 95), Offset(56, 92), Offset(78, 97),
        Offset(94, 90),
      ]),
      _seg(16, 84, 16, 76), _seg(86, 86, 86, 78),
    ]), // grass
    Region(polyPath(const [
      Offset(39, 36), Offset(42, 36), Offset(43, 60), Offset(45, 90),
      Offset(41, 90), Offset(39.5, 60),
    ])), // stem
    Region(_leaf(const Offset(41, 66), const Offset(24, 56), 6),
        details: _veins(const Offset(41, 66), const Offset(24, 56), 6)),
    Region(_leaf(const Offset(43, 76), const Offset(60, 64), 6),
        details: _veins(const Offset(43, 76), const Offset(60, 64), 6)),
    for (int i = 0; i < 14; i++)
      Region(
        ellipsePath(c.dx + 13 * math.cos(i * math.pi / 7),
            c.dy + 13 * math.sin(i * math.pi / 7), 6.5, 2.7,
            angle: i * math.pi / 7),
        details: [
          _seg(c.dx + 9 * math.cos(i * math.pi / 7),
              c.dy + 9 * math.sin(i * math.pi / 7),
              c.dx + 17 * math.cos(i * math.pi / 7),
              c.dy + 17 * math.sin(i * math.pi / 7)),
        ],
      ), // petals
    Region(circlePath(c.dx, c.dy, 8.5), details: _hatch(31, 22, 49, 40, 2.6)),
    Region(polyPath(const [
      Offset(71, 50), Offset(73, 50), Offset(74, 88), Offset(70, 88),
    ])), // tulip stem
    Region(_leaf(const Offset(72, 88), const Offset(80, 62), 4),
        details: [_seg(72, 88, 80, 62)]),
    Region(blobPath(const [
      Offset(68, 52), Offset(67, 42), Offset(72, 35), Offset(77, 42),
      Offset(76, 52),
    ])),
    Region(blobPath(const [
      Offset(66, 51), Offset(64.5, 42), Offset(66, 37), Offset(70, 44),
      Offset(72, 53),
    ])),
    Region(blobPath(const [
      Offset(78, 51), Offset(79.5, 42), Offset(78, 37), Offset(74, 44),
      Offset(72, 53),
    ])),
    Region(_blossom(16, 74, 6, 8)), // daisies
    Region(circlePath(16, 74, 2.4)),
    Region(_blossom(86, 76, 6, 8)),
    Region(circlePath(86, 76, 2.4)),
    Region(circlePath(28, 58.5, 2.8), details: [
      _seg(28, 55.7, 28, 61.3),
      circlePath(26.8, 57.6, 0.6),
      circlePath(29.2, 59.6, 0.6),
    ]), // ladybug
    Region(ellipsePath(60, 18, 3, 1.8, angle: -0.5)), // bee wings
    Region(ellipsePath(64, 17, 3, 1.8, angle: 0.5)),
    Region(ellipsePath(62, 22, 4.4, 2.8), details: [
      _seg(60.5, 19, 60.5, 25), _seg(63, 19, 63, 25),
      circlePath(65.2, 21.2, 0.5),
    ]), // bee
  ]);
}

ColoringPage _rocketPage() {
  const pivot = Offset(50, 54);
  const tilt = 0.3;
  final body = blobPath(const [
    Offset(50, 12), Offset(56, 20), Offset(59, 34), Offset(60, 50),
    Offset(59, 66), Offset(56, 74), Offset(44, 74), Offset(41, 66),
    Offset(40, 50), Offset(41, 34), Offset(44, 20),
  ]);
  final rocket = <Region>[
    Region(blobPath(const [
      Offset(43, 76), Offset(45, 86), Offset(50, 98), Offset(55, 86),
      Offset(57, 76),
    ])), // flame
    Region(blobPath(const [
      Offset(46, 76), Offset(48, 84), Offset(50, 90), Offset(52, 84),
      Offset(54, 76),
    ])),
    Region(polyPath(const [
      Offset(44, 72), Offset(56, 72), Offset(58, 79), Offset(42, 79),
    ])), // nozzle
    Region(blobPath(const [
      Offset(41, 56), Offset(34, 64), Offset(31, 77), Offset(36, 76),
      Offset(42, 71),
    ])), // fins
    Region(blobPath(const [
      Offset(59, 56), Offset(66, 64), Offset(69, 77), Offset(64, 76),
      Offset(58, 71),
    ])),
    Region(body, details: [
      _seg(40, 46, 60, 46),
      for (final y in [31.0, 51.0, 66.0])
        for (final x in [44.0, 50.0, 56.0]) circlePath(x, y, 0.5),
    ]),
    Region(_within(body, rectPath(0, 0, 100, 27))), // nose
    Region(_within(body, rectPath(0, 55, 100, 61))), // stripe
    Region(ellipsePath(50, 68, 2.4, 9)), // front fin
    Region(circlePath(50, 37, 7.5)), // window frame
    Region(circlePath(50, 37, 5.2), details: [arcPath(50, 37, 3.4, 3.6, 1.3)]),
  ];
  return ColoringPage('Rocket', '🚀', [
    Region(rectPath(0, 0, 100, 100), details: [
      for (final (x, y) in const [
        (20.0, 30.0), (44.0, 6.0), (72.0, 44.0), (6.0, 92.0), (64.0, 94.0),
        (94.0, 72.0), (34.0, 52.0), (26.0, 84.0),
      ]) ...[_seg(x - 1.5, y, x + 1.5, y), _seg(x, y - 1.5, x, y + 1.5)],
    ]), // space
    Region(_minus(ellipsePath(80, 24, 18, 5, angle: -0.35),
        ellipsePath(80, 24, 13, 2.6, angle: -0.35))), // ring (back)
    Region(circlePath(80, 24, 10), details: [
      _wave(const [Offset(71, 20), Offset(78, 18), Offset(86, 20), Offset(90, 19)]),
      _wave(const [Offset(70, 27), Offset(78, 25), Offset(88, 28)]),
    ]), // planet
    Region(_within(
        _minus(ellipsePath(80, 24, 18, 5, angle: -0.35),
            ellipsePath(80, 24, 13, 2.6, angle: -0.35)),
        _rotate(rectPath(50, 24, 110, 50), -0.35, const Offset(80, 24)))),
    Region(circlePath(14, 68, 8)), // moon
    Region(circlePath(11, 65, 2.4)),
    Region(circlePath(17, 71, 2.8)),
    Region(circlePath(12, 72.5, 2.1)),
    for (final (x, y) in const [
      (12.0, 14.0), (32.0, 16.0), (60.0, 8.0), (92.0, 52.0), (86.0, 88.0),
      (10.0, 44.0), (24.0, 90.0),
    ])
      Region(polyPath(starPoints(x, y, 3.8, 1.7, 5))),
    for (final r in rocket) _turned(r, tilt, pivot),
  ]);
}


ColoringPage _carPage() {
  final body = blobPath(const [
    Offset(9, 71), Offset(8, 62), Offset(11, 55), Offset(24, 52),
    Offset(34, 40), Offset(44, 37.5), Offset(58, 38), Offset(66, 42),
    Offset(73, 51), Offset(86, 54), Offset(92, 58), Offset(93, 66),
    Offset(91, 72), Offset(70, 72.5), Offset(30, 72.5),
  ]);
  Region tire(double x) => Region(circlePath(x, 73, 9));
  Region rim(double x) => Region(circlePath(x, 73, 5.4), details: [
        for (int i = 0; i < 5; i++)
          _seg(x, 73, x + 5.4 * math.cos(i * 2 * math.pi / 5),
              73 + 5.4 * math.sin(i * 2 * math.pi / 5)),
      ]);
  return ColoringPage('Car', '🚗', [
    Region(rectPath(0, 0, 100, 100), details: _rays(14, 12, 8, 11.5, 10)),
    Region(circlePath(14, 12, 6)), // sun
    Region(_puffs(const [(64, 12, 4.5), (71, 9, 6), (78, 12, 4.5), (71, 14, 4)])),
    Region(_below(const [
      Offset(0, 56), Offset(25, 47), Offset(55, 53), Offset(80, 45),
      Offset(100, 51),
    ])), // hills
    Region(rectPath(88.5, 44, 91, 56)), // tree trunk
    Region(_puffs(const [(87, 40, 4.5), (92, 38, 5), (95, 43, 3.5), (90, 44, 4)])),
    Region(rectPath(0, 58, 100, 79), details: _tufts(const [
      Offset(4, 66), Offset(16, 62), Offset(96, 66), Offset(84, 62),
    ])), // grass
    Region(rectPath(0, 79, 100, 82)), // curb
    Region(rectPath(0, 82, 100, 100)), // road
    for (final x in const [4.0, 24.0, 44.0, 64.0, 84.0])
      Region(rectPath(x, 90, x + 10, 92.5)), // lane marks
    Region(body, details: [
      _seg(47.5, 51, 47.5, 70),
      _wave(const [Offset(26, 53), Offset(30, 66), Offset(34, 70)]),
      _wave(const [Offset(71, 52), Offset(69, 64), Offset(64, 70)]),
      roundRectPath(38, 55, 43, 56.6, 0.8),
      roundRectPath(56, 55, 61, 56.6, 0.8),
      arcPath(26, 73, 11, math.pi, math.pi),
      arcPath(74, 73, 11, math.pi, math.pi),
    ]),
    Region(_within(body, rectPath(0, 60, 100, 62.5))), // stripe
    Region(polyPath(const [
      Offset(30, 51), Offset(37, 42), Offset(46, 40), Offset(46, 51),
    ])), // back window
    Region(polyPath(const [
      Offset(49, 51), Offset(49, 40), Offset(58, 40.5), Offset(64, 43),
      Offset(69, 51),
    ]), details: [_seg(52, 49, 58, 42)]), // front window
    Region(ellipsePath(67.5, 48, 2.4, 1.8)), // mirror
    Region(blobPath(const [
      Offset(86, 56.5), Offset(91, 58), Offset(91.5, 62), Offset(87, 61),
    ])), // headlight
    Region(roundRectPath(8.5, 57, 12, 63, 1)), // tail light
    Region(roundRectPath(84, 66, 94, 71, 2)), // bumpers
    Region(roundRectPath(6, 66, 16, 71, 2)),
    tire(26), rim(26), Region(circlePath(26, 73, 2.2)),
    tire(74), rim(74), Region(circlePath(74, 73, 2.2)),
  ]);
}

ColoringPage _butterflyPage() {
  Path mirror(Path p) => p.transform(
      (Matrix4.translationValues(100, 0, 0) * Matrix4.diagonal3Values(-1, 1, 1))
          .storage);
  final upper = blobPath(const [
    Offset(48, 40), Offset(40, 24), Offset(28, 14), Offset(14, 12),
    Offset(8, 18), Offset(10, 30), Offset(18, 42), Offset(32, 48),
    Offset(46, 48),
  ]);
  final lower = blobPath(const [
    Offset(48, 50), Offset(36, 50), Offset(22, 56), Offset(16, 66),
    Offset(20, 76), Offset(30, 80), Offset(40, 74), Offset(46, 64),
  ]);
  final upperVeins = [
    _wave(const [Offset(47, 44), Offset(36, 32), Offset(22, 20)]),
    _wave(const [Offset(47, 46), Offset(30, 38), Offset(14, 26)]),
    _wave(const [Offset(47, 47), Offset(32, 46), Offset(18, 38)]),
  ];
  final lowerVeins = [
    _wave(const [Offset(47, 52), Offset(34, 58), Offset(22, 66)]),
    _wave(const [Offset(47, 54), Offset(36, 66), Offset(28, 76)]),
  ];
  const upperSpots = [(13.0, 17.0), (11.0, 24.0), (14.0, 32.0), (20.0, 15.0)];
  const lowerSpots = [(20.0, 68.0), (24.0, 75.0), (31.0, 77.0)];
  final wings = <Region>[
    Region(upper, details: upperVeins),
    Region(lower, details: lowerVeins),
    Region(ellipsePath(28, 28, 6.5, 4, angle: 0.6)),
    Region(ellipsePath(31, 62, 5, 4, angle: -0.4)),
    for (final (x, y) in upperSpots) Region(circlePath(x, y, 2.2)),
    for (final (x, y) in lowerSpots) Region(circlePath(x, y, 2.2)),
  ];
  return ColoringPage('Butterfly', '🦋', [
    Region(rectPath(0, 0, 100, 100), details: [
      _wave(const [Offset(49, 31), Offset(46, 24), Offset(42, 18)]),
      _wave(const [Offset(51, 31), Offset(54, 24), Offset(58, 18)]),
    ]), // sky
    Region(_puffs(const [(8, 10, 4), (14, 8, 5), (20, 10, 4)])),
    Region(_puffs(const [(80, 10, 4), (86, 8, 5), (92, 10, 4)])),
    Region(_below(const [
      Offset(0, 86), Offset(30, 83), Offset(70, 86), Offset(100, 83),
    ]), details: [
      ..._tufts(const [Offset(30, 92), Offset(44, 96), Offset(60, 93), Offset(70, 98)]),
    ]), // grass
    Region(polyPath(const [Offset(13, 78), Offset(15, 78), Offset(15, 100), Offset(13, 100)])),
    Region(_leaf(const Offset(14, 92), const Offset(4, 84), 3.5)),
    Region(_blossom(14, 76, 7, 6)),
    Region(circlePath(14, 76, 2.8)),
    Region(polyPath(const [Offset(85, 76), Offset(87, 76), Offset(87, 100), Offset(85, 100)])),
    Region(_leaf(const Offset(86, 90), const Offset(96, 82), 3.5)),
    Region(_blossom(86, 74, 7, 6)),
    Region(circlePath(86, 74, 2.8)),
    ...wings,
    for (final r in wings)
      Region(mirror(r.path), details: [for (final d in r.details) mirror(d)]),
    Region(ellipsePath(50, 59, 2.8, 13), details: [
      for (final y in [52.0, 56.0, 60.0, 64.0, 68.0]) _seg(47, y, 53, y),
    ]), // abdomen
    Region(ellipsePath(50, 42, 3.4, 5.6)), // thorax
    Region(circlePath(50, 34, 3.2), details: [
      circlePath(48.6, 33.4, 0.6),
      circlePath(51.4, 33.4, 0.6),
    ]), // head
    Region(circlePath(42, 18, 2.1)), // antenna tips
    Region(circlePath(58, 18, 2.1)),
  ]);
}

/// Half ring (arch) between radii [ri] and [ro], opening downward.
Path _band(double cx, double cy, double ro, double ri) {
  return Path()
    ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: ro), math.pi,
        math.pi, true)
    ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: ri), 0, -math.pi,
        false)
    ..close();
}

/// Pine tree: three stacked triangles; [x] is the middle, [base] the bottom.
Path _pine(double x, double base, double h) => _union([
      for (int i = 0; i < 3; i++)
        polyPath([
          Offset(x - h * (0.42 - i * 0.08), base - h * (0.12 + i * 0.26)),
          Offset(x, base - h * (0.5 + i * 0.25)),
          Offset(x + h * (0.42 - i * 0.08), base - h * (0.12 + i * 0.26)),
        ]),
    ]);

/// A gull far away: two little arcs.
List<Path> _bird(double x, double y) => [
      arcPath(x - 2, y + 1.2, 2, 3.8, 1.9),
      arcPath(x + 2, y + 1.2, 2, 3.7, 1.9),
    ];

ColoringPage _rainbowPage() => ColoringPage('Rainbow', '🌈', [
      Region(rectPath(0, 0, 100, 100), details: [
        ..._rays(88, 11, 7.5, 10.5, 10),
        ..._bird(18, 12),
        ..._bird(26, 8),
        ..._bird(70, 14),
      ]), // sky
      Region(circlePath(88, 11, 5.5)), // sun
      Region(polyPath(const [Offset(0, 72), Offset(0, 46), Offset(22, 30), Offset(46, 72)])),
      Region(polyPath(const [Offset(13.3, 36), Offset(22, 30), Offset(30, 37), Offset(24, 35), Offset(19, 38)])),
      Region(polyPath(const [Offset(52, 72), Offset(80, 26), Offset(100, 50), Offset(100, 72)])),
      Region(polyPath(const [Offset(74.5, 35), Offset(80, 26), Offset(85.5, 33), Offset(81, 31), Offset(77, 36)])),
      for (int i = 0; i < 7; i++) Region(_band(50, 70, 44 - i * 4.0, 40 - i * 4.0)),
      Region(_below(const [
        Offset(0, 72), Offset(30, 69), Offset(70, 71), Offset(100, 69),
      ]), details: _tufts(const [
        Offset(30, 76), Offset(42, 98), Offset(64, 98), Offset(88, 96),
        Offset(6, 98),
      ])), // meadow
      Region(_puffs(const [(4, 69, 5), (11, 66, 6.5), (18, 69, 5), (11, 71, 5)])),
      Region(_puffs(const [(82, 69, 5), (89, 66, 6.5), (96, 69, 5), (89, 71, 5)])),
      Region(ellipsePath(52, 86, 20, 5.5), details: [
        _wave(const [Offset(40, 85), Offset(44, 84), Offset(48, 85)]),
        _wave(const [Offset(54, 88), Offset(58, 87), Offset(62, 88)]),
      ]), // pond
      Region(rectPath(9, 88, 11.5, 93)), // pine trunks
      Region(_pine(10.2, 89, 18)),
      Region(rectPath(88.5, 86, 91, 91)),
      Region(_pine(89.8, 87, 16)),
      Region(rectPath(77.3, 79, 79.9, 85)),
      Region(_pine(78.6, 81, 11)),
      Region(_blossom(24, 92, 3.4, 5), details: [circlePath(24, 92, 1.1)]),
      Region(_blossom(32, 96, 3.4, 5), details: [circlePath(32, 96, 1.1)]),
      Region(_blossom(72, 94, 3.4, 5), details: [circlePath(72, 94, 1.1)]),
    ]);

ColoringPage _catPage() {
  const whiskers = [
    [Offset(44, 43), Offset(34, 41), Offset(22, 40)],
    [Offset(44, 44.5), Offset(33, 45), Offset(22, 46.5)],
    [Offset(56, 43), Offset(66, 41), Offset(78, 40)],
    [Offset(56, 44.5), Offset(67, 45), Offset(78, 46.5)],
  ];
  final whiskerLines = [for (final w in whiskers) _wave(w)];
  return ColoringPage('Cat', '🐱', [
    Region(rectPath(0, 0, 100, 72), details: [
      for (double x = 40; x < 100; x += 8) _seg(x, 0, x, 72),
      ...whiskerLines,
    ]), // wall
    Region(rectPath(6, 8, 32, 40)), // window frame
    Region(rectPath(8.5, 10.5, 29.5, 37.5), details: [
      _seg(19, 10.5, 19, 37.5),
      _seg(8.5, 24, 29.5, 24),
      arcPath(24, 16, 3, 1.2, 3.6),
    ]), // glass
    Region(rectPath(4, 39, 34, 42)), // sill
    Region(rectPath(0, 70, 100, 74)), // baseboard
    Region(rectPath(0, 74, 100, 100), details: [
      _seg(0, 80, 100, 80), _seg(0, 87, 100, 87), _seg(0, 94, 100, 94),
      _seg(20, 74, 20, 80), _seg(64, 80, 64, 87), _seg(36, 87, 36, 94),
      _seg(86, 94, 86, 100),
    ]), // floor
    Region(ellipsePath(50, 90, 40, 8), details: [ellipsePath(50, 90, 35, 5.5)]),
    Region(circlePath(86, 82, 7), details: [
      _wave(const [Offset(80, 78), Offset(86, 80), Offset(92, 78)]),
      _wave(const [Offset(79, 82), Offset(86, 85), Offset(93, 82)]),
      _wave(const [Offset(82, 88), Offset(86, 76), Offset(89, 88)]),
    ]), // yarn
    Region(blobPath(const [
      Offset(62, 85), Offset(72, 84), Offset(80, 76), Offset(83, 66),
      Offset(81, 57), Offset(77, 56), Offset(76, 61), Offset(78, 68),
      Offset(75, 75), Offset(68, 79), Offset(61, 79),
    ]), details: [
      _seg(76, 77, 80, 79), _seg(79, 68, 83, 69), _seg(77, 61, 81, 61),
    ]), // tail
    Region(blobPath(const [
      Offset(50, 48), Offset(62, 53), Offset(68, 64), Offset(70, 76),
      Offset(66, 86), Offset(50, 88), Offset(34, 86), Offset(30, 76),
      Offset(32, 64), Offset(38, 53),
    ]), details: [
      _wave(const [Offset(32, 64), Offset(37, 66), Offset(40, 70)]),
      _wave(const [Offset(68, 64), Offset(63, 66), Offset(60, 70)]),
    ]), // body
    Region(ellipsePath(36, 78, 7, 9, angle: 0.2), details: [
      _wave(const [Offset(31, 74), Offset(35, 75), Offset(38, 78)]),
      _wave(const [Offset(31, 80), Offset(34, 81), Offset(37, 84)]),
    ]), // legs
    Region(ellipsePath(64, 78, 7, 9, angle: -0.2), details: [
      _wave(const [Offset(69, 74), Offset(65, 75), Offset(62, 78)]),
      _wave(const [Offset(69, 80), Offset(66, 81), Offset(63, 84)]),
    ]),
    Region(blobPath(const [
      Offset(44, 55), Offset(50, 57), Offset(56, 55), Offset(57, 65),
      Offset(50, 72), Offset(43, 65),
    ]), details: [
      polyPath(const [Offset(47, 60), Offset(48.5, 62), Offset(50, 60)], close: false),
      polyPath(const [Offset(50, 64), Offset(51.5, 66), Offset(53, 64)], close: false),
    ]), // chest
    Region(roundRectPath(42, 64, 48.5, 86, 3)),
    Region(roundRectPath(51.5, 64, 58, 86, 3)),
    Region(ellipsePath(45, 87, 4.4, 2.8),
        details: [_seg(44, 85.4, 44, 88), _seg(46, 85.4, 46, 88)]),
    Region(ellipsePath(55, 87, 4.4, 2.8),
        details: [_seg(54, 85.4, 54, 88), _seg(56, 85.4, 56, 88)]),
    Region(polyPath(const [Offset(32, 33), Offset(29, 10), Offset(47, 23)])), // ears
    Region(polyPath(const [Offset(34, 28), Offset(31.5, 15), Offset(42, 23)])),
    Region(polyPath(const [Offset(68, 33), Offset(71, 10), Offset(53, 23)])),
    Region(polyPath(const [Offset(66, 28), Offset(68.5, 15), Offset(58, 23)])),
    Region(blobPath(const [
      Offset(50, 21), Offset(60, 23), Offset(68, 30), Offset(70, 38),
      Offset(66, 46), Offset(58, 51), Offset(50, 52), Offset(42, 51),
      Offset(34, 46), Offset(30, 38), Offset(32, 30), Offset(40, 23),
    ]), details: [
      _seg(50, 23, 50, 28),
      _seg(46, 24, 47, 28),
      _seg(54, 24, 53, 28),
      _wave(const [Offset(31, 36), Offset(34, 37), Offset(36, 40)]),
      _wave(const [Offset(69, 36), Offset(66, 37), Offset(64, 40)]),
      ...whiskerLines,
    ]), // head
    Region(blobPath(const [
      Offset(36, 33), Offset(41, 29.5), Offset(46, 33), Offset(41, 36.5),
    ])), // eyes
    Region(ellipsePath(41, 33, 1.5, 3), details: [circlePath(41.6, 31.6, 0.5)]),
    Region(blobPath(const [
      Offset(54, 33), Offset(59, 29.5), Offset(64, 33), Offset(59, 36.5),
    ])),
    Region(ellipsePath(59, 33, 1.5, 3), details: [circlePath(59.6, 31.6, 0.5)]),
    Region(_union([ellipsePath(45.5, 44, 5.5, 4), ellipsePath(54.5, 44, 5.5, 4)]),
        details: [
          for (final (x, y) in const [(43.0, 43.0), (45.0, 45.0), (42.0, 46.0), (57.0, 43.0), (55.0, 45.0), (58.0, 46.0)])
            circlePath(x, y, 0.4),
          _wave(const [Offset(50, 42), Offset(50, 45), Offset(47, 47)]),
          _wave(const [Offset(50, 45), Offset(53, 47)]),
          ...whiskerLines,
        ]), // muzzle
    Region(polyPath(const [Offset(46.5, 38), Offset(53.5, 38), Offset(50, 42.5)])),
    Region(blobPath(const [
      Offset(39, 50), Offset(50, 53), Offset(61, 50), Offset(62, 53.5),
      Offset(50, 57), Offset(38, 53.5),
    ])), // collar
    Region(circlePath(50, 58.5, 2.4), details: [_seg(50, 58.5, 50, 61)]),
  ]);
}

ColoringPage _boatPage() {
  final hull = Path()
    ..moveTo(16, 63)
    ..lineTo(86, 63)
    ..quadraticBezierTo(80, 77, 72, 80)
    ..lineTo(32, 80)
    ..quadraticBezierTo(22, 76, 16, 63)
    ..close();
  final lighthouse = polyPath(const [
    Offset(9.5, 55), Offset(16.5, 55), Offset(15, 36), Offset(11, 36),
  ]);
  return ColoringPage('Boat', '⛵', [
    Region(rectPath(0, 0, 100, 100), details: [
      ..._rays(86, 14, 9, 12.5, 10),
      ..._bird(32, 10),
      ..._bird(40, 15),
      _seg(16, 31, 26, 27),
      _seg(16, 34, 27, 35),
    ]), // sky
    Region(circlePath(86, 14, 7)), // sun
    Region(_puffs(const [(64, 24, 4), (70, 21, 5.5), (76, 24, 4), (70, 26, 3.5)])),
    Region(blobPath(const [
      Offset(0, 66), Offset(0, 56), Offset(8, 53), Offset(18, 53),
      Offset(26, 58), Offset(30, 66),
    ])), // island
    Region(lighthouse),
    Region(_within(lighthouse, rectPath(0, 40, 100, 44))),
    Region(_within(lighthouse, rectPath(0, 48, 100, 52))),
    Region(rectPath(10, 31, 16, 36), details: [_seg(13, 31, 13, 36)]), // lamp
    Region(polyPath(const [Offset(9, 31), Offset(13, 26), Offset(17, 31)])),
    Region(_below(const [
      Offset(0, 64), Offset(25, 62), Offset(50, 65), Offset(75, 62),
      Offset(100, 64),
    ]), details: [
      for (final (x, y) in const [
        (6.0, 72.0), (88.0, 70.0), (10.0, 88.0), (40.0, 92.0), (70.0, 90.0),
        (92.0, 96.0), (24.0, 96.0),
      ])
        _wave([Offset(x, y), Offset(x + 3, y - 1.5), Offset(x + 6, y)]),
    ]), // sea
    Region(roundRectPath(38, 56, 58, 66, 1.5), details: [
      circlePath(43, 60, 1.4), circlePath(48, 60, 1.4), circlePath(53, 60, 1.4),
    ]), // cabin
    Region(rectPath(49, 8, 51.5, 63)), // mast
    Region(Path()
      ..moveTo(52, 14)
      ..quadraticBezierTo(68, 32, 78, 53)
      ..lineTo(52, 53)
      ..close(), details: [
      _seg(52, 24, 60, 23), _seg(52, 34, 66, 33), _seg(52, 44, 72, 43),
    ]), // main sail
    Region(rectPath(51, 53.2, 79, 55)), // boom
    Region(Path()
      ..moveTo(48, 16)
      ..quadraticBezierTo(36, 36, 24, 56)
      ..lineTo(48, 56)
      ..close()), // jib
    Region(polyPath(const [Offset(51.5, 8), Offset(62, 11.5), Offset(51.5, 15)])),
    Region(hull, details: [
      _seg(16, 68, 90, 68),
    ]),
    Region(_within(hull, rectPath(0, 73, 100, 76.5))), // stripe
    for (final x in const [36.0, 48.0, 60.0])
      Region(circlePath(x, 69.5, 2.3)), // portholes
    Region(roundRectPath(85, 70, 91, 78, 2.5)), // buoy
    Region(_within(roundRectPath(85, 70, 91, 78, 2.5), rectPath(0, 73, 100, 75))),
  ]);
}

ColoringPage _snowmanPage() => ColoringPage('Snowman', '⛄', [
      Region(rectPath(0, 0, 100, 100), details: [
        for (final (x, y) in const [
          (8.0, 10.0), (24.0, 22.0), (14.0, 40.0), (76.0, 8.0), (90.0, 24.0),
          (84.0, 44.0), (32.0, 6.0), (68.0, 30.0), (6.0, 56.0), (94.0, 60.0),
        ]) ...[
          _seg(x - 1.6, y, x + 1.6, y),
          _seg(x - 0.9, y - 1.4, x + 0.9, y + 1.4),
          _seg(x - 0.9, y + 1.4, x + 0.9, y - 1.4),
        ],
        // stick fingers poke past the arms
        _seg(24, 39, 21, 33), _seg(24, 39, 19, 39),
        _seg(76, 39, 79, 33), _seg(76, 39, 81, 39),
      ]), // sky
      Region(_below(const [
        Offset(0, 66), Offset(30, 58), Offset(60, 64), Offset(100, 56),
      ])), // far hills
      Region(rectPath(11, 72, 14, 78)),
      Region(_pine(12.5, 74, 26), details: [
        _wave(const [Offset(6, 62), Offset(9, 61), Offset(12, 62)]),
        _wave(const [Offset(13, 54), Offset(16, 53), Offset(18, 54)]),
      ]),
      Region(rectPath(86, 68, 89, 74)),
      Region(_pine(87.5, 70, 24)),
      Region(rectPath(73.6, 61, 76.4, 67)),
      Region(_pine(75, 63, 14)),
      Region(_below(const [
        Offset(0, 80), Offset(50, 78), Offset(100, 81),
      ]), details: [
        for (final (x, y) in const [(20.0, 88.0), (26.0, 92.0), (18.0, 96.0), (80.0, 90.0), (74.0, 95.0)])
          ovalPath(x, y, x + 2.4, y + 3.4),
      ]), // snow
      Region(polyPath(const [
        Offset(39, 49), Offset(23, 38.5), Offset(22.5, 40.5), Offset(38, 52),
      ])), // arms
      Region(polyPath(const [
        Offset(61, 49), Offset(77, 38.5), Offset(77.5, 40.5), Offset(62, 52),
      ])),
      Region(circlePath(50, 75, 17), details: [arcPath(50, 75, 13, 3.6, 1.2)]),
      Region(circlePath(50, 51, 12.5), details: [
        _seg(56, 57.5, 56, 60), _seg(58, 57.5, 58, 60), _seg(60, 57.5, 60, 60),
      ]),
      Region(circlePath(50, 31, 9.5), details: [
        for (final (x, y) in const [
          (45.5, 35.4), (47.6, 36.6), (50.0, 37.0), (52.4, 36.6), (54.5, 35.4),
        ])
          circlePath(x, y, 0.5), // coal smile
      ]), // head
      Region(blobPath(const [
        Offset(40, 39), Offset(50, 41.5), Offset(60, 39), Offset(61, 43),
        Offset(50, 46), Offset(39, 43),
      ]), details: [_seg(44, 40.5, 44, 44.8), _seg(56, 40.5, 56, 44.8)]), // scarf
      Region(polyPath(const [
        Offset(53, 43), Offset(59, 43), Offset(61, 57.5), Offset(55, 57.5),
      ]), details: [_seg(54, 48, 59.8, 48), _seg(54.5, 53, 60.5, 53)]),
      Region(roundRectPath(38.5, 21, 61.5, 24, 1.5)), // hat
      Region(rectPath(43, 6, 57, 22)),
      Region(rectPath(43, 16, 57, 20)), // hat band
      Region(circlePath(46.5, 29, 2.1)), // eyes
      Region(circlePath(53.5, 29, 2.1)),
      Region(polyPath(const [Offset(50, 31.5), Offset(63, 34), Offset(50, 36)]),
          details: [_seg(54, 32.5, 54.5, 35), _seg(58, 33.2, 58.4, 34.8)]),
      for (final y in const [47.0, 54.0, 67.0, 78.0]) Region(circlePath(50, y, 2.3)),
    ]);

ColoringPage _iceCreamPage() {
  final top = blobPath(const [
    Offset(38, 36), Offset(37, 28), Offset(42, 20), Offset(50, 17),
    Offset(58, 20), Offset(63, 28), Offset(62, 36), Offset(58, 38),
    Offset(55, 36), Offset(52, 40), Offset(48, 36), Offset(44, 39),
  ]);
  List<Path> sprinkles(double x, double y) => [
        _seg(x, y, x + 2, y + 1),
        _seg(x + 5, y - 3, x + 6, y - 1),
        _seg(x + 9, y + 1, x + 11, y),
        _seg(x + 3, y + 5, x + 4.5, y + 6.5),
      ];
  return ColoringPage('Ice cream', '🍦', [
    Region(rectPath(0, 0, 100, 76), details: [
      for (double y = 6; y < 76; y += 10)
        for (double x = (y ~/ 10).isOdd ? 10 : 4; x < 100; x += 12)
          circlePath(x, y, 1.6),
      _wave(const [Offset(51, 6), Offset(52, 2), Offset(56, 0)]),
    ]), // wall
    Region(rectPath(0, 76, 100, 100), details: [
      _wave(const [Offset(0, 84), Offset(20, 83), Offset(40, 85)]),
      _wave(const [Offset(60, 96), Offset(80, 95), Offset(100, 97)]),
      _wave(const [Offset(4, 94), Offset(16, 93), Offset(24, 95)]),
    ]), // table
    Region(ellipsePath(50, 89, 32, 7.5), details: [ellipsePath(50, 89, 26, 5)]),
    Region(ellipsePath(66, 88, 5, 1.8)), // puddle
    Region(_rotate(roundRectPath(29, 10, 34, 32, 1), -0.45, const Offset(31, 30)),
        details: [_rotate(_union(_hatch(29, 10, 34, 32, 3)), -0.45, const Offset(31, 30))]), // wafer
    Region(polyPath(const [Offset(34, 53), Offset(66, 53), Offset(50, 92)]),
        details: _hatch(30, 53, 70, 92, 5)), // cone
    Region(roundRectPath(32, 49, 68, 56, 2.5)), // cone rim
    Region(blobPath(const [
      Offset(28, 48), Offset(27, 40), Offset(32, 32), Offset(40, 30),
      Offset(48, 33), Offset(50, 40), Offset(48, 48), Offset(45, 53),
      Offset(43, 50), Offset(40, 55), Offset(37, 50), Offset(33, 52),
    ]), details: sprinkles(31, 38)), // scoop left
    Region(blobPath(const [
      Offset(72, 48), Offset(73, 40), Offset(68, 32), Offset(60, 30),
      Offset(52, 33), Offset(50, 40), Offset(52, 48), Offset(55, 53),
      Offset(57, 50), Offset(60, 55), Offset(63, 50), Offset(67, 52),
    ]), details: sprinkles(56, 40)), // scoop right
    Region(top, details: sprinkles(41, 31)),
    Region(blobPath(const [
      Offset(40, 26), Offset(44, 20), Offset(50, 18), Offset(56, 20),
      Offset(60, 26), Offset(57, 28), Offset(54, 26), Offset(51, 31),
      Offset(48, 26), Offset(44, 29),
    ])), // sauce
    Region(_puffs(const [(50, 15, 4.4), (45.5, 17, 3.6), (54.5, 17, 3.6)]),
        details: [arcPath(50, 16, 2.4, 3.4, 2.6)]), // cream
    Region(circlePath(51, 9, 3.6), details: [arcPath(51, 9, 2.2, 3.6, 1.2)]), // cherry
  ]);
}

ColoringPage _turtlePage() {
  Path hex(double cx, double cy, double r) => polyPath([
        for (int i = 0; i < 6; i++)
          Offset(cx + r * math.cos(i * math.pi / 3), cy + r * math.sin(i * math.pi / 3)),
      ]);
  return ColoringPage('Turtle', '🐢', [
    Region(rectPath(0, 0, 100, 100), details: [
      _seg(20, 0, 34, 30), _seg(34, 0, 46, 22), _seg(74, 0, 84, 18),
      for (final (x, y) in const [(56.0, 13.0), (60.0, 14.0), (64.0, 14.0), (68.0, 13.0)])
        _wave([Offset(x, y), Offset(x + 1, y + 4), Offset(x - 1, y + 8), Offset(x, y + 12)]),
    ]), // water
    Region(Path()
      ..moveTo(54, 14)
      ..arcToPoint(const Offset(70, 14), radius: const Radius.circular(8))
      ..quadraticBezierTo(66, 12, 62, 14)
      ..quadraticBezierTo(58, 12, 54, 14)
      ..close(), details: [circlePath(60, 10, 0.8), circlePath(65, 9, 0.6)]), // jellyfish
    Region(blobPath(const [
      Offset(6, 90), Offset(4, 78), Offset(8, 68), Offset(5, 58),
      Offset(9, 50), Offset(12, 58), Offset(10, 68), Offset(13, 78),
      Offset(12, 90),
    ]), details: [_wave(const [Offset(9, 88), Offset(8, 72), Offset(8.5, 56)])]),
    Region(_union([
      roundRectPath(84, 70, 89, 92, 2.5),
      roundRectPath(78, 76, 82, 88, 2),
      roundRectPath(91, 74, 95, 90, 2),
      roundRectPath(79, 84, 94, 90, 2),
    ]), details: [circlePath(86.5, 74, 0.8), circlePath(80, 80, 0.7), circlePath(93, 78, 0.7)]), // coral
    Region(_below(const [
      Offset(0, 88), Offset(30, 85), Offset(60, 89), Offset(100, 86),
    ]), details: [
      _wave(const [Offset(20, 94), Offset(28, 92), Offset(36, 94)]),
      _wave(const [Offset(54, 96), Offset(62, 94), Offset(70, 96)]),
    ]), // sand
    Region(blobPath(const [
      Offset(36, 92), Offset(40, 86), Offset(50, 85), Offset(56, 90), Offset(50, 95),
    ])), // rock
    Region(polyPath(const [Offset(15, 16), Offset(10, 12.5), Offset(10, 19.5)])),
    Region(ellipsePath(20, 16, 6, 3.2), details: [circlePath(23.5, 15.2, 0.7)]),
    Region(polyPath(const [Offset(27, 26), Offset(22, 22.5), Offset(22, 29.5)])),
    Region(ellipsePath(32, 26, 6, 3.2), details: [circlePath(35.5, 25.2, 0.7)]),
    Region(_leaf(const Offset(62, 40), const Offset(52, 15), 6),
        details: _veins(const Offset(62, 40), const Offset(52, 15), 6)),
    Region(_leaf(const Offset(62, 62), const Offset(52, 85), 6),
        details: _veins(const Offset(62, 62), const Offset(52, 85), 6)),
    Region(_leaf(const Offset(34, 40), const Offset(20, 30), 4)),
    Region(_leaf(const Offset(34, 62), const Offset(20, 72), 4)),
    Region(polyPath(const [Offset(28, 47.5), Offset(18, 51), Offset(28, 54.5)])), // tail
    Region(ellipsePath(75, 51, 8, 6), details: [
      circlePath(78, 47.5, 1), circlePath(78, 54.5, 1),
      _wave(const [Offset(81, 49), Offset(82.5, 51), Offset(81, 53)]),
    ]), // head
    Region(ellipsePath(47, 51, 22, 17), details: [
      for (int i = 0; i < 16; i++)
        _seg(47 + 19 * math.cos(i * math.pi / 8), 51 + 14.5 * math.sin(i * math.pi / 8),
            47 + 22 * math.cos(i * math.pi / 8), 51 + 17 * math.sin(i * math.pi / 8)),
    ]), // shell rim
    Region(ellipsePath(47, 51, 19, 14.5), details: [
      _seg(38, 46, 32, 40), _seg(38, 56, 32, 62), _seg(56, 46, 62, 40),
      _seg(56, 56, 62, 62), _seg(47, 44, 47, 37), _seg(47, 58, 47, 65),
      _seg(32, 51, 29, 51), _seg(62, 51, 65, 51),
    ]), // shell
    Region(hex(37.5, 51, 5.5)),
    Region(hex(47, 51, 5.5)),
    Region(hex(56.5, 51, 5.5)),
    Region(circlePath(86, 36, 2.6)), // bubbles
    Region(circlePath(90, 28, 2.2)),
    Region(circlePath(86, 20, 3)),
  ]);
}

final List<ColoringPage> coloringPages = [
  _housePage(),
  _fishPage(),
  _flowerPage(),
  _rocketPage(),
  _carPage(),
  _butterflyPage(),
  _rainbowPage(),
  _catPage(),
  _boatPage(),
  _snowmanPage(),
  _iceCreamPage(),
  _turtlePage(),
];
