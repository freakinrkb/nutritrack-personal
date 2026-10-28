/// Fiber goal derived from energy intake using IOM guidance:
/// adequate intake is 14 g per 1,000 kcal.
class FiberGoalCalc {
  FiberGoalCalc._();

  static const double gramsPer1000Kcal = 14.0;
  static const double minGrams = 5.0;
  static const double maxGrams = 80.0;

  /// Returns the energy-based fiber target in grams for [kcalGoal].
  ///
  /// Returns null when [kcalGoal] is not finite or <= 0 so callers can fall
  /// back to published references.
  static double? fromKcal(double? kcalGoal, {bool roundToWholeGram = true}) {
    if (kcalGoal == null || !kcalGoal.isFinite || kcalGoal <= 0) {
      return null;
    }
    final grams = kcalGoal * gramsPer1000Kcal / 1000.0;
    final result = roundToWholeGram ? grams.roundToDouble() : grams;
    return result.clamp(minGrams, maxGrams);
  }

  /// Returns a human-friendly display string for the auto-calculated target.
  static String format(double kcalGoal) {
    final grams = fromKcal(kcalGoal);
    if (grams == null) return '—';
    return '${grams.toStringAsFixed(0)} g';
  }

  /// Approximate kcal equivalent for display/estimation only.
  static double kcalEquivalent(double fiberGrams) =>
      fiberGrams * 1000.0 / gramsPer1000Kcal;
}
