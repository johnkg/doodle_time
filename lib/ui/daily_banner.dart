import 'package:flutter/material.dart';

import '../guides.dart';
import 'style.dart';

/// "Today's drawing" card shown on a fresh canvas.
class DailyBanner extends StatelessWidget {
  const DailyBanner({
    super.key,
    required this.guide,
    required this.doneToday,
    required this.streak,
    required this.onStart,
  });

  final DrawingGuide guide;
  final bool doneToday;

  /// Days in a row; shown from [_minStreakShown] up.
  final int streak;
  final VoidCallback onStart;

  static const int _minStreakShown = 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 6, kScreenPadding, 0),
      child: Container(
        padding: const EdgeInsets.all(kCardPadding),
        decoration: BoxDecoration(
          color: kSelectedTint,
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(color: kSelectedBorder, width: kIdleBorderWidth),
        ),
        child: Row(
          children: [
            Text(guide.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: kScreenPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doneToday ? '⭐ Done today!' : "🌟 Today's drawing",
                    style: boldText(13, color: Colors.black54),
                  ),
                  Text('Draw ${withArticle(guide.name)}', style: boldText(22)),
                  if (streak >= _minStreakShown)
                    Text('🔥 $streak days in a row',
                        style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: bigButton(minWidth: 88, minHeight: 52),
              onPressed: onStart,
              child: Text(doneToday ? 'Again' : 'Start ▶',
                  style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "a Dog", "an Octopus".
String withArticle(String noun) =>
    '${'AEIOU'.contains(noun[0]) ? 'an' : 'a'} $noun';
