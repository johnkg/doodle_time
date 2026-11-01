import 'package:flutter/material.dart';

import '../guide_painter.dart';
import '../guides.dart';
import 'style.dart';

/// Asks where the child wants to draw: true = on paper, false = in the app,
/// null = dialog dismissed.
Future<bool?> askDrawingPlace(BuildContext context, DrawingGuide guide) {
  Widget choice(BuildContext ctx, String label, {required bool paper}) {
    final style = bigButton(minHeight: 72);
    void pick() => Navigator.pop(ctx, paper);
    final text = Text(label, style: const TextStyle(fontSize: 24));
    return SizedBox(
      width: double.infinity,
      child: paper
          ? FilledButton(style: style, onPressed: pick, child: text)
          : FilledButton.tonal(style: style, onPressed: pick, child: text),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${guide.emoji} ${guide.name}',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 28)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          choice(ctx, '📄 On paper', paper: true),
          const SizedBox(height: 12),
          choice(ctx, '✏️ In the app', paper: false),
        ],
      ),
    ),
  );
}

/// "Start over?" with big No / Yes buttons. True only on Yes.
Future<bool> askClearDrawing(BuildContext context) async {
  Widget answer(BuildContext ctx, String label, bool value) {
    final style = bigButton(minWidth: 110);
    void pick() => Navigator.pop(ctx, value);
    final text = Text(label, style: const TextStyle(fontSize: 22));
    return value
        ? FilledButton(style: style, onPressed: pick, child: text)
        : FilledButton.tonal(style: style, onPressed: pick, child: text);
  }

  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Start over? 🧹', style: TextStyle(fontSize: 28)),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [answer(ctx, 'No', false), answer(ctx, 'Yes', true)],
    ),
  );
  return yes == true;
}

/// The lesson picture at full size; tap anywhere to close.
void showBigPicture(BuildContext context, DrawingGuide guide, int step) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: kPictureBackground,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CustomPaint(painter: GuidePreviewPainter(guide, step)),
          ),
        ),
      ),
    ),
  );
}

/// Celebration after the last step of a lesson.
Future<void> showLessonDone(
  BuildContext context, {
  required DrawingGuide guide,
  required bool isNewSticker,
  required DrawingGuide? openedLesson,
  required bool isDailyLesson,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Text(guide.emoji, style: const TextStyle(fontSize: 96)),
          ),
          const SizedBox(height: 8),
          Text(
            'You drew a ${guide.name}! 🎉',
            textAlign: TextAlign.center,
            style: boldText(26),
          ),
          const SizedBox(height: 8),
          Text(isNewSticker ? 'New sticker ⭐' : 'Great job! ⭐',
              style: const TextStyle(fontSize: 20)),
          if (openedLesson != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('🔓 ${openedLesson.name} is open now',
                  style: const TextStyle(fontSize: 20)),
            ),
          if (isDailyLesson) ...[
            const SizedBox(height: 8),
            Text("Today's drawing done! 🌟", style: boldText(20)),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: bigButton(minWidth: 140),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Yay! 🎉', style: TextStyle(fontSize: 22)),
        ),
      ],
    ),
  );
}
