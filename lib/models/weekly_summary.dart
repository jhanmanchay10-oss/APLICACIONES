import 'meal.dart';
import 'traffic_light.dart';

class DaySummary {
  const DaySummary({required this.date, required this.meals, this.trafficLight});

  final DateTime date;
  final List<Meal> meals;

  /// null cuando no hay comidas registradas ese día.
  final TrafficLight? trafficLight;
}

/// Indicadores de hábitos. Los valores "por día" se promedian sobre los días
/// con al menos un registro, para no penalizar días sin registrar.
class WeeklyTrends {
  const WeeklyTrends({
    required this.mealCount,
    required this.daysWithMeals,
    required this.fruitVegServingsPerDay,
    required this.fiberPerDay,
    required this.distinctFoods,
    required this.proteinSourceTypes,
    required this.ultraProcessedMeals,
    required this.addedSugarPerDay,
    required this.sodiumMgPerDay,
  });

  final int mealCount;
  final int daysWithMeals;
  final double fruitVegServingsPerDay;
  final double fiberPerDay;
  final int distinctFoods;
  final int proteinSourceTypes;
  final int ultraProcessedMeals;
  final double addedSugarPerDay;
  final double sodiumMgPerDay;

  bool get hasData => mealCount > 0;

  static const empty = WeeklyTrends(
    mealCount: 0,
    daysWithMeals: 0,
    fruitVegServingsPerDay: 0,
    fiberPerDay: 0,
    distinctFoods: 0,
    proteinSourceTypes: 0,
    ultraProcessedMeals: 0,
    addedSugarPerDay: 0,
    sodiumMgPerDay: 0,
  );
}

class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.days,
    required this.current,
    required this.previous,
  });

  final DateTime weekStart;
  final List<DaySummary> days;
  final WeeklyTrends current;
  final WeeklyTrends previous;

  Iterable<Meal> get meals => days.expand((day) => day.meals);

  int countMeals(TrafficLight light) => meals.where((meal) => meal.trafficLight == light).length;

  int countDays(TrafficLight light) => days.where((day) => day.trafficLight == light).length;
}
