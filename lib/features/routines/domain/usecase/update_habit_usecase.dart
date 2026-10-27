import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';

class UpdateHabitUsecase {
  final HabitRepository _repository;

  UpdateHabitUsecase(this._repository);

  Future<void> call(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Habit name must not be empty');
    }
    final habit = await _repository.getHabit(id);
    if (habit == null) return;
    await _repository.saveHabit(habit.copyWith(name: trimmed));
  }
}
