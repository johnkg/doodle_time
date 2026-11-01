import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../guide_painter.dart';
import '../guides.dart';
import 'style.dart';

/// Everything the lesson panels show and do. The three layouts below
/// (strip, side column, paper) arrange the same parts differently.
class LessonControls {
  const LessonControls({
    required this.guide,
    required this.step,
    required this.paper,
    required this.onHear,
    required this.onTogglePaper,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.onZoomPicture,
  });

  final DrawingGuide guide;
  final int step;

  /// True while the child draws on real paper instead of the canvas.
  final bool paper;

  final VoidCallback onHear;
  final VoidCallback onTogglePaper;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onZoomPicture;

  bool get isFirstStep => step == 0;
  bool get isLastStep => step == guide.steps.length - 1;

  static const double _headerButtonSize = 40;
  static const double _buttonHeight = 48;

  /// Lesson picture; tap it to see it full size.
  Widget picture() => GestureDetector(
        onTap: onZoomPicture,
        child: Container(
          decoration: BoxDecoration(
            color: kPictureBackground,
            borderRadius: BorderRadius.circular(kChoiceRadius),
            border: Border.all(color: Colors.black12, width: kIdleBorderWidth),
          ),
          child: CustomPaint(painter: GuidePreviewPainter(guide, step)),
        ),
      );

  /// Step label with the "hear it", "paper or app" and "close" buttons.
  Widget header() {
    const tight = BoxConstraints.tightFor(
        width: _headerButtonSize, height: _headerButtonSize);
    Widget iconButton(String tooltip, IconData icon, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          constraints: tight,
          padding: EdgeInsets.zero,
          icon: Icon(icon),
          onPressed: onPressed,
        );
    return Row(
      children: [
        Expanded(
          child: Text(
            '${guide.emoji} ${guide.name} · step ${step + 1} of ${guide.steps.length}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: boldText(13, color: Colors.black54),
          ),
        ),
        iconButton('Hear the step', Icons.volume_up, onHear),
        iconButton(
          paper ? 'Draw in the app' : 'Draw on paper',
          paper ? Icons.brush : Icons.description_outlined,
          onTogglePaper,
        ),
        iconButton('Close lesson', Icons.close, onClose),
      ],
    );
  }

  Widget text(double fontSize) =>
      Text(guide.steps[step].text, style: boldText(fontSize));

  /// Back and Next (or Done) buttons.
  Widget buttons() {
    final size =
        FilledButton.styleFrom(minimumSize: const Size(0, _buttonHeight));
    const label = TextStyle(fontSize: 18);
    return Row(
      children: [
        if (!isFirstStep) ...[
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, _buttonHeight)),
              onPressed: onBack,
              child: const Text('⬅️ Back', style: label),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: FilledButton(
            style: size,
            onPressed: onNext,
            child: Text(isLastStep ? 'Done 🎉' : 'Next ➡️', style: label),
          ),
        ),
      ],
    );
  }
}

/// Lesson above the canvas (phones and portrait). The picture is sized by
/// height as well as width so the canvas keeps most of the screen.
class LessonStrip extends StatelessWidget {
  const LessonStrip({super.key, required this.controls, required this.screen});

  final LessonControls controls;
  final Size screen;

  static const double _widthShare = 0.26;
  static const double _heightShare = 0.14;
  static const double _minPicture = 80;
  static const double _maxPicture = 150;
  static const double _textSize = 18;

  @override
  Widget build(BuildContext context) {
    final picture = math
        .min(screen.width * _widthShare, screen.height * _heightShare)
        .clamp(_minPicture, _maxPicture);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 6, kScreenPadding, 0),
      child: Container(
        padding: const EdgeInsets.all(kCardPadding),
        decoration: cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: picture, height: picture, child: controls.picture()),
                const SizedBox(width: kCardPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [controls.header(), controls.text(_textSize)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            controls.buttons(),
          ],
        ),
      ),
    );
  }
}

/// Lesson as a column left of the canvas (wide landscape), so the canvas
/// keeps its full height and the picture can be big.
class LessonSideColumn extends StatelessWidget {
  const LessonSideColumn({super.key, required this.controls});

  final LessonControls controls;

  static const double _textSize = 22;

  /// Column width as a share of the screen, within these limits.
  static double widthFor(double screenWidth) =>
      (screenWidth * 0.27).clamp(280.0, 360.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 6, 0, 6),
      child: Container(
        padding: const EdgeInsets.all(kCardPadding),
        decoration: cardDecoration(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              AspectRatio(aspectRatio: 1, child: controls.picture()),
              const SizedBox(height: kCardPadding),
              controls.header(),
              Align(
                alignment: Alignment.centerLeft,
                child: controls.text(_textSize),
              ),
              const SizedBox(height: 8),
              controls.buttons(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whole-screen lesson for drawing on real paper: big picture, one step at
/// a time, no canvas.
class PaperLesson extends StatelessWidget {
  const PaperLesson({
    super.key,
    required this.controls,
    required this.screen,
    required this.wide,
  });

  final LessonControls controls;
  final Size screen;
  final bool wide;

  static const double _textSize = 24;

  static double infoWidthFor(double screenWidth) =>
      (screenWidth * 0.34).clamp(300.0, 420.0);

  @override
  Widget build(BuildContext context) {
    // A square as big as fits; without the AspectRatio the picture has no
    // size of its own and collapses.
    final picture = Padding(
      padding: const EdgeInsets.all(kScreenPadding),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: cardDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(kCardPadding),
              child: controls.picture(),
            ),
          ),
        ),
      ),
    );
    final info = Padding(
      padding: const EdgeInsets.fromLTRB(
          kScreenPadding, 0, kScreenPadding, kScreenPadding),
      child: Container(
        padding: const EdgeInsets.all(kCardPadding),
        decoration: cardDecoration(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              controls.header(),
              if (controls.isFirstStep)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '📄 Get a pencil and a paper',
                    style: TextStyle(fontSize: 18, color: Colors.deepPurple),
                  ),
                ),
              controls.text(_textSize),
              const SizedBox(height: 8),
              controls.buttons(),
            ],
          ),
        ),
      ),
    );
    if (!wide) return Column(children: [Expanded(child: picture), info]);
    return Row(
      children: [
        Expanded(child: picture),
        SizedBox(
          width: infoWidthFor(screen.width),
          child: Align(alignment: Alignment.center, child: info),
        ),
      ],
    );
  }
}
