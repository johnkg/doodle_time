import 'package:flutter/material.dart';

/// Colors, sizes and small style helpers shared by every screen widget.

const Color kPageBackground = Color(0xFFFFF3D6);
const Color kSelectedTint = Color(0xFFEDE7F6);
const Color kPictureBackground = Color(0xFFFFFDF7);
const Color kSelectedBorder = Colors.deepPurple;
const Color kIdleBorder = Colors.black12;

/// Outer gap between screen sections.
const double kScreenPadding = 12;

/// Inner gap of cards and panels.
const double kCardPadding = 10;

const double kCardRadius = 24;
const double kButtonRadius = 20;
const double kChoiceRadius = 16;

/// Every tappable control is at least this big for small fingers.
const double kTouchTarget = 56;

const double kIdleBorderWidth = 2;
const double kSelectedBorderWidth = 4;

TextStyle boldText(double fontSize, {Color? color}) =>
    TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color);

BoxDecoration cardDecoration({Color color = Colors.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(kCardRadius),
      border: Border.all(color: Colors.black12, width: kIdleBorderWidth),
    );

/// Purple outline for the chosen item, faint gray for the others.
Border choiceBorder({required bool selected}) => Border.all(
      color: selected ? kSelectedBorder : kIdleBorder,
      width: selected ? kSelectedBorderWidth : kIdleBorderWidth,
    );

/// Rounded outline for Material buttons; the border follows [selected].
RoundedRectangleBorder roundedShape({
  double radius = kButtonRadius,
  bool selected = false,
}) =>
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: selected ? kSelectedBorder : kIdleBorder,
        width: selected ? kSelectedBorderWidth : kIdleBorderWidth,
      ),
    );

/// Big dialog button, used for choices a child has to tap.
ButtonStyle bigButton({double minWidth = 0, double minHeight = kTouchTarget}) =>
    FilledButton.styleFrom(minimumSize: Size(minWidth, minHeight));
