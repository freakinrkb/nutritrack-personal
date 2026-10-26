import 'dart:convert';

import 'package:opennutritracker/features/add_meal/data/dto/bundled/bundled_food_dto.dart';

/// The JSON envelope a food catalogue file travels in — both the one bundled
/// at `assets/food/indb_recipes.json` and one the user imports from disk in
/// Settings → Food databases (a newer drop of the same source).
///
/// One parser serves both: what the app ships is exactly what it accepts,
/// so an import can never drift into a shape search does not understand.
/// [parse] throws [FormatException] with a human-readable message on any
/// deviation; the import flow surfaces that as the standard
/// "unreadable or wrong format" failure, and the bundled-asset reader lets
/// it fail the same way its data source's tests expect.
class FoodCatalogueEnvelope {
  /// Envelope schema this app understands. Bumping it means the bundled
  /// asset and every already-imported file move together, so the parser
  /// rejects anything else rather than silently misreading fields.
  static const supportedSchemaVersion = 1;

  /// `food_source.code` the catalogue belongs to (`indb`).
  final String source;

  /// Data version of the source dump (`2024.11`), carried in the envelope —
  /// stored alongside the items so Settings can later show which version
  /// replaced the bundled one.
  final String sourceVersion;

  /// Licence string (`CC BY 4.0`): attribution must be reproducible for an
  /// imported file exactly as for the bundled copy.
  final String license;

  final List<BundledFoodDTO> items;

  const FoodCatalogueEnvelope({
    required this.source,
    required this.sourceVersion,
    required this.license,
    required this.items,
  });

  /// Number of recipes — what the Settings success message reports.
  int get itemCount => items.length;

  static FoodCatalogueEnvelope parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw FormatException(
        'Catalogue file is not valid JSON: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Catalogue file must be a JSON object with schemaVersion and items',
      );
    }
    final version = decoded['schemaVersion'];
    if (version != supportedSchemaVersion) {
      throw FormatException(
        'Unsupported catalogue schemaVersion: $version '
        '(expected $supportedSchemaVersion)',
      );
    }
    final source = decoded['source'];
    if (source is! String || source.trim().isEmpty) {
      throw const FormatException('Catalogue file has no source code');
    }
    final items = decoded['items'];
    if (items is! List) {
      throw const FormatException('Catalogue file has no items list');
    }
    if (items.isEmpty) {
      throw const FormatException('Catalogue file contains no foods');
    }
    final parsed = <BundledFoodDTO>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map<String, dynamic>) {
        throw FormatException('Catalogue item $i is not an object');
      }
      final code = item['code'];
      final name = item['name'];
      if (code is! String || code.trim().isEmpty) {
        throw FormatException('Catalogue item $i has no code');
      }
      if (name is! String || name.trim().isEmpty) {
        throw FormatException('Catalogue item $i ($code) has no name');
      }
      parsed.add(BundledFoodDTO.fromJson(item));
    }
    return FoodCatalogueEnvelope(
      source: source.trim(),
      sourceVersion: decoded['sourceVersion'] is String
          ? decoded['sourceVersion']! as String
          : '',
      license: decoded['license'] is String
          ? decoded['license']! as String
          : '',
      items: parsed,
    );
  }
}
