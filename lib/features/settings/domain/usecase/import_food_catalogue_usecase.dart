import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/imported_food_catalogue_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/bundled_food_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/bundled/food_catalogue_envelope.dart';
import 'package:opennutritracker/features/add_meal/data/dto/sp/sp_const.dart';
import 'package:opennutritracker/features/settings/domain/export_import_failure.dart';

/// Outcome of a catalogue import: the number of recipes stored on success,
/// or the reason nothing was written. Cancelled picks never reach a result
/// — [ImportFoodCatalogueUsecase.importFromPickedFile] returns null, the
/// same contract the CSV/JSON meal importers use — so the screen shows no
/// error for a picker the user backed out of.
class ImportFoodCatalogueResult {
  final int? itemCount;
  final ExportImportFailureReason? failureReason;

  const ImportFoodCatalogueResult.success(int this.itemCount)
    : failureReason = null;

  const ImportFoodCatalogueResult.failure(
    ExportImportFailureReason this.failureReason,
  ) : itemCount = null;

  bool get isSuccess => itemCount != null;
}

/// Imports a food catalogue file (the same envelope the app bundles at
/// `assets/food/indb_recipes.json`) so search uses a newer drop of a source
/// than the one shipped in the binary — without rebuilding or updating the
/// app.
///
/// The file is validated against `FoodCatalogueEnvelope.parse`, the one
/// schema authority shared with the bundled asset, then stored verbatim in
/// the imported-catalogue box under its `source` code. Only `indb` is
/// accepted: the merged-search reader (`BundledFoodDataSource`) tags every
/// row it returns with that source's toggle and display name, so an
/// unknown source would mislabel its foods.
class ImportFoodCatalogueUsecase {
  final _log = Logger('ImportFoodCatalogueUsecase');

  final ImportedFoodCatalogueDataSource _catalogueBox;
  final BundledFoodDataSource _bundledCatalogue;

  ImportFoodCatalogueUsecase(this._catalogueBox, this._bundledCatalogue);

  /// Picks a `.json` file, imports it, and returns null when the user
  /// cancelled the picker (mirroring [ImportMealsJsonUsecase]'s contract).
  Future<ImportFoodCatalogueResult?> importFromPickedFile() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || picked.path == null) return null;
    String content;
    try {
      content = await File(picked.path!).readAsString(encoding: utf8);
    } on FileSystemException catch (error, stack) {
      _log.warning('Could not read picked catalogue file', error, stack);
      return const ImportFoodCatalogueResult.failure(
        ExportImportFailureReason.unreadableOrWrongFormat,
      );
    }
    return importFromJsonString(content);
  }

  /// Validates [jsonContent] and stores it as the active imported catalogue
  /// for INDB, replacing any previously imported file. The search catalogue
  /// is invalidated so the very next query serves the new rows.
  Future<ImportFoodCatalogueResult> importFromJsonString(
    String jsonContent,
  ) async {
    FoodCatalogueEnvelope envelope;
    try {
      envelope = FoodCatalogueEnvelope.parse(jsonContent);
    } on FormatException catch (error) {
      _log.info('Rejected catalogue file: ${error.message}');
      return const ImportFoodCatalogueResult.failure(
        ExportImportFailureReason.unreadableOrWrongFormat,
      );
    }
    if (envelope.source != SPConst.indbSourceCode) {
      return const ImportFoodCatalogueResult.failure(
        ExportImportFailureReason.unreadableOrWrongFormat,
      );
    }
    try {
      await _catalogueBox.write(SPConst.indbSourceCode, jsonContent);
    } catch (error, stack) {
      _log.warning('Could not store imported catalogue', error, stack);
      return const ImportFoodCatalogueResult.failure(
        ExportImportFailureReason.writeFailed,
      );
    }
    _bundledCatalogue.invalidateCatalogue();
    return ImportFoodCatalogueResult.success(envelope.itemCount);
  }

  /// Recipe count of the stored imported file, or null when the user has
  /// imported nothing (or the stored copy no longer parses — search treats
  /// it the same way, skipping it in favour of the bundled asset).
  Future<int?> importedItemCount() async {
    String? stored;
    try {
      stored = await _catalogueBox.read(SPConst.indbSourceCode);
    } catch (error, stack) {
      // Settings must still open with its toggles if the box is unhappy.
      _log.warning('Could not read imported catalogue', error, stack);
      return null;
    }
    if (stored == null) return null;
    try {
      return FoodCatalogueEnvelope.parse(stored).itemCount;
    } on FormatException {
      return null;
    }
  }

  /// Removes the imported catalogue so search falls back to the bundled
  /// asset alone.
  Future<void> removeImportedCatalogue() async {
    await _catalogueBox.delete(SPConst.indbSourceCode);
    _bundledCatalogue.invalidateCatalogue();
  }
}
