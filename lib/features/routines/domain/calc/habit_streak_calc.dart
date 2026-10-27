/// Streak rules for the daily routine checklist.
///
/// A skipped day is neutral: it neither adds to nor breaks the streak. Today
/// is also allowed to be unmarked, because the day is not over yet — the Home
/// card should show yesterday's streak until the user either marks today or
/// the next logical day begins. Any earlier unmarked day ends the count.
class HabitStreakCalc {
  static int currentStreak({
    required Set<String> doneDays,
    required Set<String> skippedDays,
    required String todayKey,
  }) {
    final today = _parseDay(todayKey);
    if (today == null) return 0;
    var cursor = today;
    var streak = 0;

    while (true) {
      final key = _keyOf(cursor);
      if (doneDays.contains(key)) {
        streak++;
      } else if (!skippedDays.contains(key)) {
        final isToday = cursor.year == today.year &&
            cursor.month == today.month &&
            cursor.day == today.day;
        if (!isToday) break;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  static DateTime? _parseDay(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String _keyOf(DateTime day) {
    String pad(int value, int width) => '$value'.padLeft(width, '0');
    return '${pad(day.year, 4)}-${pad(day.month, 2)}-${pad(day.day, 2)}';
  }
}
