/// "Good morning" / "Good afternoon" / "Good evening" for the time of day.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// `1 file` / `2 files` — [singular] when [count] is exactly one.
String countLabel(int count, String singular, String plural) =>
    '$count ${count == 1 ? singular : plural}';
