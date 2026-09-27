import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisemaforo/models/food_category.dart';
import 'package:nutrisemaforo/models/food_item.dart';
import 'package:nutrisemaforo/services/ai/food_recognition_service.dart';
import 'package:nutrisemaforo/services/barcode/open_food_facts_service.dart';

void main() {
  group('Open Food Facts', () {
    test('convierte un producto con nutrientes por 100 g', () {
      final item = OpenFoodFactsService.parseProduct({
        'code': '7750182001234',
        'product_name_es': 'Galletas de chocolate',
        'brands': 'Marca, Otra',
        'serving_size': '6 galletas (36 g)',
        'nova_group': 4,
        'categories_tags': ['en:snacks', 'en:sweet-snacks', 'en:biscuits-and-cakes'],
        'nutriments': {
          'energy-kcal_100g': 480,
          'proteins_100g': 6,
          'carbohydrates_100g': 68,
          'fat_100g': 20,
          'saturated-fat_100g': 9,
          'sugars_100g': 30,
          'fiber_100g': 2,
          'salt_100g': 0.9,
        },
      })!;
      expect(item.name, 'Galletas de chocolate');
      expect(item.brand, 'Marca');
      expect(item.category, FoodCategory.sweets);
      expect(item.typicalPortionGrams, 36);
      expect(item.per100g.sodiumMg, closeTo(360, 0.1));
      expect(item.isUltraProcessed, isTrue);
      expect(item.source, FoodSource.openFoodFacts);
    });

    test('devuelve null si no hay información nutricional', () {
      expect(OpenFoodFactsService.parseProduct({'product_name': 'X', 'nutriments': {}}), isNull);
    });

    test('valida códigos de barras', () {
      expect(OpenFoodFactsService.isValidBarcode('7750182001234'), isTrue);
      expect(OpenFoodFactsService.isValidBarcode('abc'), isFalse);
    });
  });

  group('Reconocimiento de alimentos', () {
    const service = FoodRecognitionService(enabled: false);

    test('usa la base local cuando reconoce el alimento y respeta la cantidad', () {
      final result = service.parse({
        'overall_confidence': 0.8,
        'foods': [
          {'name': 'arroz blanco', 'estimated_grams': 180, 'confidence': 0.9},
          {
            'name': 'guiso misterioso',
            'estimated_grams': 5000,
            'confidence': 0.3,
            'category': 'mixedDish',
            'per_100g': {'calories': 150, 'protein': 8, 'sodium_mg': 400},
          },
        ],
      });
      expect(result.foods, hasLength(2));
      expect(result.foods.first.food.source, FoodSource.local);
      expect(result.foods.first.grams, 180);
      expect(result.foods.last.food.source, FoodSource.ai);
      expect(result.foods.last.grams, 3000);
      expect(result.foods.last.food.category, FoodCategory.mixedDish);
      expect(result.isLowConfidence, isFalse);
    });

    test('marca baja confianza', () {
      final result = service.parse({'overall_confidence': 0.3, 'foods': []});
      expect(result.isLowConfidence, isTrue);
    });
  });
}
