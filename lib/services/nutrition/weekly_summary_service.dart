import '../../core/config/nutrition_criteria.dart';
import '../../core/utils/date_utils.dart';
import '../../models/meal.dart';
import '../../models/traffic_light.dart';
import '../../models/weekly_summary.dart';

class WeeklySummaryService {
  const WeeklySummaryService({this.criteria = NutritionCriteria.standard});

  final NutritionCriteria criteria;

  /// Resumen de la semana (lunes a domingo) que contiene [reference].
  WeeklySummary build(List<Meal> meals, DateTime reference) {
    final weekStart = AppDates.startOfWeek(reference);
    final previousStart = weekStart.subtract(const Duration(days: 7));

    final days = List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final dayMeals = meals.where((meal) => AppDates.isSameDay(meal.createdAt, date)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return DaySummary(date: date, meals: dayMeals, trafficLight: _dayLight(dayMeals));
    });

    return WeeklySummary(
      weekStart: weekStart,
      days: days,
      current: trendsFor(_inRange(meals, weekStart)),
      previous: trendsFor(_inRange(meals, previousStart)),
    );
  }

  List<Meal> _inRange(List<Meal> meals, DateTime start) {
    final end = start.add(const Duration(days: 7));
    return meals.where((meal) => !meal.createdAt.isBefore(start) && meal.createdAt.isBefore(end)).toList();
  }

  TrafficLight? _dayLight(List<Meal> meals) {
    if (meals.isEmpty) return null;
    final average = meals.fold<int>(0, (sum, meal) => sum + meal.trafficLight.value) / meals.length;
    return TrafficLight.fromAverage(average);
  }

  WeeklyTrends trendsFor(List<Meal> meals) {
    if (meals.isEmpty) return WeeklyTrends.empty;

    final days = meals.map((meal) => AppDates.dateOnly(meal.createdAt)).toSet().length;
    var fruitVegGrams = 0.0;
    var fiber = 0.0;
    var addedSugar = 0.0;
    var sodium = 0.0;
    var ultraProcessedMeals = 0;
    final distinctFoods = <String>{};
    final proteinTypes = <String>{};

    for (final meal in meals) {
      var hasUltraProcessed = false;
      for (final item in meal.foods) {
        final nutrients = item.nutrients;
        final category = item.food.category;
        if (category.isFruitOrVegetable) fruitVegGrams += item.grams;
        if (category.isProteinSource) proteinTypes.add(category.name);
        if (item.food.hasAddedSugar) addedSugar += nutrients.sugar;
        if (item.food.isUltraProcessed) hasUltraProcessed = true;
        fiber += nutrients.fiber;
        sodium += nutrients.sodiumMg;
        distinctFoods.add(item.food.name.trim().toLowerCase());
      }
      if (hasUltraProcessed) ultraProcessedMeals++;
    }

    return WeeklyTrends(
      mealCount: meals.length,
      daysWithMeals: days,
      fruitVegServingsPerDay: fruitVegGrams / criteria.fruitVegServingGrams / days,
      fiberPerDay: fiber / days,
      distinctFoods: distinctFoods.length,
      proteinSourceTypes: proteinTypes.length,
      ultraProcessedMeals: ultraProcessedMeals,
      addedSugarPerDay: addedSugar / days,
      sodiumMgPerDay: sodium / days,
    );
  }
}
