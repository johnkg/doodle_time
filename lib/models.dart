import 'dart:ui';

enum Tool { brush, eraser, stamp, fill }

double _r(double v) => (v * 10000).round() / 10000;

// Color.value is deprecated in newer Flutter but works in all versions and
// keeps saved drawings readable across upgrades.
int _colorToInt(Color c) {
  // ignore: deprecated_member_use
  return c.value;
}

/// One undoable thing the child did. Points are stored normalized (0..1)
/// so a drawing survives window resizes and rotation.
abstract class DrawOp {
  const DrawOp();

  Map<String, dynamic> toJson();

  /// Returns null for unknown / corrupt entries so old saves never crash.
  static DrawOp? fromJson(Map<String, dynamic> j) {
    try {
      switch (j['t']) {
        case 's':
          return StrokeOp.fromJson(j);
        case 'p':
          return StampOp.fromJson(j);
        case 'f':
          return FillOp.fromJson(j);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class StrokeOp extends DrawOp {
  StrokeOp({
    required this.color,
    required this.width,
    required this.rainbow,
    required this.erase,
    required Offset first,
  }) : points = [first];

  final List<Offset> points;
  final Color color;
  final double width;
  final bool rainbow;
  final bool erase;

  factory StrokeOp.fromJson(Map<String, dynamic> j) {
    final pts = (j['p'] as List).map((e) => (e as num).toDouble()).toList();
    final s = StrokeOp(
      color: Color(j['c'] as int),
      width: (j['w'] as num).toDouble(),
      rainbow: j['r'] as bool,
      erase: j['e'] as bool,
      first: Offset(pts[0], pts[1]),
    );
    for (int i = 2; i + 1 < pts.length; i += 2) {
      s.points.add(Offset(pts[i], pts[i + 1]));
    }
    return s;
  }

  @override
  Map<String, dynamic> toJson() => {
        't': 's',
        'c': _colorToInt(color),
        'w': width,
        'r': rainbow,
        'e': erase,
        'p': [
          for (final o in points) ...[_r(o.dx), _r(o.dy)],
        ],
      };
}

class StampOp extends DrawOp {
  const StampOp({
    required this.emoji,
    required this.center,
    required this.size,
  });

  final String emoji;
  final Offset center; // normalized
  final double size; // logical pixels

  factory StampOp.fromJson(Map<String, dynamic> j) => StampOp(
        emoji: j['m'] as String,
        center: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        size: (j['s'] as num).toDouble(),
      );

  @override
  Map<String, dynamic> toJson() => {
        't': 'p',
        'm': emoji,
        'x': _r(center.dx),
        'y': _r(center.dy),
        's': size,
      };
}

class FillOp extends DrawOp {
  const FillOp({required this.region, required this.color});

  final int region;
  final Color color;

  factory FillOp.fromJson(Map<String, dynamic> j) => FillOp(
        region: j['i'] as int,
        color: Color(j['c'] as int),
      );

  @override
  Map<String, dynamic> toJson() => {
        't': 'f',
        'i': region,
        'c': _colorToInt(color),
      };
}
