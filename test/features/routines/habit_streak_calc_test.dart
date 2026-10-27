import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/routines/domain/calc/habit_streak_calc.dart';

void main() {
  group('HabitStreakCalc', () {
    int streak(
      Iterable<String> done, {
      Iterable<String> skipped = const [],
      String today = '2026-10-10',
    }) =>
        HabitStreakCalc.currentStreak(
          doneDays: done.toSet(),
          skippedDays: skipped.toSet(),
          todayKey: today,
        );

    test('counts today and consecutive earlier done days', () {
      expect(streak(['2026-10-10', '2026-10-09', '2026-10-08']), equals(3));
    });

    test('allows today to be unmarked until the day ends', () {
      expect(streak(['2026-10-09', '2026-10-08']), equals(2));
    });

    test('an unmarked earlier day breaks the streak', () {
      expect(streak(['2026-10-10', '2026-10-08']), equals(1));
    });

    test('a skipped day is neutral, not a break', () {
      expect(
        streak(['2026-10-10', '2026-10-08'], skipped: ['2026-10-09']),
        equals(2),
      );
    });

    test('skipping today keeps yesterday\'s streak visible', () {
      expect(
        streak(['2026-10-09', '2026-10-08'], skipped: ['2026-10-10']),
        equals(2),
      );
    });

    test('skipped days alone do not create a streak', () {
      expect(
        streak(const [], skipped: ['2026-10-10', '2026-10-09']),
        equals(0),
      );
    });

    test('malformed day key returns zero instead of throwing', () {
      expect(streak(['2026-10-09'], today: 'not-a-day'), equals(0));
    });
  });
}
