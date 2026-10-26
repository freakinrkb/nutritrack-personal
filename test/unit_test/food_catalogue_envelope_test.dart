import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/data/dto/bundled/food_catalogue_envelope.dart';

/// One valid envelope, as the bundled asset and an import file share it.
String _envelope({
  Object? schemaVersion = FoodCatalogueEnvelope.supportedSchemaVersion,
  Object? source = 'indb',
  Object? items,
}) {
  return jsonEncode({
    'schemaVersion': schemaVersion,
    'source': source,
    'sourceVersion': '2024.11',
    'license': 'CC BY 4.0',
    'items':
        items ??
        [
          {
            'code': 'indb:ASC001',
            'name': 'Hot tea (Garam Chai)',
            'energyKcal100': 16.1,
            'carbohydrates100': 2.6,
            'fat100': 0.5,
            'proteins100': 0.4,
          },
        ],
  });
}

void main() {
  group('FoodCatalogueEnvelope.parse', () {
    test('parses the shared asset/import shape', () {
      final envelope = FoodCatalogueEnvelope.parse(_envelope());

      expect(envelope.source, 'indb');
      expect(envelope.sourceVersion, '2024.11');
      expect(envelope.license, 'CC BY 4.0');
      expect(envelope.itemCount, 1);
      expect(envelope.items.single.code, 'indb:ASC001');
      expect(envelope.items.single.energyKcal100, 16.1);
    });

    test('rejects text that is not JSON at all', () {
      expect(
        () => FoodCatalogueEnvelope.parse('<html>not a catalogue</html>'),
        throwsFormatException,
      );
    });

    test('rejects a JSON array rather than an envelope object', () {
      expect(
        () => FoodCatalogueEnvelope.parse('[1, 2, 3]'),
        throwsFormatException,
      );
    });

    test('rejects a schema version this app cannot read', () {
      expect(
        () => FoodCatalogueEnvelope.parse(
          _envelope(
            schemaVersion: FoodCatalogueEnvelope.supportedSchemaVersion + 1,
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects an envelope without a source code', () {
      expect(
        () => FoodCatalogueEnvelope.parse(_envelope(source: '  ')),
        throwsFormatException,
      );
    });

    test('rejects an envelope with no items', () {
      expect(
        () => FoodCatalogueEnvelope.parse(_envelope(items: <Object>[])),
        throwsFormatException,
      );
    });

    test('rejects an item without a code', () {
      expect(
        () => FoodCatalogueEnvelope.parse(
          _envelope(
            items: [
              {'name': 'Anonymous food', 'energyKcal100': 100},
            ],
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects an item without a name', () {
      expect(
        () => FoodCatalogueEnvelope.parse(
          _envelope(
            items: [
              {'code': 'indb:X'},
            ],
          ),
        ),
        throwsFormatException,
      );
    });
  });
}
