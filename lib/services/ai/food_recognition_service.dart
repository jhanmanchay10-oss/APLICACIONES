import 'dart:convert';
import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_utils.dart';
import '../../data/local_food_database.dart';
import '../../models/food_category.dart';
import '../../models/food_item.dart';
import '../../models/meal.dart';
import '../../models/nutrients.dart';
import 'ai_client.dart';

class RecognitionResult {
  const RecognitionResult({required this.foods, required this.confidence, this.notes, this.dishName});

  final List<MealFood> foods;

  /// Confianza global del análisis (0-1).
  final double confidence;
  final String? notes;

  /// Nombre del plato reconocido (ej. "Lomo saltado"), si aplica.
  final String? dishName;

  bool get isLowConfidence => foods.isEmpty || confidence < AppConstants.lowConfidenceThreshold;
}

/// Identifica alimentos en una foto o en un texto escrito por el usuario.
/// La clave de la IA vive en el servidor (Edge Functions), nunca en la aplicación.
class FoodRecognitionService {
  const FoodRecognitionService({
    required this.enabled,
    this.database = const LocalFoodDatabase(),
    this.client,
  });

  /// false cuando Supabase no está configurado en esta compilación.
  final bool enabled;
  final LocalFoodDatabase database;
  final AiClient? client;

  AiClient get _client => client ?? AiClient(enabled: enabled);

  Future<RecognitionResult> recognize(File image) async {
    if (!enabled) throw const ConfigurationException(AiClient.notConfiguredMessage);
    final bytes = await image.readAsBytes();
    final lower = image.path.toLowerCase();
    final mediaType = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    final json = await _client.invoke(
      'analyze-meal',
      {'image_base64': base64Encode(bytes), 'media_type': mediaType},
      timeout: AppConstants.analysisTimeout,
    );
    return parse(json);
  }

  /// Estima un alimento escrito (ej. "2 huevos cocidos") cuando no está en la base local.
  Future<RecognitionResult> estimateFromText(String query) async {
    if (!enabled) throw const ConfigurationException(AiClient.notConfiguredMessage);
    final text = TextUtils.sanitize(query, maxLength: 200);
    if (text.length < 2) throw const AnalysisException('Escribe el nombre del alimento.');
    final json = await _client.invoke('estimate-food', {'query': text}, timeout: const Duration(seconds: 45));
    final result = parse(json, preferLocal: false);
    if (result.foods.isEmpty) {
      throw const NotFoundException('No reconocimos ese alimento. Prueba con otro nombre.');
    }
    return result;
  }

  /// Convierte la respuesta de la IA en alimentos editables. Si un alimento
  /// existe en la base local se usan esos nutrientes (más fiables); si no,
  /// se usan los estimados por la IA.
  RecognitionResult parse(Map<String, dynamic> json, {bool preferLocal = true}) {
    final rawFoods = (json['foods'] as List?)?.whereType<Map>() ?? const <Map>[];
    final foods = <MealFood>[];

    for (final raw in rawFoods) {
      final name = TextUtils.sanitize((raw['name'] as String?) ?? '');
      if (name.isEmpty) continue;
      final grams = ((raw['estimated_grams'] as num?)?.toDouble() ?? 100).clamp(1, AppConstants.maxFoodGrams);
      final confidence = ((raw['confidence'] as num?)?.toDouble() ?? 0.5).clamp(0, 1).toDouble();

      final local = preferLocal ? database.bestMatch(name) : null;
      final food = local?.copyWith(name: _capitalize(name)) ?? _fromAi(raw, name);
      foods.add(MealFood(food: food, grams: grams.toDouble(), confidence: confidence));
    }

    final dishName = TextUtils.sanitize((json['dish_name'] as String?) ?? '');
    final notes = TextUtils.sanitize((json['notes'] as String?) ?? '', maxLength: 300);
    return RecognitionResult(
      foods: foods,
      confidence: ((json['overall_confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble(),
      notes: notes.isEmpty ? null : notes,
      dishName: dishName.isEmpty ? null : dishName,
    );
  }

  FoodItem _fromAi(Map raw, String name) {
    final per100g = raw['per_100g'];
    final portion = (raw['estimated_grams'] as num?)?.toDouble();
    return FoodItem(
      id: 'ai_${TextUtils.normalize(name).hashCode}',
      name: _capitalize(name),
      category: FoodCategory.fromName(raw['category'] as String?),
      novaGroup: (raw['nova_group'] as num?)?.toInt().clamp(1, 4),
      typicalPortionGrams:
          (portion == null || portion <= 0) ? 100 : portion.clamp(1, AppConstants.maxFoodGrams).toDouble(),
      source: FoodSource.ai,
      per100g: per100g is Map ? Nutrients.fromJson(Map<String, dynamic>.from(per100g)) : Nutrients.zero,
    );
  }

  static String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
