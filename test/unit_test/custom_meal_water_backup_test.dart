import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/favourite_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/recipe_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/data_source/water_intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/weight_log_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/favourite_meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/custom_activity_template_repository.dart';
import 'package:opennutritracker/core/data/repository/favourite_meal_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/features/settings/domain/export_import_failure.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/export_import_bloc.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.uri);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => null;

  @override
  Future<int> length() => File(path!).length();

  @override
  Future<Uint8List> readAsBytes() => File(path!).readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() => File(path!).openRead().cast();
}

class _StubActivities extends UserActivityRepository {
  _StubActivities() : super(UserActivityDataSource(FakeHiveDBProvider()));

  @override
  Future<List<UserActivityDBO>> getAllUserActivityDBO() async => [];

  @override
  Future<void> upsertAllUserActivityDBOs(
    List<UserActivityDBO> userActivityDBOs,
  ) async {}
}

class _StubIntakes extends IntakeRepository {
  _StubIntakes() : super(IntakeDataSource(FakeHiveDBProvider()));

  @override
  Future<List<IntakeDBO>> getAllIntakesDBO() async => [];

  @override
  Future<void> upsertAllIntakeDBOs(List<IntakeDBO> intakeDBOs) async {}
}

class _StubTrackedDays extends TrackedDayRepository {
  _StubTrackedDays() : super(TrackedDayDataSource(FakeHiveDBProvider()));

  @override
  Future<List<TrackedDayDBO>> getAllTrackedDaysDBO() async => [];

  @override
  Future<void> addAllTrackedDays(List<TrackedDayDBO> trackedDays) async {}
}

class _StubRecipes extends RecipeRepository {
  _StubRecipes() : super(RecipeDataSource(FakeHiveDBProvider()));

  @override
  List<RecipeDBO> getAllRecipesDBO() => [];

  @override
  Future<void> addAllRecipeDBOs(List<RecipeDBO> recipes) async {}
}

class _StubWeightLog extends WeightLogRepository {
  _StubWeightLog() : super(WeightLogDataSource(FakeHiveDBProvider()));

  @override
  Future<List<WeightLogDBO>> getAllEntriesDBO() async => [];

  @override
  Future<void> addAllEntries(List<WeightLogDBO> entries) async {}
}

class _StubTemplates extends CustomActivityTemplateRepository {
  _StubTemplates()
      : super(CustomActivityTemplateDataSource(FakeHiveDBProvider()));

  @override
  Future<List<CustomActivityTemplateDBO>> allTemplateDBOs() async => [];

  @override
  Future<void> upsertAllTemplateDBOs(
    List<CustomActivityTemplateDBO> templates,
  ) async {}
}

class _StubConfig extends ConfigRepository {
  _StubConfig() : super(ConfigDataSource(FakeHiveDBProvider()));

  @override
  Future<ConfigDBO> getConfigDBO() async => ConfigDBO.empty();

  @override
  Future<void> setConfigGoalSettings({
    required double? kcalAdjustment,
    required double? carbGoalPct,
    required double? proteinGoalPct,
    required double? fatGoalPct,
    required Map<String, int>? mealKcalSharesPct,
    required int? dailyWaterGoalMl,
    Map<String, double>? nutrientGoals,
    bool replaceNutrientGoals = false,
  }) async {}
}

class _StubFavourites extends FavouriteMealRepository {
  _StubFavourites()
      : super(
          FavouriteMealDataSource(FakeHiveDBProvider()),
          CustomMealDataSource(FakeHiveDBProvider()),
          RecipeDataSource(FakeHiveDBProvider()),
        );

  @override
  Future<List<FavouriteMealDBO>> getAllFavouritesDBO() async => [];

  @override
  Future<void> addAllFavouriteDBOs(List<FavouriteMealDBO> favourites) async {}
}

MealDBO _meal({required String code, required String name}) => MealDBO(
      code: code,
      name: name,
      brands: null,
      thumbnailImageUrl: null,
      mainImageUrl: null,
      url: null,
      mealQuantity: '100',
      mealUnit: 'g',
      servingQuantity: 100,
      servingUnit: 'g',
      servingSize: '100 g',
      nutriments: MealNutrimentsDBO(
        energyKcal100: 380,
        carbohydrates100: 60,
        fat100: 7,
        proteins100: 13,
        sugars100: 1,
        saturatedFat100: 1,
        fiber100: 10,
      ),
      source: MealSourceDBO.custom,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;
  late Box<MealDBO> sourceMealBox;
  late Box<WaterIntakeDBO> sourceWaterBox;
  late Box<MealDBO> destinationMealBox;
  late Box<WaterIntakeDBO> destinationWaterBox;
  late CustomMealDataSource sourceMeals;
  late WaterIntakeRepository sourceWater;
  late CustomMealDataSource destinationMeals;
  late WaterIntakeRepository destinationWater;
  late ExportDataUsecase exporter;
  late ImportDataUsecase importer;

  setUpAll(() async {
    Hive.init('.');
    registerHiveAdaptersOnce();
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('custom_water_backup');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    final tag = DateTime.now().microsecondsSinceEpoch;
    Future<Box<T>> open<T>(String name) =>
        Hive.openBox<T>('backup_${name}_$tag');

    sourceMealBox = await open<MealDBO>('source_meal');
    sourceWaterBox = await open<WaterIntakeDBO>('source_water');
    destinationMealBox = await open<MealDBO>('destination_meal');
    destinationWaterBox = await open<WaterIntakeDBO>('destination_water');

    sourceMeals = CustomMealDataSource(
      FakeHiveDBProvider(customMealBox: sourceMealBox),
    );
    sourceWater = WaterIntakeRepository(
      WaterIntakeDataSource(FakeHiveDBProvider(waterIntakeBox: sourceWaterBox)),
    );
    destinationMeals = CustomMealDataSource(
      FakeHiveDBProvider(customMealBox: destinationMealBox),
    );
    destinationWater = WaterIntakeRepository(
      WaterIntakeDataSource(
        FakeHiveDBProvider(waterIntakeBox: destinationWaterBox),
      ),
    );

    exporter = ExportDataUsecase(
      _StubActivities(),
      _StubIntakes(),
      _StubTrackedDays(),
      _StubRecipes(),
      sourceMeals,
      _StubWeightLog(),
      _StubTemplates(),
      _StubConfig(),
      _StubFavourites(),
      waterIntakeRepository: sourceWater,
    );
    importer = ImportDataUsecase(
      _StubActivities(),
      _StubIntakes(),
      _StubTrackedDays(),
      _StubRecipes(),
      _StubWeightLog(),
      _StubTemplates(),
      _StubConfig(),
      _StubFavourites(),
      customMealDataSource: destinationMeals,
      waterIntakeRepository: destinationWater,
      pickFile: () async =>
          _PickedFile('backup.zip', File('${tempDir.path}/backup.zip').uri),
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await sourceMealBox.deleteFromDisk();
    await sourceWaterBox.deleteFromDisk();
    await destinationMealBox.deleteFromDisk();
    await destinationWaterBox.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<Archive> exportJson() => exporter.assembleArchive(
        format: ExportFormat.json,
        userActivityJsonFileName: ExportImportBloc.userActivityJsonFileName,
        userIntakeJsonFileName: ExportImportBloc.userIntakeJsonFileName,
        trackedDayJsonFileName: ExportImportBloc.trackedDayJsonFileName,
        recipeJsonFileName: ExportImportBloc.recipeJsonFileName,
        weightLogJsonFileName: ExportImportBloc.weightLogJsonFileName,
        customActivityTemplateJsonFileName:
            ExportImportBloc.customActivityTemplateJsonFileName,
      );

  Future<bool> importJson() => importer.importData(
        ExportImportBloc.userActivityJsonFileName,
        ExportImportBloc.userIntakeJsonFileName,
        ExportImportBloc.trackedDayJsonFileName,
        ExportImportBloc.recipeJsonFileName,
        ExportImportBloc.weightLogJsonFileName,
        ExportImportBloc.customActivityTemplateJsonFileName,
      );

  void writeArchive(Archive archive) {
    File(
      '${tempDir.path}/backup.zip',
    ).writeAsBytesSync(ZipEncoder().encode(archive));
  }

  test('JSON export carries the custom-meal library and water log', () async {
    await sourceMeals.saveCustomMeal(_meal(code: 'oats-1', name: 'Oats'));
    await sourceWater.addAllEntries([
      WaterIntakeDBO(
        id: 'water-1',
        dateTime: DateTime(2026, 10, 4, 8),
        amountMl: 250,
      ),
      WaterIntakeDBO(
        id: 'water-2',
        dateTime: DateTime(2026, 10, 4, 9),
        amountMl: 500,
      ),
    ]);

    final archive = await exportJson();

    final mealsEntry = archive.findFile(
      ExportImportBloc.customMealJsonFileName,
    );
    final waterEntry = archive.findFile(
      ExportImportBloc.waterIntakeJsonFileName,
    );
    expect(mealsEntry, isNotNull);
    expect(waterEntry, isNotNull);

    final meals =
        jsonDecode(utf8.decode(mealsEntry!.content as List<int>)) as List;
    final water =
        jsonDecode(utf8.decode(waterEntry!.content as List<int>)) as List;
    expect(meals.single['code'], 'oats-1');
    expect(meals.single['name'], 'Oats');
    expect(water.map((entry) => entry['id']), ['water-1', 'water-2']);
    expect(water.map((entry) => entry['amountMl']), [250, 500]);
  });

  test('import restores both and re-importing changes nothing', () async {
    await sourceMeals.saveCustomMeal(_meal(code: 'oats-1', name: 'Oats'));
    await sourceWater.addAllEntries([
      WaterIntakeDBO(
        id: 'water-1',
        dateTime: DateTime(2026, 10, 4, 8),
        amountMl: 250,
      ),
      WaterIntakeDBO(
        id: 'water-2',
        dateTime: DateTime(2026, 10, 4, 9),
        amountMl: 500,
      ),
    ]);
    writeArchive(await exportJson());

    expect(await importJson(), isTrue);

    expect(destinationMeals.getAllCustomMeals(), hasLength(1));
    expect(destinationMeals.getAllCustomMeals().single.name, 'Oats');
    expect(
      (await destinationWater.getAllEntriesDBO()).map((e) => e.id).toSet(),
      {'water-1', 'water-2'},
    );

    expect(await importJson(), isTrue);
    expect(destinationMeals.getAllCustomMeals(), hasLength(1));
    expect(await destinationWater.getAllEntriesDBO(), hasLength(2));
  });

  test(
    'a malformed custom-meal file rejects the zip before any write',
    () async {
      final archive = Archive();
      void add(String name, Object json) {
        final bytes = utf8.encode(jsonEncode(json));
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add(ExportImportBloc.userActivityJsonFileName, const []);
      add(ExportImportBloc.userIntakeJsonFileName, const []);
      add(ExportImportBloc.trackedDayJsonFileName, const []);
      add(ExportImportBloc.recipeJsonFileName, const []);
      add(ExportImportBloc.weightLogJsonFileName, const []);
      add(ExportImportBloc.customActivityTemplateJsonFileName, const []);
      add(ExportImportBloc.customMealJsonFileName, [
        {'name': 'missing required fields'},
      ]);
      add(ExportImportBloc.waterIntakeJsonFileName, [
        {
          'id': 'water-1',
          'dateTime': '2026-10-04T08:00:00.000',
          'amountMl': 250,
        },
      ]);
      writeArchive(archive);

      await expectLater(
        importJson(),
        throwsA(
          isA<ExportImportFailure>().having(
            (failure) => failure.reason,
            'reason',
            ExportImportFailureReason.unreadableOrWrongFormat,
          ),
        ),
      );

      expect(destinationMeals.getAllCustomMeals(), isEmpty);
      expect(await destinationWater.getAllEntriesDBO(), isEmpty);
    },
  );
}
