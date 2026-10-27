import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/habit_checkin_dbo.dart';
import 'package:opennutritracker/core/data/dbo/habit_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/routines/data/data_source/habit_data_source.dart';
import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';
import 'package:opennutritracker/features/routines/domain/usecase/get_routine_day_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/set_habit_status_usecase.dart';

import '../../helpers/fake_hive_db_provider.dart';
import '../../helpers/hive_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHiveDBProvider db;
  late HabitRepository repository;
  late GetConfigUsecase getConfig;

  setUpAll(registerHiveAdaptersOnce);

  setUp(() async {
    Hive.init('.');
    final tag = DateTime.now().microsecondsSinceEpoch;
    final configBox = await Hive.openBox<ConfigDBO>('routines_config_$tag');
    db = FakeHiveDBProvider(
      configBox: configBox,
      appConfigBox: configBox,
      habitBox: await Hive.openBox<HabitDBO>('routines_habits_$tag'),
      habitCheckinBox: await Hive.openBox<HabitCheckinDBO>(
        'routines_checkins_$tag',
      ),
    );
    final configSource = ConfigDataSource(db);
    await configSource.initializeConfig();
    await configSource.setConfigDayStartOffset(4, 0);
    getConfig = GetConfigUsecase(ConfigRepository(configSource));
    repository = HabitRepository(HabitDataSource(db));
    await repository.saveHabit(
      HabitEntity(
        id: 'walk',
        name: 'Walk after lunch',
        sortOrder: 0,
        createdAt: DateTime(2026, 10, 1),
      ),
    );
  });

  tearDown(() => Hive.deleteFromDisk());

  test(
    'status writes use the configured logical day, not wall-clock midnight',
    () async {
      await SetHabitStatusUsecase(
        repository,
        getConfig,
        now: () => DateTime(2026, 10, 10, 3, 30),
      ).call('walk', HabitStatus.done);

      final checkins = await repository.getCheckins();
      expect(checkins.single.dayKey, '2026-10-09');
    },
  );

  test(
    'loads today\'s status and preserves the streak before today is marked',
    () async {
      await repository.setStatus('walk', '2026-10-08', HabitStatus.done);
      await repository.setStatus('walk', '2026-10-09', HabitStatus.done);

      final result = await GetRoutineDayUsecase(
        repository,
        getConfig,
        now: () => DateTime(2026, 10, 10, 4, 5),
      ).call();

      expect(result.day, DateTime(2026, 10, 10));
      expect(result.doneCount, 0);
      expect(result.habits.single.status, isNull);
      expect(result.habits.single.streak, 2);
    },
  );

  test('skip is counted neither as done nor as a streak break', () async {
    await repository.setStatus('walk', '2026-10-08', HabitStatus.done);
    await repository.setStatus('walk', '2026-10-09', HabitStatus.skipped);
    await repository.setStatus('walk', '2026-10-10', HabitStatus.done);

    final result = await GetRoutineDayUsecase(
      repository,
      getConfig,
      now: () => DateTime(2026, 10, 10, 12),
    ).call();

    expect(result.doneCount, 1);
    expect(result.habits.single.status, HabitStatus.done);
    expect(result.habits.single.streak, 2);
  });
}
