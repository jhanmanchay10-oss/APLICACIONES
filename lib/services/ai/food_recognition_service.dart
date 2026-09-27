import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_utils.dart';
import '../../data/local_food_database.dart';
import '../../models/food_category.dart';
import '../../models/food_item.dart';
import '../../models/meal.dart';
import '../../models/nutrients.dart';

class RecognitionResult {
  const RecognitionResult({required this.foods, required this.confidence, this.notes});

  final List<MealFood> foods;

  /// Confianza global del análisis (0-1).
  final double confidence;
  final String? notes;

  bool get isLowConfidence => foods.isEmpty || confidence < AppConstants.lowConfidenceThreshold;
}

/// Identifica alimentos en una foto. La clave de la IA vive en el servidor
/// (Supabase Edge Function `analyze-meal`), nunca en la aplicación.
class FoodRecognitionService {
  const FoodRecognitionService({required this.enabled, this.database = const LocalFoodDatabase()});

  /// false cuando Supabase no está configurado en esta compilación.
  final bool enabled;
  final LocalFoodDatabase database;

  bool get requiresSignIn => enabled && Supabase.instance.client.auth.currentSession == null;

  Future<RecognitionResult> recognize(File image) async {
    if (!enabled) {
      throw const ConfigurationException(
        'El análisis automático no está configurado en esta versión. Agrega los alimentos manualmente.',
      );
    }
    if (requiresSignIn) {
      throw const AccountException('Inicia sesión en tu perfil para usar el análisis con IA.');
    }

    final bytes = await image.readAsBytes();
    final lower = image.path.toLowerCase();
    final mediaType = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');

    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions
          .invoke('analyze-meal', body: {'image_base64': base64Encode(bytes), 'media_type': mediaType})
          .timeout(AppConstants.analysisTimeout);
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw const AccountException('Tu sesión expiró. Vuelve a iniciar sesión.');
      }
      if (error.status == 429) {
        throw const AnalysisException('Has hecho muchos análisis seguidos. Espera un momento e inténtalo de nuevo.');
      }
      throw const AnalysisException();
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('El análisis tardó demasiado. Inténtalo nuevamente.');
    }

    final data = response.data;
    final json = data is String ? jsonDecode(data) : data;
    if (json is! Map) throw const AnalysisException();
    return parse(Map<String, dynamic>.from(json));
  }

  /// Convierte la respuesta de la IA en alimentos editables. Si un alimento
  /// existe en la base local se usan esos nutrientes (más fiables); si no,
  /// se usan los estimados por la IA.
  RecognitionResult parse(Map<String, dynamic> json) {
    final rawFoods = (json['foods'] as List?)?.whereType<Map>() ?? const <Map>[];
    final foods = <MealFood>[];

    for (final raw in rawFoods) {
      final name = TextUtils.sanitize((raw['name'] as String?) ?? '');
      if (name.isEmpty) continue;
      final grams = ((raw['estimated_grams'] as num?)?.toDouble() ?? 100).clamp(1, AppConstants.maxFoodGrams);
      final confidence = ((raw['confidence'] as num?)?.toDouble() ?? 0.5).clamp(0, 1).toDouble();

      final local = database.bestMatch(name);
      final food = local?.copyWith(name: _capitalize(name)) ?? _fromAi(raw, name);
      foods.add(MealFood(food: food, grams: grams.toDouble(), confidence: confidence));
    }

    return RecognitionResult(
      foods: foods,
      confidence: ((json['overall_confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  FoodItem _fromAi(Map raw, String name) {
    final per100g = raw['per_100g'];
    return FoodItem(
      id: 'ai_${TextUtils.normalize(name).hashCode}',
      name: _capitalize(name),
      category: FoodCategory.fromName(raw['category'] as String?),
      novaGroup: (raw['nova_group'] as num?)?.toInt().clamp(1, 4),
      source: FoodSource.ai,
      per100g: per100g is Map ? Nutrients.fromJson(Map<String, dynamic>.from(per100g)) : Nutrients.zero,
    );
  }

  static String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
