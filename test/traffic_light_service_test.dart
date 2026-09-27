import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisemaforo/data/local_food_database.dart';
import 'package:nutrisemaforo/models/meal.dart';
import 'package:nutrisemaforo/models/traffic_light.dart';
import 'package:nutrisemaforo/services/nutrition/nutrition_score.dart';
import 'package:nutrisemaforo/services/nutrition/traffic_light_service.dart';

void main() {
  const database = LocalFoodDatabase();
  const service = TrafficLightService();

  MealFood item(String id, double grams) => MealFood(food: database.byId('local_$id')!, grams: grams);

  test('un plato equilibrado con verduras, legumbres y proteína es verde', () {
    final result = service.assess([
      item('arroz_integral', 150),
      item('lentejas', 150),
      item('pollo_plancha', 100),
      item('ensalada', 150),
    ]);
    expect(result.trafficLight, TrafficLight.green);
    expect(result.strengths, isNotEmpty);
  });

  test('una gaseosa es roja por azúcar añadido y ultraprocesamiento', () {
    final result = service.assess([item('gaseosa', 500)]);
    expect(result.trafficLight, TrafficLight.red);
    expect(result.factors.map((f) => f.id), contains(FactorIds.ultraProcessedHigh));
    expect(result.improvements, isNotEmpty);
  });

  test('una fruta entera es verde aunque tenga azúcares naturales', () {
    final result = service.assess([item('manzana', 150)]);
    expect(result.trafficLight, TrafficLight.green);
    expect(result.factors.map((f) => f.id), isNot(contains(FactorIds.sugarMedium)));
  });

  test('comida rápida con snacks es roja', () {
    final result = service.assess([item('hamburguesa', 220), item('papitas', 40), item('gaseosa', 500)]);
    expect(result.trafficLight, TrafficLight.red);
  });

  test('arroz con pollo sin verduras es naranja y sugiere añadir verduras', () {
    final result = service.assess([item('arroz_blanco', 200), item('pollo_brasa', 200)]);
    expect(result.trafficLight, TrafficLight.orange);
    expect(result.factors.map((f) => f.id), contains(FactorIds.fruitVegNone));
    expect(result.improvements.first.emoji, '🥦');
  });

  test('las calorías por sí solas no hacen rojo un alimento nutritivo', () {
    final result = service.assess([item('mani', 30)]);
    expect(result.trafficLight, isNot(TrafficLight.red));
  });

  test('una lista vacía no genera factores', () {
    final result = service.assess(const []);
    expect(result.factors, isEmpty);
    expect(result.summary, isNotEmpty);
  });
}
