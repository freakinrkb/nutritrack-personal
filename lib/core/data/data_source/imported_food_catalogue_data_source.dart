import 'package:hive_ce_flutter/hive_flutter.dart';

/// Storage for food catalogue files the user imports in Settings → Food
/// databases (a newer drop of a source the app also bundles, e.g. the
/// Anuvaad INDB recipe list).
///
/// One box, global (shared across profiles — it is a food database, not
/// personal data), keyed by `food_source.code`; the value is the file's
/// envelope JSON verbatim. Storing the JSON rather than parsed rows keeps
/// the file re-readable for validation and lets `BundledFoodDataSource`
/// merge it with the bundled asset through the one schema authority,
/// `FoodCatalogueEnvelope.parse`.
///
/// The box is injected (as `RemoteSearchCacheDataSource`'s boxes are) so
/// tests can open a throwaway `Box<String>` without a full provider.
class ImportedFoodCatalogueDataSource {
  final Box<String> _box;

  ImportedFoodCatalogueDataSource(this._box);

  /// The stored envelope for [sourceCode], or null when the user has
  /// imported nothing for that source (or removed it again).
  Future<String?> read(String sourceCode) async => _box.get(sourceCode);

  /// Replaces any stored envelope for [sourceCode]. A re-import of the
  /// same source overwrites rather than accumulates: there is exactly one
  /// imported catalogue per source, the newest file the user picked.
  Future<void> write(String sourceCode, String envelopeJson) =>
      _box.put(sourceCode, envelopeJson);

  /// Drops the imported catalogue for [sourceCode], so search falls back
  /// to the bundled asset alone. No-op when nothing is stored.
  Future<void> delete(String sourceCode) => _box.delete(sourceCode);
}
