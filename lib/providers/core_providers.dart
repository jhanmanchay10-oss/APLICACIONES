import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/env.dart';
import '../core/config/nutrition_criteria.dart';
import '../data/local_food_database.dart';
import '../repositories/meal_repository.dart';
import '../services/ai/food_recognition_service.dart';
import '../services/barcode/open_food_facts_service.dart';
import '../services/nutrition/recommendation_engine.dart';
import '../services/nutrition/traffic_light_service.dart';
import '../services/nutrition/weekly_summary_service.dart';
import '../services/storage/local_database.dart';
import '../services/storage/photo_storage.dart';
import '../services/sync/cloud_sync_service.dart';

/// Se sobrescriben en main() una vez inicializados.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final localDatabaseProvider = Provider<LocalDatabase>((ref) => throw UnimplementedError());

final nutritionCriteriaProvider = Provider<NutritionCriteria>((ref) => NutritionCriteria.standard);

final trafficLightServiceProvider = Provider<TrafficLightService>((ref) {
  final criteria = ref.watch(nutritionCriteriaProvider);
  return TrafficLightService(criteria: criteria, recommendations: RecommendationEngine(criteria: criteria));
});

final recommendationEngineProvider =
    Provider<RecommendationEngine>((ref) => RecommendationEngine(criteria: ref.watch(nutritionCriteriaProvider)));

final weeklySummaryServiceProvider =
    Provider<WeeklySummaryService>((ref) => WeeklySummaryService(criteria: ref.watch(nutritionCriteriaProvider)));

final localFoodDatabaseProvider = Provider<LocalFoodDatabase>((ref) => const LocalFoodDatabase());

final openFoodFactsServiceProvider = Provider<OpenFoodFactsService>((ref) => OpenFoodFactsService());

final foodRecognitionServiceProvider = Provider<FoodRecognitionService>(
  (ref) => FoodRecognitionService(enabled: Env.isSupabaseConfigured, database: ref.watch(localFoodDatabaseProvider)),
);

final photoStorageProvider = Provider<PhotoStorage>((ref) => const PhotoStorage());

final cloudSyncServiceProvider =
    Provider<CloudSyncService>((ref) => const CloudSyncService(enabled: Env.isSupabaseConfigured));

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(ref.watch(localDatabaseProvider), ref.watch(photoStorageProvider)),
);
