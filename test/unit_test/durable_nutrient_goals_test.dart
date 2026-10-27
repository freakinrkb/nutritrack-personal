import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/app_theme_dbo.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/utils/calc/nutrient_panel_keys.dart';

import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

ConfigDBO _dbo({Map<String, double>? nutrientGoals}) => ConfigDBO(
      false,
      false,
      false,
      AppThemeDBO.system,
      nutrientGoals: nutrientGoals,
    );

void main() {
  group('ConfigEntity durable nutrient goals', () {
    test('an old config has no durable goals', () {
      final config = ConfigEntity.fromConfigDBO(ConfigDBO.empty());

      expect(config.nutrientGoals, isEmpty);
      expect(config.nutrientGoal(NutrientPanelKeys.fiber), isNull);
    });

    test('known finite non-negative targets survive the config boundary', () {
      final config = ConfigEntity.fromConfigDBO(
        _dbo(
          nutrientGoals: {
            NutrientPanelKeys.fiber: 32,
            NutrientPanelKeys.iron: 0,
            NutrientPanelKeys.vitaminD: 17.5,
          },
        ),
      );

      expect(config.nutrientGoals, {
        NutrientPanelKeys.fiber: 32.0,
        NutrientPanelKeys.iron: 0.0,
        NutrientPanelKeys.vitaminD: 17.5,
      });
    });

    test('unknown, non-finite and negative targets are dropped', () {
      final config = ConfigEntity.fromConfigDBO(
        _dbo(
          nutrientGoals: {
            NutrientPanelKeys.fiber: double.nan,
            NutrientPanelKeys.iron: -2,
            NutrientPanelKeys.calcium: double.infinity,
            NutrientPanelKeys.sodium: 1800,
            'not_a_nutrient': 4,
          },
        ),
      );

      expect(config.nutrientGoals, {NutrientPanelKeys.sodium: 1800.0});
    });

    test('the map survives JSON used for backup and export', () {
      final stored = _dbo(
        nutrientGoals: {NutrientPanelKeys.fiber: 32, NutrientPanelKeys.iron: 9},
      );
      final reread = ConfigDBO.fromJson(stored.toJson());

      expect(reread.nutrientGoals, {
        NutrientPanelKeys.fiber: 32.0,
        NutrientPanelKeys.iron: 9.0,
      });
    });
  });

  group('ConfigDataSource durable nutrient goals', () {
    late Box<ConfigDBO> appBox;
    late Box<ConfigDBO> profileABox;
    late Box<ConfigDBO> profileBBox;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerHiveAdaptersOnce();
    });

    setUp(() async {
      Hive.init('.');
      appBox = await Hive.openBox<ConfigDBO>('durable_goals_app_test');
      profileABox = await Hive.openBox<ConfigDBO>('durable_goals_a_test');
      profileBBox = await Hive.openBox<ConfigDBO>('durable_goals_b_test');
      await appBox.clear();
      await profileABox.clear();
      await profileBBox.clear();
    });

    tearDown(() async {
      await Hive.close();
      await Hive.deleteFromDisk();
    });

    ConfigDataSource sourceFor(Box<ConfigDBO> profileBox) => ConfigDataSource(
          FakeHiveDBProvider(configBox: profileBox, appConfigBox: appBox),
        );

    test('goals are per-profile and never leak from the app box', () async {
      final profileA = sourceFor(profileABox);
      await profileA.initializeConfig();
      await profileA.setNutrientGoals({
        NutrientPanelKeys.fiber: 32,
        NutrientPanelKeys.iron: 11,
      });

      expect(await profileA.getNutrientGoals(), {
        NutrientPanelKeys.fiber: 32.0,
        NutrientPanelKeys.iron: 11.0,
      });

      final profileB = sourceFor(profileBBox);
      await profileB.initializeConfig();
      expect(await profileB.getNutrientGoals(), isEmpty);
    });

    test('an empty map clears every durable target', () async {
      final profileA = sourceFor(profileABox);
      await profileA.initializeConfig();
      await profileA.setNutrientGoals({NutrientPanelKeys.fiber: 32});
      await profileA.setNutrientGoals({});

      expect(await profileA.getNutrientGoals(), isEmpty);
    });

    test(
      'the returned map is a copy the caller cannot mutate in place',
      () async {
        final profileA = sourceFor(profileABox);
        await profileA.initializeConfig();
        await profileA.setNutrientGoals({NutrientPanelKeys.fiber: 32});

        final read = await profileA.getNutrientGoals();
        read[NutrientPanelKeys.fiber] = 1;

        expect(await profileA.getNutrientGoals(), {
          NutrientPanelKeys.fiber: 32.0,
        });
      },
    );
  });
}
