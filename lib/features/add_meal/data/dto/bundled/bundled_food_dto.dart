/// One item of a food catalogue bundled inside the app, independent of any
/// network source. The first (and currently only) catalogue is the Anuvaad
/// Indian Nutrient Databank recipe list; see
/// `assets/food/indb_recipes.json`, whose envelope records the source,
/// version and CC BY 4.0 licence.
///
/// Nutrient values are per 100 g in the canonical units the app displays
/// (kcal / g / mg / µg — the same units `MealNutrimentsEntity` and the
/// Supabase `food_summary` view use), so mapping to a meal is a
/// field-for-field copy with no conversions. A hand-written `fromJson`
/// rather than `json_serializable`: the shape is fixed by the asset this
/// class ships with, and a generated `.g.dart` for a file that never comes
/// from an API would be pure ceremony.
class BundledFoodDTO {
  /// Stable identifier, namespaced by source (`indb:ASC001`) so it can
  /// never collide with a backend food_id in the search cache or the
  /// dedup key.
  final String code;
  final String name;

  final double? energyKcal100;
  final double? carbohydrates100;
  final double? fat100;
  final double? proteins100;
  final double? sugars100;
  final double? saturatedFat100;
  final double? fiber100;
  final double? monounsaturatedFat100;
  final double? polyunsaturatedFat100;
  final double? transFat100;
  final double? cholesterol100;
  final double? sodium100;
  final double? potassium100;
  final double? magnesium100;
  final double? calcium100;
  final double? iron100;
  final double? zinc100;
  final double? phosphorus100;
  final double? vitaminA100;
  final double? vitaminC100;
  final double? vitaminD100;
  final double? vitaminB6100;
  final double? vitaminB12100;
  final double? niacin100;

  const BundledFoodDTO({
    required this.code,
    required this.name,
    required this.energyKcal100,
    required this.carbohydrates100,
    required this.fat100,
    required this.proteins100,
    this.sugars100,
    this.saturatedFat100,
    this.fiber100,
    this.monounsaturatedFat100,
    this.polyunsaturatedFat100,
    this.transFat100,
    this.cholesterol100,
    this.sodium100,
    this.potassium100,
    this.magnesium100,
    this.calcium100,
    this.iron100,
    this.zinc100,
    this.phosphorus100,
    this.vitaminA100,
    this.vitaminC100,
    this.vitaminD100,
    this.vitaminB6100,
    this.vitaminB12100,
    this.niacin100,
  });

  factory BundledFoodDTO.fromJson(Map<String, dynamic> json) => BundledFoodDTO(
    code: json['code'] as String,
    name: json['name'] as String,
    energyKcal100: _asDouble(json['energyKcal100']),
    carbohydrates100: _asDouble(json['carbohydrates100']),
    fat100: _asDouble(json['fat100']),
    proteins100: _asDouble(json['proteins100']),
    sugars100: _asDouble(json['sugars100']),
    saturatedFat100: _asDouble(json['saturatedFat100']),
    fiber100: _asDouble(json['fiber100']),
    monounsaturatedFat100: _asDouble(json['monounsaturatedFat100']),
    polyunsaturatedFat100: _asDouble(json['polyunsaturatedFat100']),
    transFat100: _asDouble(json['transFat100']),
    cholesterol100: _asDouble(json['cholesterol100']),
    sodium100: _asDouble(json['sodium100']),
    potassium100: _asDouble(json['potassium100']),
    magnesium100: _asDouble(json['magnesium100']),
    calcium100: _asDouble(json['calcium100']),
    iron100: _asDouble(json['iron100']),
    zinc100: _asDouble(json['zinc100']),
    phosphorus100: _asDouble(json['phosphorus100']),
    vitaminA100: _asDouble(json['vitaminA100']),
    vitaminC100: _asDouble(json['vitaminC100']),
    vitaminD100: _asDouble(json['vitaminD100']),
    vitaminB6100: _asDouble(json['vitaminB6100']),
    vitaminB12100: _asDouble(json['vitaminB12100']),
    niacin100: _asDouble(json['niacin100']),
  );

  /// JSON numbers arrive as `int` or `double`; anything else (the `null`s
  /// the asset uses for nutrients INDB does not publish, e.g. trans fat and
  /// B12) stays null rather than becoming a cast error mid-search.
  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;
}
