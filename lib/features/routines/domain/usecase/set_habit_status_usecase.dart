import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';

class SetHabitStatusUsecase {
  final HabitRepository _repository;
  final GetConfigUsecase _getConfig;
  final DateTime Function() _now;

  SetHabitStatusUsecase(
    this._repository,
    this._getConfig, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<void> call(String habitId, HabitStatus? status) async {
    final config = await _getConfig.getConfig();
    final dayKey = DayBoundaryCalc.dayKeyOf(
      _now(),
      config.dayStartOffsetTotalMinutes,
      clockReading: true,
    );
    await _repository.setStatus(habitId, dayKey, status);
  }
}
