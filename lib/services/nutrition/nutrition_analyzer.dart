import '../../models/food_category.dart';
import '../../models/meal.dart';
import '../../models/nutrients.dart';

/// Perfil agregado de un conjunto de alimentos, independiente de los umbrales.
class NutritionProfile {
  const NutritionProfile({
    required this.totals,
    required this.totalGrams,
    required this.foodCount,
    required this.fruitVegGrams,
    required this.addedSugarGrams,
    required this.ultraProcessedGrams,
    required this.foodGroups,
    required this.hasProteinSource,
    required this.hasWholeGrainOrLegume,
  });

  final Nutrients totals;
  final double totalGrams;
  final int foodCount;
  final double fruitVegGrams;
  final double addedSugarGrams;
  final double ultraProcessedGrams;
  final Set<FoodCategory> foodGroups;
  final bool hasProteinSource;
  final bool hasWholeGrainOrLegume;

  bool get isEmpty => totalGrams <= 0;
  bool get isMeal => foodCount >= 2;

  double _per100g(double value) => isEmpty ? 0 : value / totalGrams * 100;

  double get addedSugarPer100g => _per100g(addedSugarGrams);
  double get saturatedFatPer100g => _per100g(totals.saturatedFat);
  double get sodiumMgPer100g => _per100g(totals.sodiumMg);
  double get fiberPer100g => _per100g(totals.fiber);

  double get fruitVegShare => isEmpty ? 0 : fruitVegGrams / totalGrams;
  double get ultraProcessedShare => isEmpty ? 0 : ultraProcessedGrams / totalGrams;

  /// Proporción de la energía que proviene de proteínas (4 kcal/g).
  double get proteinEnergyShare =>
      totals.calories <= 0 ? 0 : (totals.protein * 4 / totals.calories).clamp(0, 1).toDouble();
}

class NutritionAnalyzer {
  const NutritionAnalyzer();

  NutritionProfile analyze(List<MealFood> foods) {
    var totals = Nutrients.zero;
    var totalGrams = 0.0;
    var fruitVegGrams = 0.0;
    var addedSugarGrams = 0.0;
    var ultraProcessedGrams = 0.0;
    final groups = <FoodCategory>{};

    for (final item in foods) {
      if (item.grams <= 0) continue;
      final nutrients = item.nutrients;
      totals = totals + nutrients;
      totalGrams += item.grams;
      groups.add(item.food.category);
      if (item.food.category.isFruitOrVegetable) fruitVegGrams += item.grams;
      if (item.food.hasAddedSugar) addedSugarGrams += nutrients.sugar;
      if (item.food.isUltraProcessed) ultraProcessedGrams += item.grams;
    }

    return NutritionProfile(
      totals: totals,
      totalGrams: totalGrams,
      foodCount: foods.where((item) => item.grams > 0).length,
      fruitVegGrams: fruitVegGrams,
      addedSugarGrams: addedSugarGrams,
      ultraProcessedGrams: ultraProcessedGrams,
      foodGroups: groups,
      hasProteinSource: groups.any((group) => group.isProteinSource),
      hasWholeGrainOrLegume: groups.any((group) => group.isWholeGrainOrLegume),
    );
  }
}
