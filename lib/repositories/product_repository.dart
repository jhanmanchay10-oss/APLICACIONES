import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';
import '../models/food_item.dart';
import '../services/barcode/open_food_facts_service.dart';

/// Productos por código de barras: primero la copia guardada en el teléfono
/// (funciona sin internet), luego Open Food Facts. Cada producto encontrado o
/// leído de una etiqueta se guarda para la próxima vez.
class ProductRepository {
  ProductRepository(this._prefs, this._openFoodFacts);

  final SharedPreferences _prefs;
  final OpenFoodFactsService _openFoodFacts;

  static const _key = 'product_cache_v1';
  static const _maxProducts = 200;

  Map<String, dynamic> _readCache() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  FoodItem? cached(String barcode) {
    final entry = _readCache()[barcode];
    if (entry is! Map) return null;
    try {
      return FoodItem.fromJson(Map<String, dynamic>.from(entry));
    } catch (_) {
      return null;
    }
  }

  /// Productos guardados, del más reciente al más antiguo.
  List<FoodItem> recent() {
    final cache = _readCache();
    final items = <FoodItem>[];
    for (final entry in cache.values.toList().reversed) {
      if (entry is! Map) continue;
      try {
        items.add(FoodItem.fromJson(Map<String, dynamic>.from(entry)));
      } catch (_) {
        // Entrada dañada: se ignora.
      }
    }
    return items;
  }

  Future<void> save(FoodItem product) async {
    final code = product.barcode;
    if (code == null) return;
    final cache = _readCache()..remove(code);
    cache[code] = product.toJson();
    while (cache.length > _maxProducts) {
      cache.remove(cache.keys.first);
    }
    await _prefs.setString(_key, jsonEncode(cache));
  }

  /// Busca un producto. Lanza [NotFoundException] si no existe en ninguna fuente.
  Future<FoodItem> byBarcode(String barcode) async {
    final code = barcode.trim();
    final local = cached(code);
    try {
      final product = await _openFoodFacts.productByBarcode(code);
      await save(product);
      return product;
    } on NetworkException {
      if (local != null) return local;
      rethrow;
    } on NotFoundException {
      // Productos leídos de la etiqueta con IA quedan guardados en el teléfono.
      if (local != null) return local;
      rethrow;
    }
  }
}
