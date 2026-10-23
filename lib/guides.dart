import 'dart:math' as math;

import 'package:flutter/material.dart';

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

GuideShape _line(List<Offset> pts, {bool close = false}) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final o in pts.skip(1)) {
    p.lineTo(o.dx, o.dy);
  }
  if (close) p.close();
  return GuideShape(p);
}

GuideShape _circle(double cx, double cy, double r) => GuideShape(
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

GuideShape _dot(double cx, double cy, double r) => GuideShape(
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    fill: true);

GuideShape _oval(double l, double t, double r, double b) =>
    GuideShape(Path()..addOval(Rect.fromLTRB(l, t, r, b)));

GuideShape _rect(double l, double t, double r, double b) =>
    GuideShape(Path()..addRect(Rect.fromLTRB(l, t, r, b)));

GuideShape _arc(double cx, double cy, double r, double start, double sweep) =>
    GuideShape(Path()
      ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep));

GuideShape _curve(Offset a, Offset control, Offset b) => GuideShape(
    Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy));

// ---- lessons (easiest first) ---------------------------------------------------

DrawingGuide _sun() => DrawingGuide('Sun', '☀️', [
      GuideStep('Draw a big circle ⭕', [_circle(50, 50, 18)]),
      GuideStep('Draw short lines all around it ✨', [
        for (int i = 0; i < 8; i++)
          _line([
            Offset(50 + 24 * math.cos(i * math.pi / 4),
                50 + 24 * math.sin(i * math.pi / 4)),
            Offset(50 + 36 * math.cos(i * math.pi / 4),
                50 + 36 * math.sin(i * math.pi / 4)),
          ]),
      ]),
      GuideStep('Add two eyes 👀', [_dot(43, 46, 2.5), _dot(57, 46, 2.5)]),
      GuideStep('Add a big smile 😊', [_arc(50, 52, 9, 0.2, math.pi - 0.4)]),
    ]);

DrawingGuide _house() => DrawingGuide('House', '🏠', [
      GuideStep('Draw a big square ⬜', [_rect(25, 45, 75, 80)]),
      GuideStep('Draw a triangle on top for the roof 🔺', [
        _line(const [Offset(20, 45), Offset(50, 20), Offset(80, 45)]),
      ]),
      GuideStep('Draw a door 🚪', [_rect(44, 60, 56, 80)]),
      GuideStep('Draw two little windows 🪟', [
        _rect(30, 52, 40, 62),
        _rect(60, 52, 70, 62),
      ]),
      GuideStep('Add the sun and the ground ☀️', [
        _circle(85, 15, 7),
        _line(const [Offset(5, 80), Offset(95, 80)]),
      ]),
    ]);

DrawingGuide _fish() => DrawingGuide('Fish', '🐟', [
      GuideStep('Draw a big oval 🥚', [_oval(20, 32, 75, 68)]),
      GuideStep('Add a triangle tail at the back 🔺', [
        _line(const [Offset(22, 50), Offset(6, 36), Offset(6, 64)],
            close: true),
      ]),
      GuideStep('Add a fin on top 🌊', [
        _line(const [Offset(42, 34), Offset(52, 20), Offset(62, 33)]),
      ]),
      GuideStep('Add one eye 👁️', [_dot(65, 46, 3.5)]),
      GuideStep('Add a smile and bubbles 🫧', [
        _arc(68, 54, 6, 0.4, 1.8),
        _circle(86, 30, 4),
        _circle(91, 20, 3),
        _circle(84, 13, 2.5),
      ]),
    ]);

DrawingGuide _flower() => DrawingGuide('Flower', '🌼', [
      GuideStep('Draw a small circle in the middle ⭕', [_circle(50, 34, 8)]),
      GuideStep('Draw round petals all around 🌸', [
        for (int i = 0; i < 6; i++)
          _circle(50 + 16 * math.cos(i * math.pi / 3),
              34 + 16 * math.sin(i * math.pi / 3), 9),
      ]),
      GuideStep('Draw a long line down for the stem 🌱', [
        _line(const [Offset(50, 59), Offset(50, 90)]),
      ]),
      GuideStep('Add two leaves 🍃', [
        _oval(30, 70, 48, 78),
        _oval(52, 64, 70, 72),
      ]),
      GuideStep('Add grass at the bottom 🌿', [
        _line([
          for (int i = 0; i <= 15; i++) Offset(5 + i * 6.0, i.isEven ? 92.0 : 86.0),
        ]),
      ]),
    ]);

DrawingGuide _cat() => DrawingGuide('Cat', '🐱', [
      GuideStep('Draw a big circle for the head ⭕', [_circle(50, 50, 26)]),
      GuideStep('Draw two triangle ears on top 🔺🔺', [
        _line(const [Offset(27, 36), Offset(29, 12), Offset(44, 26)]),
        _line(const [Offset(73, 36), Offset(71, 12), Offset(56, 26)]),
      ]),
      GuideStep('Add two eyes 👀', [_dot(40, 46, 3.5), _dot(60, 46, 3.5)]),
      GuideStep('Add a little triangle nose 🔻', [
        _line(const [Offset(46, 55), Offset(54, 55), Offset(50, 60)],
            close: true),
      ]),
      GuideStep('Add a happy smile 😺', [
        _curve(const Offset(50, 60), const Offset(50, 67), const Offset(43, 66)),
        _curve(const Offset(50, 60), const Offset(50, 67), const Offset(57, 66)),
      ]),
      GuideStep('Add whiskers on both sides 〰️', [
        _line(const [Offset(33, 56), Offset(10, 52)]),
        _line(const [Offset(33, 60), Offset(10, 60)]),
        _line(const [Offset(33, 64), Offset(10, 68)]),
        _line(const [Offset(67, 56), Offset(90, 52)]),
        _line(const [Offset(67, 60), Offset(90, 60)]),
        _line(const [Offset(67, 64), Offset(90, 68)]),
      ]),
    ]);

DrawingGuide _snowman() => DrawingGuide('Snowman', '⛄', [
      GuideStep('Draw a big circle at the bottom ⭕', [_circle(50, 72, 18)]),
      GuideStep('Draw a smaller circle on top of it ⭕', [_circle(50, 48, 13)]),
      GuideStep('Draw a small circle for the head ⭕', [_circle(50, 30, 10)]),
      GuideStep('Add a tall hat 🎩', [
        _rect(38, 19, 62, 22),
        _rect(43, 7, 57, 19),
      ]),
      GuideStep('Add eyes, a pointy nose and buttons 🥕', [
        _dot(46, 28, 2),
        _dot(54, 28, 2),
        _line(const [Offset(50, 31), Offset(61, 33), Offset(50, 35)],
            close: true),
        _dot(50, 44, 2.5),
        _dot(50, 52, 2.5),
        _dot(50, 66, 3),
        _dot(50, 76, 3),
      ]),
      GuideStep('Add two stick arms 🌿', [
        _line(const [Offset(37, 48), Offset(18, 40)]),
        _line(const [Offset(63, 48), Offset(82, 40)]),
      ]),
    ]);

DrawingGuide _apple() => DrawingGuide('Apple', '🍎', [
      GuideStep('Draw a big round circle ⭕', [_circle(50, 58, 26)]),
      GuideStep('Draw a short line on top for the stem 🌿', [
        _line(const [Offset(50, 33), Offset(54, 18)]),
      ]),
      GuideStep('Add a leaf next to the stem 🍃', [_oval(55, 14, 72, 22)]),
      GuideStep('Add a little shine ✨', [_arc(50, 58, 18, 3.4, 0.7)]),
    ]);

DrawingGuide _tree() => DrawingGuide('Tree', '🌳', [
      GuideStep('Draw a tall rectangle for the trunk 🟫', [
        _rect(44, 55, 56, 90),
      ]),
      GuideStep('Draw 3 big round bumps for the leaves 🌳', [
        _circle(50, 35, 18),
        _circle(34, 45, 14),
        _circle(66, 45, 14),
      ]),
      GuideStep('Add some apples 🍎', [
        _dot(42, 38, 3),
        _dot(58, 32, 3),
        _dot(50, 48, 3),
        _dot(34, 48, 3),
        _dot(66, 48, 3),
      ]),
      GuideStep('Add the grass and the sun ☀️', [
        _line(const [Offset(5, 90), Offset(95, 90)]),
        _circle(85, 14, 7),
      ]),
    ]);

DrawingGuide _car() => DrawingGuide('Car', '🚗', [
      GuideStep('Draw a long rectangle for the body 🟦', [_rect(10, 52, 90, 72)]),
      GuideStep('Draw the roof on top ⛰️', [
        _line(const [
          Offset(26, 52),
          Offset(36, 36),
          Offset(66, 36),
          Offset(76, 52),
        ]),
      ]),
      GuideStep('Add two windows 🪟', [
        _line(const [
          Offset(32, 52),
          Offset(38, 40),
          Offset(48, 40),
          Offset(48, 52),
        ], close: true),
        _line(const [
          Offset(52, 40),
          Offset(62, 40),
          Offset(68, 52),
          Offset(52, 52),
        ], close: true),
      ]),
      GuideStep('Draw two big wheels ⭕⭕', [
        _circle(28, 74, 10),
        _circle(72, 74, 10),
      ]),
      GuideStep('Add small circles in the wheels and a light 💡', [
        _circle(28, 74, 4),
        _circle(72, 74, 4),
        _dot(86, 60, 3),
      ]),
    ]);

DrawingGuide _rocket() => DrawingGuide('Rocket', '🚀', [
      GuideStep('Draw a tall oval for the body 🥚', [_oval(36, 16, 64, 74)]),
      GuideStep('Add a round window ⭕', [_circle(50, 40, 7)]),
      GuideStep('Add two triangle fins at the bottom 🔺', [
        _line(const [Offset(36, 55), Offset(22, 78), Offset(36, 72)]),
        _line(const [Offset(64, 55), Offset(78, 78), Offset(64, 72)]),
      ]),
      GuideStep('Add a flame 🔥', [
        _line(const [Offset(44, 74), Offset(50, 94), Offset(56, 74)]),
      ]),
      GuideStep('Add stars all around ⭐', [
        _dot(14, 18, 2.5),
        _dot(84, 12, 2.5),
        _dot(12, 52, 2.5),
        _dot(90, 60, 2.5),
        _dot(80, 88, 2.5),
        _dot(16, 86, 2.5),
      ]),
    ]);

DrawingGuide _butterfly() => DrawingGuide('Butterfly', '🦋', [
      GuideStep('Draw a long thin oval for the body 🥚', [_oval(46, 26, 54, 80)]),
      GuideStep('Draw a small circle for the head ⭕', [_circle(50, 22, 5)]),
      GuideStep('Draw two big round wings on top 🦋', [
        _oval(12, 14, 48, 50),
        _oval(52, 14, 88, 50),
      ]),
      GuideStep('Draw two smaller wings below', [
        _oval(20, 48, 48, 82),
        _oval(52, 48, 80, 82),
      ]),
      GuideStep('Add spots and two feelers ✨', [
        _circle(30, 32, 5),
        _circle(70, 32, 5),
        _circle(34, 65, 4),
        _circle(66, 65, 4),
        _line(const [Offset(48, 18), Offset(40, 6)]),
        _line(const [Offset(52, 18), Offset(60, 6)]),
      ]),
    ]);

DrawingGuide _dog() => DrawingGuide('Dog', '🐶', [
      GuideStep('Draw a big circle for the head ⭕', [_circle(50, 48, 24)]),
      GuideStep('Draw two floppy ears on the sides 🐶', [
        _oval(18, 30, 34, 66),
        _oval(66, 30, 82, 66),
      ]),
      GuideStep('Add two eyes 👀', [_dot(42, 44, 3), _dot(58, 44, 3)]),
      GuideStep('Add a big round nose ⚫', [_dot(50, 55, 4.5)]),
      GuideStep('Add a smiling mouth and a tongue 👅', [
        _line(const [Offset(50, 59), Offset(50, 64)]),
        _curve(const Offset(50, 64), const Offset(44, 72), const Offset(37, 66)),
        _curve(const Offset(50, 64), const Offset(56, 72), const Offset(63, 66)),
        _oval(46, 66, 54, 74),
      ]),
      GuideStep('Add a collar under the head 🔴', [
        _arc(50, 48, 29, math.pi / 4, math.pi / 2),
        _circle(50, 82, 3.5),
      ]),
    ]);

DrawingGuide _robot() => DrawingGuide('Robot', '🤖', [
      GuideStep('Draw a big square for the head ⬜', [_rect(30, 20, 70, 54)]),
      GuideStep('Draw a tall rectangle for the body 🟦', [_rect(32, 58, 68, 92)]),
      GuideStep('Add two square eyes 👀', [
        _rect(38, 29, 46, 37),
        _rect(54, 29, 62, 37),
      ]),
      GuideStep('Add a straight mouth ➖', [
        _line(const [Offset(40, 46), Offset(60, 46)]),
      ]),
      GuideStep('Add an antenna on top 📡', [
        _line(const [Offset(50, 20), Offset(50, 10)]),
        _circle(50, 7, 3),
      ]),
      GuideStep('Add two arms and some buttons 🔘', [
        _rect(16, 62, 32, 70),
        _rect(68, 62, 84, 70),
        _dot(44, 70, 3),
        _dot(56, 70, 3),
        _dot(50, 82, 3),
      ]),
    ]);

DrawingGuide _sailboat() => DrawingGuide('Sailboat', '⛵', [
      GuideStep('Draw a bowl shape for the boat 🥣', [
        _line(const [
          Offset(18, 62),
          Offset(82, 62),
          Offset(70, 80),
          Offset(30, 80),
        ], close: true),
      ]),
      GuideStep('Draw a tall line for the mast ➕', [
        _line(const [Offset(50, 62), Offset(50, 18)]),
      ]),
      GuideStep('Draw a big triangle sail 🔺', [
        _line(const [Offset(53, 22), Offset(53, 58), Offset(80, 58)],
            close: true),
      ]),
      GuideStep('Add a smaller sail on the other side 🔺', [
        _line(const [Offset(47, 30), Offset(47, 58), Offset(26, 58)],
            close: true),
      ]),
      GuideStep('Add waves and the sun 🌊', [
        _curve(const Offset(5, 88), const Offset(15, 82), const Offset(25, 88)),
        _curve(const Offset(25, 88), const Offset(35, 94), const Offset(45, 88)),
        _curve(const Offset(45, 88), const Offset(55, 82), const Offset(65, 88)),
        _curve(const Offset(65, 88), const Offset(75, 94), const Offset(85, 88)),
        _circle(84, 16, 8),
      ]),
    ]);

DrawingGuide _iceCream() => DrawingGuide('Ice cream', '🍦', [
      GuideStep('Draw a triangle pointing down for the cone 🔻', [
        _line(const [Offset(34, 50), Offset(66, 50), Offset(50, 92)],
            close: true),
      ]),
      GuideStep('Draw a big round scoop on top ⭕', [_circle(50, 36, 16)]),
      GuideStep('Add a cherry on top 🍒', [
        _circle(50, 15, 4),
        _line(const [Offset(50, 11), Offset(56, 5)]),
      ]),
      GuideStep('Draw crossing lines on the cone ✖️', [
        _line(const [Offset(41, 56), Offset(55, 74)]),
        _line(const [Offset(59, 56), Offset(45, 74)]),
      ]),
      GuideStep('Add a wavy edge under the scoop 💧', [
        _curve(const Offset(34, 49), const Offset(42, 58), const Offset(50, 49)),
        _curve(const Offset(50, 49), const Offset(58, 58), const Offset(66, 49)),
      ]),
    ]);

DrawingGuide _bird() => DrawingGuide('Bird', '🐦', [
      GuideStep('Draw a big circle for the body ⭕', [_circle(50, 52, 22)]),
      GuideStep('Draw a smaller circle for the head ⭕', [_circle(66, 32, 13)]),
      GuideStep('Add a pointy beak 🔺', [
        _line(const [Offset(78, 30), Offset(92, 34), Offset(78, 38)],
            close: true),
      ]),
      GuideStep('Add an eye and a wing 👁️', [
        _dot(70, 29, 2.5),
        _oval(36, 48, 58, 64),
      ]),
      GuideStep('Add a tail and two legs 🪶', [
        _line(const [Offset(30, 56), Offset(12, 48)]),
        _line(const [Offset(30, 60), Offset(10, 60)]),
        _line(const [Offset(30, 64), Offset(12, 72)]),
        _line(const [Offset(44, 73), Offset(44, 88), Offset(38, 88)]),
        _line(const [Offset(56, 74), Offset(56, 88), Offset(50, 88)]),
      ]),
    ]);

DrawingGuide _turtle() => DrawingGuide('Turtle', '🐢', [
      GuideStep('Draw a big oval for the shell 🥚', [_oval(26, 36, 74, 74)]),
      GuideStep('Draw a round head on the side ⭕', [_circle(80, 52, 10)]),
      GuideStep('Add two legs and a tail 🦶', [
        _oval(32, 66, 44, 84),
        _oval(56, 66, 68, 84),
        _line(const [Offset(28, 56), Offset(14, 62), Offset(28, 64)],
            close: true),
      ]),
      GuideStep('Add an eye and a smile 😊', [
        _dot(83, 49, 2.5),
        _arc(84, 54, 4, 0.3, 1.8),
      ]),
      GuideStep('Draw a pattern on the shell 🔷', [
        _line(const [
          Offset(42, 55),
          Offset(46, 47),
          Offset(54, 47),
          Offset(58, 55),
          Offset(54, 63),
          Offset(46, 63),
        ], close: true),
        _circle(36, 54, 4),
        _circle(64, 54, 4),
      ]),
    ]);

DrawingGuide _penguin() => DrawingGuide('Penguin', '🐧', [
      GuideStep('Draw a big oval for the body 🥚', [_oval(30, 25, 70, 88)]),
      GuideStep('Draw a smaller oval on the belly 🥚', [_oval(38, 44, 62, 84)]),
      GuideStep('Add two eyes 👀', [_dot(43, 34, 2.5), _dot(57, 34, 2.5)]),
      GuideStep('Add a little triangle beak 🔺', [
        _line(const [Offset(46, 38), Offset(54, 38), Offset(50, 44)],
            close: true),
      ]),
      GuideStep('Add two flippers on the sides 🪽', [
        _oval(16, 44, 30, 70),
        _oval(70, 44, 84, 70),
      ]),
      GuideStep('Add two feet at the bottom 🦶', [
        _oval(34, 86, 48, 94),
        _oval(52, 86, 66, 94),
      ]),
    ]);

DrawingGuide _moon() => DrawingGuide('Moon', '🌙', [
      GuideStep('Draw a big circle ⭕', [_circle(50, 50, 28)]),
      GuideStep('Draw two sleepy eyes 😴', [
        _curve(const Offset(34, 46), const Offset(40, 52), const Offset(46, 46)),
        _curve(const Offset(54, 46), const Offset(60, 52), const Offset(66, 46)),
      ]),
      GuideStep('Add a small smile 🙂', [_arc(50, 56, 8, 0.3, math.pi - 0.6)]),
      GuideStep('Add stars all around ⭐', [
        _dot(12, 14, 3),
        _dot(88, 18, 3),
        _dot(10, 70, 3),
        _dot(90, 76, 3),
        _dot(50, 8, 3),
        _dot(50, 92, 3),
      ]),
    ]);

DrawingGuide _mushroom() => DrawingGuide('Mushroom', '🍄', [
      GuideStep('Draw a half circle on top for the cap 🍄', [
        _arc(50, 52, 32, math.pi, math.pi),
        _line(const [Offset(18, 52), Offset(82, 52)]),
      ]),
      GuideStep('Draw a short rectangle for the stem 🟦', [
        _rect(40, 52, 60, 82),
      ]),
      GuideStep('Add round spots on the cap ⚪', [
        _circle(36, 40, 5),
        _circle(52, 32, 6),
        _circle(66, 42, 5),
      ]),
      GuideStep('Add some grass underneath 🌱', [
        _line(const [Offset(10, 84), Offset(90, 84)]),
        _line(const [Offset(24, 84), Offset(22, 76)]),
        _line(const [Offset(30, 84), Offset(32, 74)]),
        _line(const [Offset(72, 84), Offset(70, 76)]),
        _line(const [Offset(78, 84), Offset(80, 74)]),
      ]),
    ]);

DrawingGuide _train() => DrawingGuide('Train', '🚂', [
      GuideStep('Draw a long rectangle for the engine 🟦', [
        _rect(10, 50, 62, 76),
      ]),
      GuideStep('Draw a taller square at the back for the cab ⬜', [
        _rect(12, 32, 34, 50),
      ]),
      GuideStep('Add a chimney on the front ⬛', [_rect(46, 38, 56, 50)]),
      GuideStep('Draw three wheels ⭕⭕⭕', [
        _circle(22, 80, 8),
        _circle(40, 80, 8),
        _circle(56, 80, 8),
      ]),
      GuideStep('Add a window, puffs of smoke and the track 💨', [
        _rect(17, 38, 29, 46),
        _circle(52, 28, 4),
        _circle(58, 20, 5),
        _circle(66, 12, 6),
        _line(const [Offset(5, 90), Offset(95, 90)]),
      ]),
    ]);

DrawingGuide _bunny() => DrawingGuide('Bunny', '🐰', [
      GuideStep('Draw a big circle for the head ⭕', [_circle(50, 58, 22)]),
      GuideStep('Draw two long ovals for the ears 🐰', [
        _oval(34, 8, 46, 42),
        _oval(54, 8, 66, 42),
      ]),
      GuideStep('Add two eyes 👀', [_dot(42, 54, 3), _dot(58, 54, 3)]),
      GuideStep('Add a tiny nose and a smile 😊', [
        _line(const [Offset(47, 62), Offset(53, 62), Offset(50, 66)],
            close: true),
        _curve(const Offset(50, 66), const Offset(45, 73), const Offset(40, 69)),
        _curve(const Offset(50, 66), const Offset(55, 73), const Offset(60, 69)),
      ]),
      GuideStep('Add whiskers on both sides 〰️', [
        _line(const [Offset(34, 64), Offset(14, 60)]),
        _line(const [Offset(34, 68), Offset(14, 70)]),
        _line(const [Offset(66, 64), Offset(86, 60)]),
        _line(const [Offset(66, 68), Offset(86, 70)]),
      ]),
      GuideStep('Add a round body below 🥚', [_oval(32, 78, 68, 98)]),
    ]);

DrawingGuide _octopus() => DrawingGuide('Octopus', '🐙', [
      GuideStep('Draw a big round head ⭕', [_circle(50, 36, 24)]),
      GuideStep('Add two eyes 👀', [_dot(41, 34, 3.5), _dot(59, 34, 3.5)]),
      GuideStep('Add a smile 😊', [_arc(50, 42, 8, 0.3, math.pi - 0.6)]),
      GuideStep('Draw four wavy legs 🐙', [
        _curve(const Offset(32, 56), const Offset(20, 70), const Offset(28, 86)),
        _curve(const Offset(43, 59), const Offset(36, 76), const Offset(44, 92)),
        _curve(const Offset(57, 59), const Offset(64, 76), const Offset(56, 92)),
        _curve(const Offset(68, 56), const Offset(80, 70), const Offset(72, 86)),
      ]),
      GuideStep('Add bubbles 🫧', [
        _circle(82, 20, 4),
        _circle(88, 10, 3),
        _circle(14, 22, 4),
        _circle(10, 34, 3),
      ]),
    ]);

DrawingGuide _giraffe() => DrawingGuide('Giraffe', '🦒', [
      GuideStep('Draw a tall rectangle for the neck 🟦', [_rect(28, 30, 44, 64)]),
      GuideStep('Draw an oval for the head on top 🥚', [_oval(20, 10, 52, 32)]),
      GuideStep('Add two ears and two little horns 👂', [
        _oval(12, 14, 22, 20),
        _oval(50, 14, 60, 20),
        _line(const [Offset(30, 10), Offset(30, 4)]),
        _line(const [Offset(42, 10), Offset(42, 4)]),
        _dot(30, 3, 2),
        _dot(42, 3, 2),
      ]),
      GuideStep('Add two eyes and two nose holes 👀', [
        _dot(30, 19, 2.5),
        _dot(42, 19, 2.5),
        _dot(34, 27, 1.8),
        _dot(39, 27, 1.8),
      ]),
      GuideStep('Add a big oval for the body 🥚', [_oval(24, 56, 88, 78)]),
      GuideStep('Add four long legs 🦵', [
        _line(const [Offset(34, 74), Offset(34, 96)]),
        _line(const [Offset(46, 77), Offset(46, 96)]),
        _line(const [Offset(66, 77), Offset(66, 96)]),
        _line(const [Offset(78, 74), Offset(78, 96)]),
      ]),
      GuideStep('Add spots all over ⚫', [
        _circle(36, 40, 3.5),
        _circle(35, 53, 3),
        _circle(52, 66, 3.5),
        _circle(65, 63, 3.5),
        _circle(77, 68, 3),
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
