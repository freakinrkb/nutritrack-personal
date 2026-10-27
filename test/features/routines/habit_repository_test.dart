import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/habit_checkin_dbo.dart';
import 'package:opennutritracker/core/data/dbo/habit_dbo.dart';
import 'package:opennutritracker/features/routines/data/data_source/habit_data_source.dart';
import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';

import '../../helpers/fake_hive_db_provider.dart';
import '../../helpers/hive_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Box<HabitDBO> habits;
  late Box<HabitCheckinDBO> checkins;
  late HabitRepository repository;

  setUpAll(registerHiveAdaptersOnce);

  setUp(() async {
    Hive.init('.');
    final tag = DateTime.now().microsecondsSinceEpoch;
    habits = await Hive.openBox<HabitDBO>('habit_repo_habits_$tag');
    checkins = await Hive.openBox<HabitCheckinDBO>('habit_repo_checkins_$tag');
    repository = HabitRepository(
      HabitDataSource(
        FakeHiveDBProvider(habitBox: habits, habitCheckinBox: checkins),
      ),
    );
  });

  tearDown(() => Hive.deleteFromDisk());

  HabitEntity habit(String id, String name, int order) => HabitEntity(
        id: id,
        name: name,
        sortOrder: order,
        createdAt: DateTime(2026, 10, 1, 12, order),
      );

  test('saves habits and returns them in sort order', () async {
    await repository.saveHabit(habit('b', 'Drink water', 2));
    await repository.saveHabit(habit('a', 'Walk', 1));

    final result = await repository.getHabits();

    expect(result.map((entry) => entry.name), ['Walk', 'Drink water']);
    expect(await repository.getHabit('a'), isNotNull);
  });

  test('a habit has one status per day and the latest write wins', () async {
    await repository.setStatus('walk', '2026-10-10', HabitStatus.done);
    await repository.setStatus('walk', '2026-10-10', HabitStatus.skipped);
    await repository.setStatus('walk', '2026-10-09', HabitStatus.done);

    final result = await repository.getCheckins();

    expect(result, hasLength(2));
    expect(
      result.singleWhere((entry) => entry.dayKey == '2026-10-10').status,
      HabitStatus.skipped,
    );
    expect(
      checkins.keys,
      containsAll([
        HabitCheckinDBO.keyFor('walk', '2026-10-10'),
        HabitCheckinDBO.keyFor('walk', '2026-10-09'),
      ]),
    );
  });

  test('clearing a status removes only that day', () async {
    await repository.setStatus('walk', '2026-10-10', HabitStatus.done);
    await repository.setStatus('walk', '2026-10-09', HabitStatus.done);

    await repository.setStatus('walk', '2026-10-10', null);

    final result = await repository.getCheckins();
    expect(result, hasLength(1));
    expect(result.single.dayKey, '2026-10-09');
  });

  test('deleting a habit removes all of its check-ins', () async {
    await repository.setStatus('walk', '2026-10-10', HabitStatus.done);
    await repository.setStatus('walk', '2026-10-09', HabitStatus.skipped);
    await repository.setStatus('water', '2026-10-10', HabitStatus.done);

    await repository.deleteHabit('walk');

    final result = await repository.getCheckins();
    expect(result, hasLength(1));
    expect(result.single.habitId, 'water');
    expect(habits.get('walk'), isNull);
  });
}
