import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/bundled_food_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/bundled/food_catalogue_envelope.dart';

/// Guards the bundled Anuvaad INDB catalogue the app ships with.
///
/// Reads the asset straight from disk rather than through `rootBundle` —
/// a unit test has no asset bundle (the precedent is
/// `ai_endpoint_probe_runner_test.dart`), and what is being checked is the
/// file in the repository, which is exactly what the build embeds.
void main() {
  final file = File(BundledFoodDataSource.assetPath);

  Map<String, dynamic> decodeEnvelope() {
    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    return decoded as Map<String, dynamic>;
  }

  group('bundled INDB catalogue asset', () {
    test('exists at the path the data source reads', () {
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '${BundledFoodDataSource.assetPath} must be bundled — '
            'it is registered in pubspec.yaml and powers offline '
            'Indian-recipe search',
      );
    });

    test('carries the source, version and licence the CC BY 4.0 '
        'attribution depends on', () {
      final envelope = decodeEnvelope();

      expect(
        envelope['schemaVersion'],
        FoodCatalogueEnvelope.supportedSchemaVersion,
      );
      expect(envelope['source'], 'indb');
      expect(envelope['sourceVersion'], isNotEmpty);
      expect(envelope['license'], 'CC BY 4.0');
      expect(envelope['attribution'], isNotEmpty);
    });

    test('passes the same validator the import flow uses', () {
      // What ships must be exactly what the app accepts as an import —
      // one schema authority (FoodCatalogueEnvelope.parse) reads both.
      final parsed = FoodCatalogueEnvelope.parse(file.readAsStringSync());

      expect(parsed.source, 'indb');
      expect(parsed.itemCount, 1014);
    });

    test('holds the full 2024.11 recipe set with unique namespaced codes', () {
      final envelope = decodeEnvelope();
      final items = envelope['items'] as List;

      expect(items, hasLength(1014));
      expect(envelope['itemCount'], items.length);

      final codes = <String>{};
      for (final item in items) {
        expect(item, isA<Map<String, dynamic>>());
        final code = item['code'] as String;
        final name = item['name'] as String;
        expect(
          code,
          startsWith('indb:'),
          reason:
              'codes must be namespaced so they can never collide '
              'with a backend food_id in the search cache or dedup',
        );
        expect(code.length, greaterThan('indb:'.length));
        expect(name.trim(), isNotEmpty);
        expect(codes.add(code), isTrue, reason: 'duplicate code $code');
      }
    });

    test('every item has the macros the search results depend on', () {
      final items = decodeEnvelope()['items'] as List;

      for (final item in items) {
        for (final key in [
          'energyKcal100',
          'carbohydrates100',
          'fat100',
          'proteins100',
        ]) {
          final value = item[key];
          expect(value, isA<num>(), reason: '${item['code']} is missing $key');
          expect(
            (value as num).toDouble(),
            greaterThanOrEqualTo(0),
            reason: '${item['code']} has negative $key',
          );
        }
        // Per-100 g basis: no macronutrient can exceed the 100 g it is
        // stated per, and the sum leaves no room for impossible rows.
        final carbs = (item['carbohydrates100'] as num).toDouble();
        final protein = (item['proteins100'] as num).toDouble();
        final fat = (item['fat100'] as num).toDouble();
        expect(carbs, lessThanOrEqualTo(100));
        expect(protein, lessThanOrEqualTo(100));
        expect(fat, lessThanOrEqualTo(100));
        expect(
          carbs + protein + fat,
          lessThanOrEqualTo(100.5),
          reason: '${item['code']} macros exceed its 100 g basis',
        );
        final sugar = item['sugars100'];
        if (sugar != null) {
          expect(
            (sugar as num).toDouble(),
            lessThanOrEqualTo(carbs + 0.5),
            reason: '${item['code']} has more sugar than carbohydrate',
          );
        }
        // INDB publishes saturated fat in mg; the generator converts to g.
        final satFat = item['saturatedFat100'];
        if (satFat != null) {
          expect(
            (satFat as num).toDouble(),
            lessThanOrEqualTo(fat + 0.05),
            reason: '${item['code']} has more saturated fat than fat',
          );
        }
      }
    });
  });
}
