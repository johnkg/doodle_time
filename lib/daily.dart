import 'guides.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Key stored in the progress set when the daily lesson was finished that day.
/// (Lesson stickers are stored by lesson name; day entries start with `day:`.)
String dayKey(DateTime d) => 'day:${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Today's lesson. Depends only on the calendar date, so it is the same on
/// every device with no internet, and walks through all lessons in order.
DrawingGuide dailyGuide(DateTime date, [List<DrawingGuide>? guides]) {
  final list = guides ?? drawingGuides;
  final day = DateTime.utc(date.year, date.month, date.day)
          .millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return list[day % list.length];
}

/// Days in a row the daily lesson was finished, counting back from today
/// (or from yesterday if today is not done yet, so the streak isn't lost
/// before the child has had a chance to draw).
int dailyStreak(Set<String> done, DateTime today) {
  var d = DateTime(today.year, today.month, today.day);
  if (!done.contains(dayKey(d))) {
    d = DateTime(d.year, d.month, d.day - 1);
  }
  var count = 0;
  while (done.contains(dayKey(d))) {
    count++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return count;
}
