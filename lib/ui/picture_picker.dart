import 'package:flutter/material.dart';

import '../guide_painter.dart';
import '../guides.dart';
import '../pages.dart';
import '../unlock.dart';
import 'style.dart';

/// Opens the "Pictures" sheet: lesson paths to learn from, and coloring pages.
///
/// A locked lesson calls [onLockedLesson] with the lesson that opens it. A
/// chosen lesson or page closes the sheet first, then calls [onLesson] or
/// [onPage] (a null page means the blank canvas).
void showPicturePicker(
  BuildContext context, {
  required Set<String> done,
  required void Function(DrawingGuide lessonBefore) onLockedLesson,
  required void Function(DrawingGuide lesson) onLesson,
  required void Function(ColoringPage? page) onPage,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      void choose(VoidCallback action) {
        Navigator.pop(sheetContext);
        action();
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionTitle(
                '✏️ Learn to draw · ⭐ ${drawingGuides.where((g) => done.contains(g.name)).length}/${drawingGuides.length}',
              ),
              for (final track in lessonTracks) ...[
                const SizedBox(height: 12),
                _TrackRow(
                  track: track,
                  done: done,
                  onLockedLesson: onLockedLesson,
                  onLesson: (lesson) => choose(() => onLesson(lesson)),
                ),
              ],
              const SizedBox(height: 20),
              const _SectionTitle('🎨 Color a picture'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _PageChoice(
                    emoji: '📄',
                    label: 'Blank',
                    onTap: () => choose(() => onPage(null)),
                  ),
                  for (final page in coloringPages)
                    _PageChoice(
                      emoji: page.emoji,
                      label: page.name,
                      onTap: () => choose(() => onPage(page)),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: boldText(26));
}

/// One theme: its name and its chain of lessons. Finish a lesson to open
/// the next one.
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.done,
    required this.onLockedLesson,
    required this.onLesson,
  });

  final LessonTrack track;
  final Set<String> done;
  final void Function(DrawingGuide lessonBefore) onLockedLesson;
  final void Function(DrawingGuide lesson) onLesson;

  static const double _linkWidth = 18;
  static const double _linkHeight = 4;

  /// Puts the link line at the middle of the round lesson pictures.
  static const double _linkTop = 42;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${track.emoji} ${track.name}',
          style: boldText(20, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < track.guides.length; i++) ...[
                if (i > 0)
                  Container(
                    width: _linkWidth,
                    height: _linkHeight,
                    margin: const EdgeInsets.only(top: _linkTop),
                    color: Colors.black12,
                  ),
                _lessonNode(i),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _lessonNode(int index) {
    final lesson = track.guides[index];
    final open = isUnlocked(track, index, done);
    return _LessonNode(
      guide: lesson,
      locked: !open,
      done: done.contains(lesson.name),
      onTap: () =>
          open ? onLesson(lesson) : onLockedLesson(lessonBefore(track, index)!),
    );
  }
}

/// One lesson on a track: a round picture of the finished drawing. Locked
/// lessons are faded with a lock; finished ones get a star.
class _LessonNode extends StatelessWidget {
  const _LessonNode({
    required this.guide,
    required this.locked,
    required this.done,
    required this.onTap,
  });

  final DrawingGuide guide;
  final bool locked;
  final bool done;
  final VoidCallback onTap;

  static const double _width = 96;
  static const double _circle = 88;
  static const double _lockedOpacity = 0.15;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: locked ? '${guide.name}, locked' : guide.name,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _width,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: _circle,
                    height: _circle,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? Colors.amber : Colors.black26,
                        width: kSelectedBorderWidth,
                      ),
                    ),
                    child: Opacity(
                      opacity: locked ? _lockedOpacity : 1,
                      child: CustomPaint(
                        painter:
                            GuidePreviewPainter(guide, guide.steps.length - 1),
                      ),
                    ),
                  ),
                  if (locked) const Text('🔒', style: TextStyle(fontSize: 32)),
                  if (done)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text('⭐', style: TextStyle(fontSize: 24)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                guide.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: boldText(16,
                    color: locked ? Colors.black38 : Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageChoice extends StatelessWidget {
  const _PageChoice({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  static const double _side = 104;

  @override
  Widget build(BuildContext context) {
    final shape = roundedShape();
    return Material(
      color: kPageBackground,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          width: _side,
          height: _side,
          // Scale down instead of overflowing (long names, large system font).
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 44)),
                    Text(label, maxLines: 1, style: boldText(16)),
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
