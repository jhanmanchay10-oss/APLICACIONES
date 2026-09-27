import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisemaforo/data/local_food_database.dart';
import 'package:nutrisemaforo/models/meal.dart';
import 'package:nutrisemaforo/models/traffic_light.dart';
import 'package:nutrisemaforo/services/nutrition/recommendation_engine.dart';
import 'package:nutrisemaforo/services/nutrition/weekly_summary_service.dart';

void main() {
  const database = LocalFoodDatabase();

  Meal meal(DateTime date, TrafficLight light, List<(String, double)> foods) => Meal(
        id: '${date.millisecondsSinceEpoch}',
        createdAt: date,
        mealType: MealType.lunch,
        name: 'Prueba',
        foods: [for (final (id, grams) in foods) MealFood(food: database.byId('local_$id')!, grams: grams)],
        trafficLight: light,
        score: 0,
        source: MealSource.search,
      );

  test('agrupa por día (lunes a domingo) y calcula el color del día', () {
    final monday = DateTime(2026, 9, 21, 13);
    final meals = [
      meal(monday, TrafficLight.green, [('ensalada', 100)]),
      meal(monday.add(const Duration(hours: 6)), TrafficLight.green, [('manzana', 150)]),
      meal(monday.add(const Duration(days: 5)), TrafficLight.red, [('gaseosa', 500)]),
    ];
    final summary = const WeeklySummaryService().build(meals, DateTime(2026, 9, 24));

    expect(summary.weekStart, DateTime(2026, 9, 21));
    expect(summary.days.first.trafficLight, TrafficLight.green);
    expect(summary.days[5].trafficLight, TrafficLight.red);
    expect(summary.days[1].trafficLight, isNull);
    expect(summary.countMeals(TrafficLight.green), 2);
    expect(summary.current.daysWithMeals, 2);
    expect(summary.current.ultraProcessedMeals, 1);

    final tips = const RecommendationEngine().weekly(summary);
    expect(tips.first.message, contains('2 comidas en verde'));
  });

  test('sin registros sugiere empezar a registrar', () {
    final summary = const WeeklySummaryService().build(const [], DateTime(2026, 9, 24));
    expect(summary.current.hasData, isFalse);
    expect(const RecommendationEngine().weekly(summary), hasLength(1));
  });
}
