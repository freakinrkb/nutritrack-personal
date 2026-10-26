import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/imported_food_catalogue_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/bundled_food_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/bundled/bundled_food_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

import '../helpers/hive_test_setup.dart';

/// Fixture catalogue: same envelope and item shape as
/// `assets/food/indb_recipes.json`, with names chosen so the ranking
/// tiers (exact / prefix / token-prefix / substring) are all reachable.
String _fixtureCatalogue({int itemGap = 0}) {
  final extraItems = List.generate(
    itemGap,
    (i) => {
      'code': 'indb:FILLER$i',
      'name': 'Filler recipe $i with khichdi in the middle',
      'energyKcal100': 1.0,
      'carbohydrates100': 0.2,
      'fat100': 0.1,
      'proteins100': 0.05,
    },
  );
  return jsonEncode({
    'schemaVersion': 1,
    'source': 'indb',
    'license': 'CC BY 4.0',
    'items': [
      {
        'code': 'indb:EXACT',
        'name': 'khichdi',
        'energyKcal100': 100,
        'carbohydrates100': 18,
        'fat100': 2,
        'proteins100': 4,
      },
      {
        'code': 'indb:PREFIX',
        'name': 'Khichdi, plain',
        'energyKcal100': 57.0,
        'carbohydrates100': 10.0,
        'fat100': 1.0,
        'proteins100': 1.7,
        'sugars100': 0.12,
        'fiber100': 0.84,
        'saturatedFat100': 0.53,
        'cholesterol100': 2.1,
        'sodium100': 37.1,
        'iron100': 0.3,
        'vitaminB12100': null,
        'niacin100': 0.34,
      },
      {
        'code': 'indb:MIDWORD',
        'name': 'Plain khitchdi (Plain khichri/khichdi)',
        'energyKcal100': 57.0305,
        'carbohydrates100': 10.0419,
        'fat100': 1.0063,
        'proteins100': 1.7178,
      },
      {
        'code': 'indb:UNRELATED',
        'name': 'Masala dosa',
        'energyKcal100': 168.0,
        'carbohydrates100': 27.0,
        'fat100': 4.5,
        'proteins100': 3.8,
      },
      ...extraItems,
    ],
  });
}

void main() {
  group('BundledFoodDTO', () {
    test('parses every nutrient field and int-or-double numbers', () {
      final dto = BundledFoodDTO.fromJson(const {
        'code': 'indb:X1',
        'name': 'Test food',
        'energyKcal100': 100,
        'carbohydrates100': 18.5,
        'fat100': 2,
        'proteins100': 4.2,
        'sugars100': 1.1,
        'saturatedFat100': 0.5,
        'fiber100': 0.8,
        'monounsaturatedFat100': 1.0,
        'polyunsaturatedFat100': 0.4,
        'transFat100': null,
        'cholesterol100': 0,
        'sodium100': 10,
        'potassium100': 20,
        'magnesium100': 3,
        'calcium100': 4,
        'iron100': 0.5,
        'zinc100': 0.2,
        'phosphorus100': 9,
        'vitaminA100': 1,
        'vitaminC100': 2,
        'vitaminD100': 0.5,
        'vitaminB6100': 0.1,
        'vitaminB12100': null,
        'niacin100': 0.3,
      });

      expect(dto.code, 'indb:X1');
      expect(dto.name, 'Test food');
      expect(dto.energyKcal100, 100.0);
      expect(dto.carbohydrates100, 18.5);
      expect(dto.transFat100, isNull);
      expect(dto.vitaminB12100, isNull);
      expect(dto.niacin100, 0.3);
    });
  });

  group('MealEntity.fromBundledFood', () {
    test('maps to a 100 g reference meal tagged as bundled INDB', () {
      final meal = MealEntity.fromBundledFood(
        BundledFoodDTO.fromJson(const {
          'code': 'indb:X1',
          'name': 'Test food',
          'energyKcal100': 100,
          'carbohydrates100': 18.5,
          'fat100': 2,
          'proteins100': 4.2,
        }),
      );

      expect(meal.code, 'indb:X1');
      expect(meal.source, MealSourceEntity.fdc);
      expect(meal.backendSource, 'indb');
      expect(meal.url, isNull);
      expect(meal.servingQuantity, 100);
      expect(meal.servingUnit, 'g');
      expect(meal.servingSize, '100 g');
      expect(meal.detailed, isTrue);
      expect(meal.nutriments.energyKcal100, 100.0);
      expect(meal.nutriments.proteins100, 4.2);
      expect(meal.nutriments.vitaminB12100, isNull);
    });
  });

  group('BundledFoodDataSource.search', () {
    BundledFoodDataSource buildSource({String? catalogue}) =>
        BundledFoodDataSource(
          loadAsset: () async => catalogue ?? _fixtureCatalogue(),
        );

    test(
      'ranks exact, prefix, token-prefix, substring in that order',
      () async {
        final results = await buildSource().search('khichdi');

        expect(results.map((m) => m.code), [
          'indb:EXACT',
          'indb:PREFIX',
          'indb:MIDWORD',
        ]);
      },
    );

    test('is case-insensitive and trims the query', () async {
      final results = await buildSource().search('  KHICHDI  ');

      expect(results.first.code, 'indb:EXACT');
    });

    test('requires every query token to match', () async {
      final results = await buildSource().search('plain khichdi');

      // 'plain' is absent from the exact-name item, so it drops out; the
      // other two names carry both tokens.
      expect(results.map((m) => m.code), ['indb:PREFIX', 'indb:MIDWORD']);
    });

    test('empty and whitespace-only queries return nothing', () async {
      final source = buildSource();

      expect(await source.search(''), isEmpty);
      expect(await source.search('   '), isEmpty);
    });

    test('caps the list at maxResults', () async {
      final results = await buildSource(
        catalogue: _fixtureCatalogue(itemGap: 50),
      ).search('filler');

      expect(results, hasLength(BundledFoodDataSource.maxResults));
      expect(
        results.every((m) => m.name!.toLowerCase().contains('filler')),
        isTrue,
      );
    });

    test('parses the catalogue once across searches', () async {
      var loadCount = 0;
      final source = BundledFoodDataSource(
        loadAsset: () async {
          loadCount++;
          return _fixtureCatalogue();
        },
      );

      await source.search('khichdi');
      await source.search('dosa');

      expect(loadCount, 1);
    });

    test('a failed load throws but does not poison the next search', () async {
      var fail = true;
      final source = BundledFoodDataSource(
        loadAsset: () async {
          if (fail) throw StateError('asset missing');
          return _fixtureCatalogue();
        },
      );

      await expectLater(source.search('khichdi'), throwsStateError);

      fail = false;
      final results = await source.search('khichdi');
      expect(results, isNotEmpty);
    });

    test('rejects an envelope from an unknown schema version', () {
      final source = buildSource(
        catalogue: jsonEncode({
          'schemaVersion': 99,
          'items': <Map<String, dynamic>>[],
        }),
      );

      expect(source.search('anything'), throwsFormatException);
    });
  });

  group('BundledFoodDataSource with an imported catalogue', () {
    late Box<String> box;
    late BundledFoodDataSource source;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      Hive.init('.');
      registerHiveAdaptersOnce();
    });

    setUp(() async {
      box = await Hive.openBox<String>(
        'bundled_imported_catalogue_'
        '${DateTime.now().microsecondsSinceEpoch}',
      );
      source = BundledFoodDataSource(
        loadAsset: () async => _fixtureCatalogue(),
        importedCatalogue: ImportedFoodCatalogueDataSource(box),
      );
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk(box.name);
    });

    String importedEnvelope({required List<Map<String, Object?>> items}) =>
        jsonEncode({
          'schemaVersion': 1,
          'source': 'indb',
          'sourceVersion': '2025.07',
          'license': 'CC BY 4.0',
          'items': items,
        });

    test(
      'replaces bundled rows with the same code and adds new ones',
      () async {
        await box.put(
          'indb',
          importedEnvelope(
            items: [
              {
                'code': 'indb:EXACT',
                'name': 'khichdi',
                'energyKcal100': 999,
                'carbohydrates100': 10,
                'fat100': 1,
                'proteins100': 4,
              },
              {
                'code': 'indb:NEW',
                'name': 'Sambar rice',
                'energyKcal100': 150,
                'carbohydrates100': 28,
                'fat100': 3,
                'proteins100': 5,
              },
            ],
          ),
        );

        final results = await source.search('rice');

        expect(results.single.code, 'indb:NEW');

        final exact = await source.search('khichdi');
        final replaced = exact.firstWhere((m) => m.code == 'indb:EXACT');
        expect(replaced.name, 'khichdi');
        // The imported row's data, not the bundled copy's.
        expect(replaced.nutriments.energyKcal100, 999);
      },
    );

    test('invalidateCatalogue makes a later import visible', () async {
      final before = await source.search('dosa');
      expect(before.single.code, 'indb:UNRELATED');

      await box.put(
        'indb',
        importedEnvelope(
          items: [
            {
              'code': 'indb:REPLACEMENT',
              'name': 'Dosa, replaced',
              'energyKcal100': 170,
              'carbohydrates100': 27,
              'fat100': 4,
              'proteins100': 4,
            },
          ],
        ),
      );
      // The parsed catalogue is cached until told otherwise: without
      // invalidation the pre-import rows keep serving.
      final cached = await source.search('dosa');
      expect(cached.single.code, 'indb:UNRELATED');

      source.invalidateCatalogue();

      // The overlay adds REPLACEMENT; the bundled 'Masala dosa' keeps its
      // own code and stays searchable next to it.
      final after = await source.search('dosa');
      expect(after.map((m) => m.code), ['indb:REPLACEMENT', 'indb:UNRELATED']);
    });

    test(
      'a corrupt stored file keeps search on the bundled catalogue',
      () async {
        await box.put('indb', 'this is not a catalogue');

        final results = await source.search('dosa');

        expect(results.single.code, 'indb:UNRELATED');
      },
    );
  });
}
