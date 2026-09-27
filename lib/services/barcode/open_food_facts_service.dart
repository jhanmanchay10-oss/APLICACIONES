import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../models/food_category.dart';
import '../../models/food_item.dart';
import '../../models/nutrients.dart';

/// Cliente de Open Food Facts (base de datos abierta de productos).
/// https://openfoodfacts.github.io/openfoodfacts-server/api/
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _fields = 'code,product_name,product_name_es,generic_name_es,brands,serving_size,quantity,'
      'nutriments,ingredients_text_es,ingredients_text,nova_group,image_front_small_url,'
      'image_front_url,categories_tags,nutriscore_grade';

  static final _barcodePattern = RegExp(r'^\d{6,14}$');

  static bool isValidBarcode(String code) => _barcodePattern.hasMatch(code.trim());

  Future<FoodItem> productByBarcode(String barcode) async {
    final code = barcode.trim();
    if (!isValidBarcode(code)) {
      throw const NotFoundException('El código de barras no es válido.');
    }
    final uri = Uri.parse('${AppConstants.openFoodFactsBaseUrl}/api/v2/product/$code.json')
        .replace(queryParameters: {'fields': _fields, 'lc': 'es'});
    final json = await _get(uri);

    final product = json['product'];
    if (json['status'] != 1 || product is! Map) {
      throw const NotFoundException(
        'No encontramos este producto. Puedes buscarlo manualmente o intentarlo con otro código.',
      );
    }
    final item = parseProduct(Map<String, dynamic>.from(product), fallbackCode: code);
    if (item == null) {
      throw const NotFoundException('Este producto no tiene información nutricional disponible.');
    }
    return item;
  }

  Future<List<FoodItem>> search(String query) async {
    final text = query.trim();
    if (text.length < 2) return const [];
    final uri = Uri.parse('${AppConstants.openFoodFactsBaseUrl}/cgi/search.pl').replace(queryParameters: {
      'search_terms': text,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '20',
      'fields': _fields,
      'lc': 'es',
    });
    final json = await _get(uri);
    final products = json['products'];
    if (products is! List) return const [];
    return products
        .whereType<Map>()
        .map((product) => parseProduct(Map<String, dynamic>.from(product)))
        .whereType<FoodItem>()
        .toList();
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': AppConstants.openFoodFactsUserAgent, 'Accept': 'application/json'})
          .timeout(AppConstants.requestTimeout);
      if (response.statusCode == 404) {
        return const {'status': 0};
      }
      if (response.statusCode != 200) {
        throw const NetworkException('El servicio de productos no está disponible ahora. Inténtalo más tarde.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('La conexión tardó demasiado. Inténtalo nuevamente.');
    } on FormatException {
      throw const NetworkException('Recibimos una respuesta inválida del servicio de productos.');
    }
  }

  /// Convierte un producto de Open Food Facts; devuelve null si no tiene nutrientes.
  static FoodItem? parseProduct(Map<String, dynamic> product, {String? fallbackCode}) {
    final nutriments = product['nutriments'];
    if (nutriments is! Map) return null;

    double? read(String key) {
      final value = nutriments['${key}_100g'];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final kcal = read('energy-kcal') ?? ((read('energy') ?? 0) / 4.184);
    final sodiumGrams = read('sodium') ?? ((read('salt') ?? 0) / 2.5);
    final hasData = [kcal, read('proteins'), read('carbohydrates'), read('fat')].any((value) => (value ?? 0) > 0);
    if (!hasData) return null;

    final name = _firstNonEmpty([product['product_name_es'], product['product_name'], product['generic_name_es']]);
    if (name == null) return null;

    final sugar = read('sugars') ?? 0;
    final tags = (product['categories_tags'] as List?)?.whereType<String>().toSet() ?? const <String>{};
    final nova = (product['nova_group'] as num?)?.toInt();
    final code = (product['code'] as String?) ?? fallbackCode;

    return FoodItem(
      id: 'off_${code ?? name.hashCode}',
      name: name,
      brand: _firstNonEmpty([product['brands']])?.split(',').first.trim(),
      barcode: code,
      servingSize: _firstNonEmpty([product['serving_size'], product['quantity']]),
      ingredients: _firstNonEmpty([product['ingredients_text_es'], product['ingredients_text']]),
      imageUrl: _firstNonEmpty([product['image_front_small_url'], product['image_front_url']]),
      nutriScoreGrade: _firstNonEmpty([product['nutriscore_grade']]),
      novaGroup: nova,
      category: _categoryFromTags(tags, sugarPer100g: sugar),
      typicalPortionGrams: _servingGrams(product['serving_size']) ?? 100,
      source: FoodSource.openFoodFacts,
      per100g: Nutrients(
        calories: kcal,
        protein: read('proteins') ?? 0,
        carbohydrates: read('carbohydrates') ?? 0,
        fat: read('fat') ?? 0,
        saturatedFat: read('saturated-fat') ?? 0,
        fiber: read('fiber') ?? 0,
        sugar: sugar,
        sodiumMg: sodiumGrams * 1000,
      ),
    );
  }

  static FoodCategory _categoryFromTags(Set<String> tags, {required double sugarPer100g}) {
    bool has(String tag) => tags.contains(tag);
    if (has('en:beverages')) {
      if (has('en:waters') || sugarPer100g < 1) return FoodCategory.beverage;
      return FoodCategory.sugaryDrink;
    }
    if (has('en:confectioneries') || has('en:sweet-snacks') || has('en:biscuits-and-cakes') || has('en:desserts')) {
      return FoodCategory.sweets;
    }
    if (has('en:salty-snacks') || has('en:appetizers') || has('en:crisps')) return FoodCategory.snack;
    if (has('en:processed-meats') || has('en:sausages') || has('en:hams')) return FoodCategory.processedMeat;
    if (has('en:dairies') || has('en:yogurts') || has('en:cheeses') || has('en:milks')) return FoodCategory.dairy;
    if (has('en:legumes') || has('en:pulses')) return FoodCategory.legume;
    if (has('en:nuts') || has('en:seeds')) return FoodCategory.nutsSeeds;
    if (has('en:fishes') || has('en:seafood') || has('en:canned-fishes')) return FoodCategory.fish;
    if (has('en:fruits') || has('en:fruits-based-foods')) return FoodCategory.fruit;
    if (has('en:vegetables') || has('en:vegetables-based-foods')) return FoodCategory.vegetable;
    if (has('en:whole-grain-breads') || has('en:oat-flakes') || has('en:whole-grain-pastas')) {
      return FoodCategory.wholeGrain;
    }
    if (has('en:breads') || has('en:pastas') || has('en:rices') || has('en:cereals-and-potatoes')) {
      return FoodCategory.refinedGrain;
    }
    if (has('en:fats') || has('en:vegetable-oils')) return FoodCategory.fatsOils;
    if (has('en:meals') || has('en:prepared-meals')) return FoodCategory.mixedDish;
    return FoodCategory.other;
  }

  static double? _servingGrams(Object? servingSize) {
    if (servingSize is! String) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b', caseSensitive: false).firstMatch(servingSize);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    return value == null || value <= 0 || value > AppConstants.maxFoodGrams ? null : value;
  }

  static String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
