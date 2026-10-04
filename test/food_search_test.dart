import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisemaforo/data/local_food_database.dart';
import 'package:nutrisemaforo/models/food_category.dart';
import 'package:nutrisemaforo/models/food_item.dart';
import 'package:nutrisemaforo/services/ai/assistant_service.dart';
import 'package:nutrisemaforo/services/ai/label_reader_service.dart';
import 'package:nutrisemaforo/core/errors/app_exception.dart';

void main() {
  const database = LocalFoodDatabase();

  group('Búsqueda local', () {
    test('encuentra huevos cocidos aunque se escriban en plural y con preparación', () {
      expect(database.search('huevos cocidos').first.name, 'Huevo');
      expect(database.search('Huevo sancochado').first.name, 'Huevo');
      expect(database.search('2 huevos').first.name, 'Huevo');
    });

    test('ignora tildes y prioriza el plato completo', () {
      expect(database.search('papa a la huancaina').first.name, 'Papa a la huancaína');
      expect(database.search('arroz con pollo').first.name, 'Arroz con pollo');
      expect(database.search('lomo saltado').first.name, 'Lomo saltado');
      expect(database.search('frejoles').first.name, 'Frejoles');
    });

    test('bestMatch solo acepta coincidencias completas', () {
      expect(database.bestMatch('arroz blanco cocido')?.name, 'Arroz blanco');
      expect(database.bestMatch('guiso misterioso'), isNull);
      expect(database.bestMatch('papa a la huancaína')?.name, 'Papa a la huancaína');
    });

    test('incluye comida peruana', () {
      for (final name in ['ceviche', 'causa', 'chaufa', 'anticuchos', 'lucuma', 'chicha morada', 'picarones']) {
        expect(database.search(name), isNotEmpty, reason: name);
      }
    });
  });

  group('Lectura de etiquetas', () {
    test('convierte la respuesta de la IA en un producto con octógonos', () {
      final product = LabelReaderService.parse({
        'is_readable': true,
        'name': 'Galletas de chocolate',
        'brand': 'Marca',
        'serving_size': '1 paquete (40 g)',
        'serving_grams': 40,
        'category': 'sweets',
        'nova_group': 4,
        'per_100g': {'calories': 480, 'sugar': 30, 'sodium_mg': 350, 'saturated_fat': 9},
        'warning_octagons': ['high_sugar', 'high_saturated_fat'],
        'ingredients': 'harina, azúcar',
        'notes': '',
      }, barcode: '7750000000001');
      expect(product.name, 'Galletas de chocolate');
      expect(product.barcode, '7750000000001');
      expect(product.category, FoodCategory.sweets);
      expect(product.typicalPortionGrams, 40);
      expect(product.warnings, ['high_sugar', 'high_saturated_fat']);
      expect(product.source, FoodSource.ai);
      expect(FoodItem.fromJson(product.toJson()).warnings, product.warnings);
    });

    test('avisa si la etiqueta no se puede leer', () {
      expect(
        () => LabelReaderService.parse({'is_readable': false, 'notes': 'Acércate más.'}),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  test('el contexto del asistente funciona sin registros', () {
    expect(AssistantService.buildContext(), contains('aún no tiene comidas'));
  });
}
