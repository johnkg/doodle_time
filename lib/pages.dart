import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A colorable area. Paths live in a 100 x 100 design space.
class Region {
  const Region(this.path);
  final Path path;
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

Path _rect(double l, double t, double r, double b) =>
    Path()..addRect(Rect.fromLTRB(l, t, r, b));

Path _oval(double l, double t, double r, double b) =>
    Path()..addOval(Rect.fromLTRB(l, t, r, b));

Path _circle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

Path _poly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final o in pts.skip(1)) {
    p.lineTo(o.dx, o.dy);
  }
  p.close();
  return p;
}

ColoringPage _housePage() => ColoringPage('House', '🏠', [
      Region(_rect(0, 0, 100, 100)), // sky
      Region(_rect(0, 75, 100, 100)), // ground
      Region(_rect(25, 45, 75, 75)), // wall
      Region(_poly(const [Offset(20, 45), Offset(50, 22), Offset(80, 45)])), // roof
      Region(_rect(44, 56, 56, 75)), // door
      Region(_rect(30, 52, 40, 62)), // window left
      Region(_rect(60, 52, 70, 62)), // window right
      Region(_circle(84, 16, 9)), // sun
      Region(_rect(85, 60, 89, 76)), // trunk
      Region(_circle(87, 52, 12)), // tree top
    ]);

ColoringPage _fishPage() => ColoringPage('Fish', '🐟', [
      Region(_rect(0, 0, 100, 100)), // water
      Region(_rect(0, 88, 100, 100)), // sand
      Region(_poly(const [Offset(24, 50), Offset(6, 34), Offset(6, 66)])), // tail
      Region(_poly(const [Offset(42, 35), Offset(52, 20), Offset(62, 34)])), // fin
      Region(_oval(20, 32, 78, 68)), // body
      Region(_oval(44, 34, 54, 66)), // stripe
      Region(_circle(68, 46, 4)), // eye
      Region(_circle(88, 30, 5)), // bubble
      Region(_circle(92, 18, 3.5)), // bubble
      Region(_circle(84, 12, 3)), // bubble
    ]);

ColoringPage _flowerPage() {
  final petals = <Region>[
    for (int i = 0; i < 6; i++)
      Region(_circle(
        50 + 16 * math.cos(i * math.pi / 3),
        34 + 16 * math.sin(i * math.pi / 3),
        10,
      )),
  ];
  return ColoringPage('Flower', '🌼', [
    Region(_rect(0, 0, 100, 100)), // sky
    Region(_rect(0, 82, 100, 100)), // grass
    Region(_circle(88, 12, 7)), // sun
    Region(_rect(48, 40, 52, 82)), // stem
    Region(_oval(31, 62, 48, 70)), // leaf left
    Region(_oval(52, 56, 69, 64)), // leaf right
    ...petals,
    Region(_circle(50, 34, 9)), // center
  ]);
}

ColoringPage _rocketPage() => ColoringPage('Rocket', '🚀', [
      Region(_rect(0, 0, 100, 100)), // space
      Region(_circle(12, 14, 3)), // stars
      Region(_circle(80, 10, 3)),
      Region(_circle(10, 48, 3)),
      Region(_circle(90, 62, 3)),
      Region(_circle(82, 88, 3)),
      Region(_circle(14, 86, 3)),
      Region(_circle(84, 30, 9)), // planet
      Region(_poly(const [Offset(44, 72), Offset(56, 72), Offset(50, 94)])), // flame
      Region(_poly(const [Offset(36, 55), Offset(22, 78), Offset(36, 72)])), // fin left
      Region(_poly(const [Offset(64, 55), Offset(78, 78), Offset(64, 72)])), // fin right
      Region(_oval(36, 16, 64, 74)), // body
      Region(_circle(50, 40, 7)), // window
    ]);

ColoringPage _carPage() => ColoringPage('Car', '🚗', [
      Region(_rect(0, 0, 100, 100)), // sky
      Region(_rect(0, 78, 100, 100)), // road
      Region(_circle(85, 15, 9)), // sun
      Region(_poly(const [
        Offset(26, 54),
        Offset(36, 36),
        Offset(66, 36),
        Offset(76, 54),
      ])), // cabin
      Region(_rect(10, 52, 90, 72)), // body
      Region(_poly(const [
        Offset(32, 52),
        Offset(38, 40),
        Offset(48, 40),
        Offset(48, 52),
      ])), // window left
      Region(_poly(const [
        Offset(52, 40),
        Offset(62, 40),
        Offset(70, 52),
        Offset(52, 52),
      ])), // window right
      Region(_circle(28, 74, 10)), // wheel
      Region(_circle(72, 74, 10)), // wheel
      Region(_circle(28, 74, 4)), // hubcap
      Region(_circle(72, 74, 4)), // hubcap
      Region(_circle(86, 60, 3.5)), // light
    ]);

ColoringPage _butterflyPage() => ColoringPage('Butterfly', '🦋', [
      Region(_rect(0, 0, 100, 100)), // sky
      Region(_oval(12, 14, 48, 50)), // wing upper left
      Region(_oval(52, 14, 88, 50)), // wing upper right
      Region(_oval(20, 48, 48, 82)), // wing lower left
      Region(_oval(52, 48, 80, 82)), // wing lower right
      Region(_circle(30, 32, 6)), // spots
      Region(_circle(70, 32, 6)),
      Region(_circle(34, 65, 5)),
      Region(_circle(66, 65, 5)),
      Region(_oval(46, 26, 54, 80)), // body
      Region(_circle(50, 22, 5)), // head
    ]);

/// Half ring (arch) between radii [ri] and [ro], opening downward.
Path _band(double cx, double cy, double ro, double ri) {
  return Path()
    ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: ro), math.pi,
        math.pi, true)
    ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: ri), 0, -math.pi,
        false)
    ..close();
}

ColoringPage _rainbowPage() => ColoringPage('Rainbow', '🌈', [
      Region(_rect(0, 0, 100, 100)), // sky
      Region(_band(50, 72, 44, 38)),
      Region(_band(50, 72, 38, 32)),
      Region(_band(50, 72, 32, 26)),
      Region(_band(50, 72, 26, 20)),
      Region(_band(50, 72, 20, 14)),
      Region(_rect(0, 72, 100, 100)), // grass
      Region(_circle(12, 72, 9)), // clouds
      Region(_circle(24, 74, 8)),
      Region(_circle(88, 72, 9)),
      Region(_circle(76, 74, 8)),
      Region(_circle(86, 14, 8)), // sun
    ]);

ColoringPage _catPage() => ColoringPage('Cat', '🐱', [
      Region(_rect(0, 0, 100, 100)), // wall
      Region(_oval(66, 76, 94, 88)), // tail
      Region(_oval(32, 66, 68, 98)), // body
      Region(_poly(const [Offset(26, 34), Offset(28, 10), Offset(44, 24)])), // ear L
      Region(_poly(const [Offset(74, 34), Offset(72, 10), Offset(56, 24)])), // ear R
      Region(_circle(50, 46, 26)), // head
      Region(_circle(40, 42, 4.5)), // eye L
      Region(_circle(60, 42, 4.5)), // eye R
      Region(_poly(const [Offset(45, 52), Offset(55, 52), Offset(50, 58)])), // nose
    ]);

ColoringPage _boatPage() => ColoringPage('Boat', '⛵', [
      Region(_rect(0, 0, 100, 100)), // sky
      Region(_circle(82, 16, 9)), // sun
      Region(_rect(0, 66, 100, 100)), // sea
      Region(_rect(48, 20, 52, 64)), // mast
      Region(_poly(const [Offset(53, 24), Offset(53, 60), Offset(80, 60)])), // sail R
      Region(_poly(const [Offset(47, 30), Offset(47, 60), Offset(24, 60)])), // sail L
      Region(_poly(const [Offset(52, 20), Offset(52, 28), Offset(64, 24)])), // flag
      Region(_poly(const [
        Offset(18, 62),
        Offset(82, 62),
        Offset(70, 82),
        Offset(30, 82),
      ])), // hull
    ]);

ColoringPage _snowmanPage() => ColoringPage('Snowman', '⛄', [
      Region(_rect(0, 0, 100, 100)), // sky
      Region(_rect(0, 82, 100, 100)), // snow ground
      Region(_circle(14, 20, 3.5)), // snowflakes
      Region(_circle(86, 34, 3.5)),
      Region(_circle(18, 56, 3.5)),
      Region(_circle(82, 10, 3.5)),
      Region(_circle(50, 70, 18)), // bottom
      Region(_circle(50, 47, 13)), // middle
      Region(_circle(50, 28, 10)), // head
      Region(_rect(38, 18, 62, 22)), // hat brim
      Region(_rect(43, 6, 57, 19)), // hat top
      Region(_circle(46, 26, 2.5)), // eyes
      Region(_circle(54, 26, 2.5)),
      Region(_poly(const [Offset(50, 29), Offset(61, 31), Offset(50, 33)])), // nose
      Region(_circle(50, 44, 2.8)), // buttons
      Region(_circle(50, 52, 2.8)),
      Region(_circle(50, 66, 3.2)),
      Region(_circle(50, 76, 3.2)),
    ]);

ColoringPage _iceCreamPage() => ColoringPage('Ice cream', '🍦', [
      Region(_rect(0, 0, 100, 100)), // background
      Region(_oval(28, 88, 72, 98)), // plate
      Region(_poly(const [Offset(34, 52), Offset(66, 52), Offset(50, 94)])), // cone
      Region(_circle(39, 42, 14)), // scoop L
      Region(_circle(61, 42, 14)), // scoop R
      Region(_circle(50, 28, 14)), // scoop top
      Region(_circle(50, 12, 5)), // cherry
    ]);

ColoringPage _turtlePage() => ColoringPage('Turtle', '🐢', [
      Region(_rect(0, 0, 100, 100)), // water
      Region(_rect(0, 88, 100, 100)), // sand
      Region(_oval(32, 66, 44, 84)), // leg
      Region(_oval(56, 66, 68, 84)), // leg
      Region(_poly(const [Offset(30, 56), Offset(14, 62), Offset(30, 64)])), // tail
      Region(_circle(80, 52, 10)), // head
      Region(_oval(26, 36, 74, 74)), // shell
      Region(_poly(const [
        Offset(42, 55),
        Offset(46, 47),
        Offset(54, 47),
        Offset(58, 55),
        Offset(54, 63),
        Offset(46, 63),
      ])), // shell pattern
      Region(_circle(36, 54, 4)), // shell spots
      Region(_circle(64, 54, 4)),
      Region(_circle(83, 49, 2.5)), // eye
    ]);

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
