/// Stable identifiers for the daily nutrient panel's rows.
///
/// These strings key the per-nutrient visibility and durable goal maps on
/// [ConfigEntity], so renaming any of them is a backward-incompatible change:
/// existing overrides would silently lose their associations.
class NutrientPanelKeys {
  NutrientPanelKeys._();

  static const String fiber = 'fiber';
  static const String sodium = 'sodium';
  static const String saturatedFat = 'saturated_fat';
  static const String sugar = 'sugar';
  static const String calcium = 'calcium';
  static const String iron = 'iron';
  static const String potassium = 'potassium';
  static const String vitaminD = 'vitamin_d';
  static const String vitaminB12 = 'vitamin_b12';
  static const String magnesium = 'magnesium';

  static const List<String> all = <String>[
    fiber,
    sodium,
    saturatedFat,
    sugar,
    calcium,
    iron,
    potassium,
    vitaminD,
    vitaminB12,
    magnesium,
  ];
}
