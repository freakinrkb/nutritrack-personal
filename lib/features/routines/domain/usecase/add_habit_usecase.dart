import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';

class AddHabitUsecase {
  final HabitRepository _repository;

  AddHabitUsecase(this._repository);

  Future<HabitEntity> call(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Habit name must not be empty');
    }
    final existing = await _repository.getHabits();
    final nextOrder = existing.fold<int>(
      0,
      (highest, habit) =>
          habit.sortOrder >= highest ? habit.sortOrder + 1 : highest,
    );
    final habit = HabitEntity(
      id: IdGenerator.getUniqueID(),
      name: trimmed,
      sortOrder: nextOrder,
      createdAt: DateTime.now(),
    );
    await _repository.saveHabit(habit);
    return habit;
  }
}
