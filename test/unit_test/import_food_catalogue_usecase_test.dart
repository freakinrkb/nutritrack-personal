import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/imported_food_catalogue_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/bundled_food_data_source.dart';
import 'package:opennutritracker/features/settings/domain/export_import_failure.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_food_catalogue_usecase.dart';

import '../helpers/hive_test_setup.dart';

/// The bundled half of the catalogue: two recipes, enough to prove the
/// import replaces one and leaves the other alone.
const _bundledFixture = '''
{
  "schemaVersion": 1,
  "source": "indb",
  "sourceVersion": "2024.11",
  "license": "CC BY 4.0",
  "items": [
    {
      "code": "indb:EXACT",
      "name": "khichdi",
      "energyKcal100": 100,
      "carbohydrates100": 18,
      "fat100": 2,
      "proteins100": 4
    },
    {
      "code": "indb:BB029",
      "name": "Masala dosa",
      "energyKcal100": 168,
      "carbohydrates100": 27,
      "fat100": 4.5,
      "proteins100": 3.8
    }
  ]
}
''';

String _importFile({
  Object? schemaVersion = 1,
  Object? source = 'indb',
  List<Map<String, Object?>>? items,
}) {
  return jsonEncode({
    'schemaVersion': schemaVersion,
    'source': source,
    'sourceVersion': '2025.07',
    'license': 'CC BY 4.0',
    'items':
        items ??
        [
          {
            'code': 'indb:EXACT',
            'name': 'khichdi',
            'energyKcal100': 999,
            'carbohydrates100': 18,
            'fat100': 2,
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
  });
}

void main() {
  group('ImportFoodCatalogueUsecase', () {
    late Box<String> box;
    late ImportedFoodCatalogueDataSource catalogueBox;
    late BundledFoodDataSource catalogue;
    late ImportFoodCatalogueUsecase usecase;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      Hive.init('.');
      registerHiveAdaptersOnce();
    });

    setUp(() async {
      box = await Hive.openBox<String>(
        'import_food_catalogue_${DateTime.now().microsecondsSinceEpoch}',
      );
      catalogueBox = ImportedFoodCatalogueDataSource(box);
      catalogue = BundledFoodDataSource(
        loadAsset: () async => _bundledFixture,
        importedCatalogue: catalogueBox,
      );
      usecase = ImportFoodCatalogueUsecase(catalogueBox, catalogue);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk(box.name);
    });

    test('a valid file is stored, counted, and takes over search', () async {
      final result = await usecase.importFromJsonString(_importFile());

      expect(result.isSuccess, isTrue);
      expect(result.itemCount, 2);
      expect(await usecase.importedItemCount(), 2);

      // The imported EXACT row replaces the bundled one (999 kcal), and
      // the recipe only the new file carries is searchable too.
      final exact = await catalogue.search('khichdi');
      expect(
        exact
            .firstWhere((m) => m.code == 'indb:EXACT')
            .nutriments
            .energyKcal100,
        999,
      );
      final added = await catalogue.search('sambar');
      expect(added.single.code, 'indb:NEW');
      // Bundled rows the import did not mention stay.
      final kept = await catalogue.search('dosa');
      expect(kept.single.code, 'indb:BB029');
    });

    test(
      're-importing replaces the previous file rather than adding to it',
      () async {
        await usecase.importFromJsonString(_importFile());
        final second = await usecase.importFromJsonString(
          _importFile(
            items: [
              {
                'code': 'indb:ONLY',
                'name': 'Single recipe',
                'energyKcal100': 50,
                'carbohydrates100': 10,
                'fat100': 1,
                'proteins100': 2,
              },
            ],
          ),
        );

        expect(second.itemCount, 1);
        expect(await usecase.importedItemCount(), 1);
        final added = await catalogue.search('sambar');
        expect(
          added,
          isEmpty,
          reason:
              'the first import\'s extra rows must not survive a '
              'replacement',
        );
      },
    );

    test('removing falls back to the bundled catalogue', () async {
      await usecase.importFromJsonString(_importFile());
      expect(await usecase.importedItemCount(), 2);

      await usecase.removeImportedCatalogue();

      expect(await usecase.importedItemCount(), isNull);
      final exact = await catalogue.search('khichdi');
      expect(
        exact
            .firstWhere((m) => m.code == 'indb:EXACT')
            .nutriments
            .energyKcal100,
        100,
        reason: 'bundled value again, not the imported 999',
      );
    });

    test(
      'text that is not a catalogue is rejected and stores nothing',
      () async {
        final result = await usecase.importFromJsonString('not json at all');

        expect(
          result.failureReason,
          ExportImportFailureReason.unreadableOrWrongFormat,
        );
        expect(result.itemCount, isNull);
        expect(box.get('indb'), isNull);
        final bundled = await catalogue.search('dosa');
        expect(bundled.single.code, 'indb:BB029');
      },
    );

    test("a file from a source the app doesn't bundle is rejected", () async {
      final result = await usecase.importFromJsonString(
        _importFile(source: 'tbca'),
      );

      expect(
        result.failureReason,
        ExportImportFailureReason.unreadableOrWrongFormat,
      );
      expect(box.get('indb'), isNull);
    });

    test('an unknown schema version is rejected', () async {
      final result = await usecase.importFromJsonString(
        _importFile(schemaVersion: 99),
      );

      expect(
        result.failureReason,
        ExportImportFailureReason.unreadableOrWrongFormat,
      );
    });

    test('a storage failure is reported as writeFailed', () async {
      await box.close();

      final result = await usecase.importFromJsonString(_importFile());

      expect(result.failureReason, ExportImportFailureReason.writeFailed);
    });
  });
}
