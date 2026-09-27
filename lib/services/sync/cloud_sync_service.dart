import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/meal.dart';

/// Copia de seguridad en Supabase (Postgres + Storage). Solo se ejecuta
/// cuando Supabase está configurado y hay una sesión iniciada. Las políticas
/// RLS garantizan que cada usuario solo acceda a sus propios registros.
class CloudSyncService {
  const CloudSyncService({required this.enabled});

  final bool enabled;

  static const photoBucket = 'meal-photos';

  SupabaseClient get _client => Supabase.instance.client;

  bool get canSync => enabled && _client.auth.currentUser != null;

  /// Devuelve true si la comida quedó sincronizada.
  Future<bool> upload(Meal meal) async {
    if (!canSync) return false;
    final userId = _client.auth.currentUser!.id;

    String? photoPath;
    if (meal.photoPath != null && File(meal.photoPath!).existsSync()) {
      photoPath = '$userId/${meal.id}.jpg';
      await _client.storage.from(photoBucket).upload(
            photoPath,
            File(meal.photoPath!),
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
    }

    final totals = meal.totals;
    await _client.from('meals').upsert({
      'id': meal.id,
      'user_id': userId,
      'name': meal.name,
      'meal_type': meal.mealType.name,
      'source': meal.source.name,
      'photo_path': photoPath,
      'traffic_light': meal.trafficLight.name,
      'score': meal.score,
      'is_estimate': meal.isEstimate,
      'total_calories': totals.calories,
      'created_at': meal.createdAt.toUtc().toIso8601String(),
    });

    await _client.from('meal_foods').delete().eq('meal_id', meal.id);
    await _client.from('meal_foods').insert([
      for (final item in meal.foods)
        {
          'meal_id': meal.id,
          'user_id': userId,
          'food_name': item.food.name,
          'barcode': item.food.barcode,
          'category': item.food.category.name,
          'nova_group': item.food.novaGroup,
          'quantity_grams': item.grams,
          'confidence': item.confidence,
          'calories': item.nutrients.calories,
          'protein': item.nutrients.protein,
          'carbohydrates': item.nutrients.carbohydrates,
          'fat': item.nutrients.fat,
          'saturated_fat': item.nutrients.saturatedFat,
          'fiber': item.nutrients.fiber,
          'sugar': item.nutrients.sugar,
          'sodium_mg': item.nutrients.sodiumMg,
        },
    ]);
    return true;
  }

  Future<void> delete(Meal meal) async {
    if (!canSync) return;
    await _client.from('meals').delete().eq('id', meal.id);
    final userId = _client.auth.currentUser!.id;
    await _client.storage.from(photoBucket).remove(['$userId/${meal.id}.jpg']);
  }
}
