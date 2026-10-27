import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';
import 'package:opennutritracker/features/routines/domain/calc/habit_streak_calc.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';

class GetRoutineDayUsecase {
  final HabitRepository _repository;
  final GetConfigUsecase _getConfig;
  final DateTime Function() _now;

  GetRoutineDayUsecase(
    this._repository,
    this._getConfig, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<RoutineDayEntity> call() async {
    final config = await _getConfig.getConfig();
    final offset = config.dayStartOffsetTotalMinutes;
    final now = _now();
    final day = DayBoundaryCalc.logicalDayOfMinutes(now, offset);
    final todayKey = DayBoundaryCalc.dayKeyOf(now, offset, clockReading: true);

    final habits = await _repository.getHabits();
    final checkins = await _repository.getCheckins();

    final doneByHabit = <String, Set<String>>{};
    final skippedByHabit = <String, Set<String>>{};
    final statusByHabit = <String, HabitStatus>{};
    for (final checkin in checkins) {
      if (checkin.status == HabitStatus.done) {
        (doneByHabit[checkin.habitId] ??= {}).add(checkin.dayKey);
      } else {
        (skippedByHabit[checkin.habitId] ??= {}).add(checkin.dayKey);
      }
      if (checkin.dayKey == todayKey) {
        statusByHabit[checkin.habitId] = checkin.status;
      }
    }

    return RoutineDayEntity(
      day: day,
      habits: [
        for (final habit in habits)
          RoutineHabitEntity(
            habit: habit,
            status: statusByHabit[habit.id],
            streak: HabitStreakCalc.currentStreak(
              doneDays: doneByHabit[habit.id] ?? const {},
              skippedDays: skippedByHabit[habit.id] ?? const {},
              todayKey: todayKey,
            ),
          ),
      ],
    );
  }
}
