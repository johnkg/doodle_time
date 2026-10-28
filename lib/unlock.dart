import 'guides.dart';

/// Progress-set key a grown-up adds to open every lesson.
const unlockAllKey = 'unlock:all';

/// The first lesson of a track is open; each next one opens when the lesson
/// before it is finished (or when a grown-up unlocked everything).
bool isUnlocked(LessonTrack track, int index, Set<String> done) =>
    index == 0 ||
    done.contains(unlockAllKey) ||
    done.contains(track.guides[index - 1].name);

/// The lesson that finishing [guide] opens, or null at the end of a track.
DrawingGuide? lessonAfter(DrawingGuide guide) {
  for (final t in lessonTracks) {
    final i = t.guides.indexWhere((g) => g.name == guide.name);
    if (i >= 0) return i + 1 < t.guides.length ? t.guides[i + 1] : null;
  }
  return null;
}

/// The lesson that has to be finished before [track]'s lesson [index] opens.
DrawingGuide? lessonBefore(LessonTrack track, int index) =>
    index > 0 ? track.guides[index - 1] : null;
