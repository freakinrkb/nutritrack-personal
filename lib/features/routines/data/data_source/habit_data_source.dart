import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/habit_checkin_dbo.dart';
import 'package:opennutritracker/core/data/dbo/habit_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class HabitDataSource {
  final HiveDBProvider _db;

  HabitDataSource(this._db);

  Box<HabitDBO> get _habits => _db.habitBox;
  Box<HabitCheckinDBO> get _checkins => _db.habitCheckinBox;

  Future<List<HabitDBO>> getHabits() async => _habits.values.toList();

  Future<HabitDBO?> getHabit(String id) async => _habits.get(id);

  Future<void> saveHabit(HabitDBO habit) async {
    await _habits.put(habit.id, habit);
  }

  Future<void> deleteHabit(String id) async {
    final checkinKeys = _checkins
        .toMap()
        .entries
        .where((entry) => entry.value.habitId == id)
        .map((entry) => entry.key)
        .toList();
    if (checkinKeys.isNotEmpty) {
      await _checkins.deleteAll(checkinKeys);
    }
    await _habits.delete(id);
  }

  Future<List<HabitCheckinDBO>> getCheckins() async =>
      _checkins.values.toList();

  Future<void> saveCheckin(HabitCheckinDBO checkin) async {
    await _checkins.put(
      HabitCheckinDBO.keyFor(checkin.habitId, checkin.dayKey),
      checkin,
    );
  }

  Future<void> deleteCheckin(String habitId, String dayKey) async {
    await _checkins.delete(HabitCheckinDBO.keyFor(habitId, dayKey));
  }
}
