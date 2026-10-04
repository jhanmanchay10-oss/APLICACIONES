import 'dart:convert';
import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_utils.dart';
import '../../models/food_category.dart';
import '../../models/food_item.dart';
import '../../models/nutrients.dart';
import 'ai_client.dart';

/// Lee con IA la tabla nutricional de un envase (cuando el código de barras
/// no está en Open Food Facts).
class LabelReaderService {
  const LabelReaderService(this._client);

  final AiClient _client;

  bool get enabled => _client.enabled;

  Future<FoodItem> read(File photo, {String? barcode}) async {
    final bytes = await photo.readAsBytes();
    final lower = photo.path.toLowerCase();
    final mediaType = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    final json = await _client.invoke(
      'read-label',
      {'image_base64': base64Encode(bytes), 'media_type': mediaType},
      timeout: AppConstants.analysisTimeout,
    );
    return parse(json, barcode: barcode);
  }

  static FoodItem parse(Map<String, dynamic> json, {String? barcode}) {
    if (json['is_readable'] != true) {
      final notes = TextUtils.sanitize((json['notes'] as String?) ?? '', maxLength: 300);
      throw NotFoundException(notes.isEmpty
          ? 'No pudimos leer la etiqueta. Acércate a la tabla nutricional y busca buena luz.'
          : notes);
    }
    final per100g = json['per_100g'];
    final nutrients = per100g is Map ? Nutrients.fromJson(Map<String, dynamic>.from(per100g)) : Nutrients.zero;
    if (nutrients.calories <= 0 && nutrients.carbohydrates <= 0 && nutrients.protein <= 0 && nutrients.fat <= 0) {
      throw const NotFoundException('No encontramos valores nutricionales en la foto. Enfoca la tabla del envase.');
    }

    String? text(String key, {int max = 80}) {
      final value = TextUtils.sanitize((json[key] as String?) ?? '', maxLength: max);
      return value.isEmpty ? null : value;
    }

    final servingGrams = (json['serving_grams'] as num?)?.toDouble() ?? 0;
    final name = text('name') ?? 'Producto escaneado';
    return FoodItem(
      id: 'label_${barcode ?? TextUtils.normalize(name).hashCode}',
      name: name,
      brand: text('brand', max: 60),
      barcode: barcode,
      servingSize: text('serving_size', max: 60),
      ingredients: text('ingredients', max: 1500),
      category: FoodCategory.fromName(json['category'] as String?),
      novaGroup: (json['nova_group'] as num?)?.toInt().clamp(1, 4),
      typicalPortionGrams:
          servingGrams > 0 && servingGrams <= AppConstants.maxFoodGrams ? servingGrams : 100,
      source: FoodSource.ai,
      per100g: nutrients,
      warnings: (json['warning_octagons'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}
