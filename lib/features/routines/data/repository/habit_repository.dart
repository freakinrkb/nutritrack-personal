import 'package:opennutritracker/core/data/dbo/habit_checkin_dbo.dart';
import 'package:opennutritracker/core/data/dbo/habit_dbo.dart';
import 'package:opennutritracker/features/routines/data/data_source/habit_data_source.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';

class HabitRepository {
  final HabitDataSource _dataSource;

  HabitRepository(this._dataSource);

  Future<List<HabitEntity>> getHabits() async {
    final rows = await _dataSource.getHabits();
    final habits = rows.map(_habitFromDBO).toList();
    habits.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.createdAt.compareTo(b.createdAt);
    });
    return habits;
  }

  Future<HabitEntity?> getHabit(String id) async {
    final row = await _dataSource.getHabit(id);
    return row == null ? null : _habitFromDBO(row);
  }

  Future<void> saveHabit(HabitEntity habit) async {
    await _dataSource.saveHabit(_habitToDBO(habit));
  }

  Future<void> deleteHabit(String id) async {
    await _dataSource.deleteHabit(id);
  }

  Future<List<HabitCheckinEntity>> getCheckins() async {
    final rows = await _dataSource.getCheckins();
    return rows.map(_checkinFromDBO).toList();
  }

  Future<void> setStatus(
    String habitId,
    String dayKey,
    HabitStatus? status,
  ) async {
    if (status == null) {
      await _dataSource.deleteCheckin(habitId, dayKey);
      return;
    }
    await _dataSource.saveCheckin(
      HabitCheckinDBO(
        habitId: habitId,
        dayKey: dayKey,
        status: _statusToDBO(status),
        recordedAt: DateTime.now(),
      ),
    );
  }

  HabitEntity _habitFromDBO(HabitDBO dbo) => HabitEntity(
        id: dbo.id,
        name: dbo.name,
        sortOrder: dbo.sortOrder,
        createdAt: dbo.createdAt,
      );

  HabitDBO _habitToDBO(HabitEntity entity) => HabitDBO(
        id: entity.id,
        name: entity.name,
        sortOrder: entity.sortOrder,
        createdAt: entity.createdAt,
      );

  HabitCheckinEntity _checkinFromDBO(HabitCheckinDBO dbo) => HabitCheckinEntity(
        habitId: dbo.habitId,
        dayKey: dbo.dayKey,
        status: dbo.status == HabitCheckinDBO.skippedStatus
            ? HabitStatus.skipped
            : HabitStatus.done,
        recordedAt: dbo.recordedAt,
      );

  int _statusToDBO(HabitStatus status) => switch (status) {
        HabitStatus.done => HabitCheckinDBO.doneStatus,
        HabitStatus.skipped => HabitCheckinDBO.skippedStatus,
      };
}
