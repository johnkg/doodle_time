import 'package:flutter/material.dart';

import 'style.dart';

/// Top-bar button: icon plus label, faded when it can't be used.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  static const double _iconSize = 28;
  static const double _disabledOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final shape = roundedShape();
    return Opacity(
      opacity: onTap == null ? _disabledOpacity : 1,
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: kTouchTarget,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: _iconSize),
                    const SizedBox(width: 6),
                    Text(label, style: boldText(16)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big square tool button (Draw, Erase, Stamp, Fill).
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _side = 72;

  @override
  Widget build(BuildContext context) {
    final shape = roundedShape(radius: 18, selected: selected);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? kSelectedTint : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            width: _side,
            height: _side,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                Text(label, style: boldText(13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable round or square swatch with a selection border. The other
/// choice widgets in this file are thin wrappers around it.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.size,
    required this.onTap,
    required this.decoration,
    required this.margin,
    this.child,
  });

  final double size;
  final VoidCallback onTap;
  final BoxDecoration decoration;
  final double margin;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        margin: EdgeInsets.only(right: margin),
        decoration: decoration,
        child: child,
      ),
    );
  }
}

/// Brush size picker: a dark dot as big as the brush.
class SizeDot extends StatelessWidget {
  const SizeDot({
    super.key,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final bool selected;
  final VoidCallback onTap;

  static const Color _inkColor = Color(0xFF424242);

  @override
  Widget build(BuildContext context) {
    return _Choice(
      size: kTouchTarget,
      margin: 4,
      onTap: onTap,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? kSelectedBorder : Colors.transparent,
          width: kSelectedBorderWidth,
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration:
            const BoxDecoration(color: _inkColor, shape: BoxShape.circle),
      ),
    );
  }
}

BoxDecoration _swatchDecoration({
  required bool selected,
  Color? color,
  Gradient? gradient,
}) =>
    BoxDecoration(
      color: color,
      gradient: gradient,
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? Colors.black : Colors.black12,
        width: selected ? 5 : kIdleBorderWidth,
      ),
    );

const double _swatchSize = 52;
const double _swatchGap = 8;

class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Choice(
        size: _swatchSize,
        margin: _swatchGap,
        onTap: onTap,
        decoration: _swatchDecoration(selected: selected, color: color),
      );
}

/// Picks the rainbow pen: every part of the line gets a new color.
class RainbowDot extends StatelessWidget {
  const RainbowDot({super.key, required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  static const SweepGradient _rainbow = SweepGradient(colors: [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.red,
  ]);

  @override
  Widget build(BuildContext context) => _Choice(
        size: _swatchSize,
        margin: _swatchGap,
        onTap: onTap,
        decoration: _swatchDecoration(selected: selected, gradient: _rainbow),
      );
}

class StampChoice extends StatelessWidget {
  const StampChoice({
    super.key,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Choice(
        size: kTouchTarget,
        margin: _swatchGap,
        onTap: onTap,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kChoiceRadius),
          color: selected ? kSelectedTint : Colors.white,
          border: choiceBorder(selected: selected),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 30)),
      );
}
