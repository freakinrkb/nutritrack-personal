import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';

class DeleteHabitUsecase {
  final HabitRepository _repository;

  DeleteHabitUsecase(this._repository);

  Future<void> call(String id) async {
    await _repository.deleteHabit(id);
  }
}
