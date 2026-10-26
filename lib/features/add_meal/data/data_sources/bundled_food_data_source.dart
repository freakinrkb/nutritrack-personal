import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/imported_food_catalogue_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/bundled/bundled_food_dto.dart';
import 'package:opennutritracker/features/add_meal/data/dto/bundled/food_catalogue_envelope.dart';
import 'package:opennutritracker/features/add_meal/data/dto/sp/sp_const.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// The Indian food catalogue searchable without any network round-trip.
///
/// Two files make up the catalogue, both read through
/// `FoodCatalogueEnvelope.parse` — what ships is what is accepted:
///  * the bundled asset [assetPath], generated from Anuvaad's Indian
///    Nutrient Databank recipe workbook (2024.11, CC BY 4.0; attribution in
///    the envelope and in Settings → Food databases);
///  * the user's imported file, if any (Settings → Food databases →
///    import), whose rows **replace** bundled rows with the same code and
///    add newer ones — so importing a 2025.07 drop upgrades the catalogue
///    without rebuilding the app.
///
/// Unlike `OFFDataSource` and `SpFoodDataSource`, neither file ever comes
/// off the network. A search is a substring scan over ~1,000 names, cheap
/// enough to run on every keystroke on the UI isolate once the catalogue has
/// been parsed once, which is what the cached [_catalogue] future ensures;
/// an import calls [invalidateCatalogue] so the next search re-reads.
class BundledFoodDataSource {
  /// Bundled INDB recipe catalogue. Registered in `pubspec.yaml`.
  static const assetPath = 'assets/food/indb_recipes.json';

  /// Same cut the backend search RPCs keep — twenty rows per source is what
  /// the result list is designed around.
  static const maxResults = 20;

  static final _log = Logger('BundledFoodDataSource');

  final Future<String> Function() _loadAsset;

  /// Where imported catalogue files live, or null in tests that exercise
  /// the bundled asset alone.
  final ImportedFoodCatalogueDataSource? _importedCatalogue;

  /// Parsed catalogue, created on first use and kept until
  /// [invalidateCatalogue]. The asset is a few hundred kilobytes; parsing
  /// it twice would be waste, and holding the DTOs is cheaper than
  /// re-decoding the JSON each search.
  Future<List<BundledFoodDTO>>? _catalogue;

  /// [loadAsset] is injectable so tests can feed a fixture catalogue without
  /// a Flutter asset bundle (see `bundled_food_data_source_test.dart`).
  BundledFoodDataSource({
    Future<String> Function()? loadAsset,
    ImportedFoodCatalogueDataSource? importedCatalogue,
  }) : _loadAsset = loadAsset ?? _loadBundledAsset,
       _importedCatalogue = importedCatalogue;

  static Future<String> _loadBundledAsset() => rootBundle.loadString(assetPath);

  /// Drops the parsed catalogue so the next [search] re-reads the bundled
  /// asset and the imported file. Called after an import replaces or
  /// removes the user's catalogue — without it the session would keep
  /// serving the pre-import file.
  void invalidateCatalogue() => _catalogue = null;

  /// The up-to-[maxResults] best name matches for [searchString], best first.
  ///
  /// Every whitespace-separated query token must appear in the food's name
  /// ("plain khichdi" matches "Plain khitchdi (Plain khichri/khichdi)",
  /// "khichdi tea" does not). Within that, names that equal the query rank
  /// above ones that start with it, which rank above token-prefix matches,
  /// which rank above a match buried mid-word; ties break by shorter name,
  /// then alphabetically, so the list is stable across searches.
  ///
  /// Throws only if the bundled asset itself cannot be read or parsed — the
  /// caller treats that as "this source contributed nothing".
  Future<List<MealEntity>> search(String searchString) async {
    final query = searchString.trim().toLowerCase();
    if (query.isEmpty) return const <MealEntity>[];

    final tokens = query.split(RegExp(r'\s+'));
    final scored = <({int score, int length, MealEntity meal})>[];
    for (final food in await _loadCatalogue()) {
      final score = _matchScore(food.name.toLowerCase(), query, tokens);
      if (score == null) continue;
      scored.add((
        score: score,
        length: food.name.length,
        meal: MealEntity.fromBundledFood(food),
      ));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byLength = a.length.compareTo(b.length);
      if (byLength != 0) return byLength;
      return a.meal.name!.compareTo(b.meal.name!);
    });
    return [for (final entry in scored.take(maxResults)) entry.meal];
  }

  /// How well [name] matches, or null when it does not match at all.
  static int? _matchScore(String name, String query, List<String> tokens) {
    if (name == query) return 3000;
    if (name.startsWith(query)) return 2000;
    final words = name.split(RegExp(r'[^a-z0-9]+'));
    final allWordPrefixes = tokens.every(
      (token) => words.any((word) => word.startsWith(token)),
    );
    if (allWordPrefixes) return 1000;
    final allSubstrings = tokens.every(name.contains);
    return allSubstrings ? 500 : null;
  }

  Future<List<BundledFoodDTO>> _loadCatalogue() => _catalogue =
      _catalogue ?? _parseCatalogue().catchError(_handleParseFailure);

  /// A failed load must not be cached as a permanent empty catalogue: the
  /// next search retries, so a transient failure heals instead of silently
  /// hiding the bundled foods for the rest of the session.
  Future<List<BundledFoodDTO>> _handleParseFailure(
    Object error,
    StackTrace st,
  ) {
    _log.warning('Could not read bundled food catalogue', error, st);
    _catalogue = null;
    return Future.error(error, st);
  }

  Future<List<BundledFoodDTO>> _parseCatalogue() async {
    final bundled = FoodCatalogueEnvelope.parse(await _loadAsset());
    final byCode = {for (final food in bundled.items) food.code: food};
    await _applyImported(byCode);
    return byCode.values.toList();
  }

  /// Overlays the user's imported catalogue (if any) onto [byCode]:
  /// imported rows replace bundled rows with the same code and add the ones
  /// only the newer file carries.
  ///
  /// A stored file that no longer parses — corrupt storage, or a downgrade
  /// after a schema bump that old data missed — must not take the bundled
  /// catalogue down with it: it is logged and skipped, and search falls
  /// back to what shipped in the app.
  Future<void> _applyImported(Map<String, BundledFoodDTO> byCode) async {
    final imported = _importedCatalogue;
    if (imported == null) return;
    String? stored;
    try {
      stored = await imported.read(SPConst.indbSourceCode);
    } catch (error, stack) {
      _log.warning('Could not read imported food catalogue', error, stack);
      return;
    }
    if (stored == null) return;
    try {
      final envelope = FoodCatalogueEnvelope.parse(stored);
      if (envelope.source != SPConst.indbSourceCode) return;
      for (final food in envelope.items) {
        byCode[food.code] = food;
      }
    } on FormatException catch (error) {
      _log.warning(
        'Ignoring unreadable imported food catalogue; using the bundled '
        'one: ${error.message}',
      );
    }
  }
}
