/// A short, human description of how long ago [time] was: "just now",
/// "5 minutes ago", "yesterday", "3 weeks ago". [now] is injectable for tests.
String relativeTime(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(time);

  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';

  if (elapsed.inMinutes < 1) return 'just now'; // includes clock skew (negative)
  if (elapsed.inMinutes < 60) return plural(elapsed.inMinutes, 'minute');
  if (elapsed.inHours < 24) return plural(elapsed.inHours, 'hour');
  if (elapsed.inDays == 1) return 'yesterday';
  if (elapsed.inDays < 7) return plural(elapsed.inDays, 'day');
  if (elapsed.inDays < 30) return plural(elapsed.inDays ~/ 7, 'week');
  if (elapsed.inDays < 365) return plural(elapsed.inDays ~/ 30, 'month');
  return plural(elapsed.inDays ~/ 365, 'year');
}
