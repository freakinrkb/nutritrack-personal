import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/habit_checkin_dbo.dart';
import 'package:opennutritracker/core/data/dbo/habit_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/home/presentation/widgets/routine_home_card.dart';
import 'package:opennutritracker/features/routines/data/data_source/habit_data_source.dart';
import 'package:opennutritracker/features/routines/data/repository/habit_repository.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';
import 'package:opennutritracker/features/routines/domain/usecase/add_habit_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/delete_habit_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/get_routine_day_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/set_habit_status_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/update_habit_usecase.dart';
import 'package:opennutritracker/features/routines/presentation/bloc/routines_bloc.dart';
import 'package:opennutritracker/features/routines/presentation/routines_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../helpers/fake_hive_db_provider.dart';
import '../../helpers/hive_test_setup.dart';
import '../../helpers/test_l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HabitRepository repository;
  late GetConfigUsecase getConfig;
  late RoutinesBloc bloc;

  setUpAll(registerHiveAdaptersOnce);

  setUp(() async {
    Hive.init('.');
    final tag = DateTime.now().microsecondsSinceEpoch;
    final configBox = await Hive.openBox<ConfigDBO>(
      'routines_widget_config_$tag',
      bytes: Uint8List(0),
    );
    final db = FakeHiveDBProvider(
      configBox: configBox,
      appConfigBox: configBox,
      habitBox: await Hive.openBox<HabitDBO>(
        'routines_widget_habits_$tag',
        bytes: Uint8List(0),
      ),
      habitCheckinBox: await Hive.openBox<HabitCheckinDBO>(
        'routines_widget_checkins_$tag',
        bytes: Uint8List(0),
      ),
    );
    final configSource = ConfigDataSource(db);
    await configSource.initializeConfig();
    getConfig = GetConfigUsecase(ConfigRepository(configSource));
    repository = HabitRepository(HabitDataSource(db));
  });

  tearDown(() => Hive.close());

  RoutinesBloc createBloc() {
    bloc = RoutinesBloc(
      GetRoutineDayUsecase(
        repository,
        getConfig,
        now: () => DateTime(2026, 10, 10, 12),
      ),
      AddHabitUsecase(repository),
      UpdateHabitUsecase(repository),
      DeleteHabitUsecase(repository),
      SetHabitStatusUsecase(
        repository,
        getConfig,
        now: () => DateTime(2026, 10, 10, 12),
      ),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  Widget app(Widget home) => MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: home,
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(app(RoutinesScreen(bloc: bloc)));
    await settle(tester);
  }

  testWidgets('adds, completes, skips, and deletes a routine', (tester) async {
    createBloc();
    await openScreen(tester);
    expect(bloc.state, isA<RoutinesLoaded>());

    expect(find.text(l10nEn.routinesEmptyTitle), findsOneWidget);
    expect(find.text(l10nEn.routinesProgressLabel(0, 0)), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('routines-add'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Walk after lunch');
    await tester.pump();
    await tester.tap(find.bySemanticsIdentifier('routine-name-save'));
    await settle(tester);

    expect(find.text('Walk after lunch'), findsOneWidget);
    expect(find.text(l10nEn.routinesProgressLabel(0, 1)), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);

    expect(find.text(l10nEn.routinesProgressLabel(1, 1)), findsOneWidget);
    expect(find.textContaining(l10nEn.routinesDoneTodayLabel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text(l10nEn.routinesSkipTodayAction));
    await settle(tester);

    expect(find.text(l10nEn.routinesProgressLabel(0, 1)), findsOneWidget);
    expect(
      find.textContaining(l10nEn.routinesSkippedTodayLabel),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text(l10nEn.routinesDeleteAction));
    await settle(tester);
    await tester.tap(find.bySemanticsIdentifier('routine-delete-confirm'));
    await settle(tester);

    expect(find.text(l10nEn.routinesEmptyTitle), findsOneWidget);
    expect(find.text('Walk after lunch'), findsNothing);
  });

  testWidgets('renames a routine from the overflow menu', (tester) async {
    createBloc();
    await repository.saveHabit(
      HabitEntity(
        id: 'walk',
        name: 'Walk',
        sortOrder: 0,
        createdAt: DateTime(2026, 10, 1),
      ),
    );
    await openScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text(l10nEn.routinesEditAction));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Evening walk');
    await tester.pump();
    await tester.tap(find.bySemanticsIdentifier('routine-name-save'));
    await settle(tester);

    expect(find.text('Evening walk'), findsOneWidget);
    expect(find.text('Walk'), findsNothing);
  });

  testWidgets('home card summarises progress and checks a habit inline', (
    tester,
  ) async {
    createBloc();
    await repository.saveHabit(
      HabitEntity(
        id: 'walk',
        name: 'Walk',
        sortOrder: 0,
        createdAt: DateTime(2026, 10, 1),
      ),
    );

    await tester.pumpWidget(app(Scaffold(body: RoutineHomeCard(bloc: bloc))));
    await settle(tester);

    expect(find.text(l10nEn.routinesTitle), findsOneWidget);
    expect(find.text(l10nEn.routinesProgressLabel(0, 1)), findsOneWidget);
    expect(find.text('Walk'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);

    expect(find.text(l10nEn.routinesProgressLabel(1, 1)), findsOneWidget);
  });
}
