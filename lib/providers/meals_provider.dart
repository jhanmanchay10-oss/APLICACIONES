import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meal.dart';
import '../models/weekly_summary.dart';
import 'core_providers.dart';

class MealsNotifier extends AsyncNotifier<List<Meal>> {
  @override
  Future<List<Meal>> build() => ref.watch(mealRepositoryProvider).all();

  Future<void> add(Meal meal) async {
    await ref.read(mealRepositoryProvider).save(meal);
    state = AsyncData([meal, ...?state.value]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    _syncInBackground(meal);
  }

  Future<void> remove(Meal meal) async {
    await ref.read(mealRepositoryProvider).delete(meal);
    state = AsyncData([...?state.value?.where((item) => item.id != meal.id)]);
    try {
      await ref.read(cloudSyncServiceProvider).delete(meal);
    } catch (error) {
      debugPrint('No se pudo eliminar en la nube: $error');
    }
  }

  Future<void> removeAll() async {
    await ref.read(mealRepositoryProvider).deleteAll();
    state = const AsyncData([]);
  }

  /// Sube a la nube las comidas pendientes (por ejemplo, tras iniciar sesión).
  Future<int> syncPending() async {
    var count = 0;
    for (final meal in [...?state.value].where((meal) => !meal.synced)) {
      if (await _sync(meal)) count++;
    }
    return count;
  }

  void _syncInBackground(Meal meal) => _sync(meal);

  Future<bool> _sync(Meal meal) async {
    try {
      final synced = await ref.read(cloudSyncServiceProvider).upload(meal);
      if (!synced) return false;
      await ref.read(mealRepositoryProvider).markSynced(meal.id);
      state = AsyncData([
        for (final item in [...?state.value]) item.id == meal.id ? item.copyWith(synced: true) : item,
      ]);
      return true;
    } catch (error) {
      // La comida queda guardada localmente y se reintenta más tarde.
      debugPrint('Sincronización pendiente: $error');
      return false;
    }
  }
}

final mealsProvider = AsyncNotifierProvider<MealsNotifier, List<Meal>>(MealsNotifier.new);

/// Desplazamiento de semanas en la pantalla semanal (0 = semana actual).
class WeekOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void previous() => state = state - 1;

  void next() {
    if (state < 0) state = state + 1;
  }
}

final weekOffsetProvider = NotifierProvider<WeekOffsetNotifier, int>(WeekOffsetNotifier.new);

final weeklySummaryProvider = Provider<AsyncValue<WeeklySummary>>((ref) {
  final offset = ref.watch(weekOffsetProvider);
  final service = ref.watch(weeklySummaryServiceProvider);
  final reference = DateTime.now().add(Duration(days: 7 * offset));
  return ref.watch(mealsProvider).whenData((meals) => service.build(meals, reference));
});

/// Resumen de la semana actual, usado en Inicio y Recomendaciones.
final currentWeekSummaryProvider = Provider<AsyncValue<WeeklySummary>>((ref) {
  final service = ref.watch(weeklySummaryServiceProvider);
  return ref.watch(mealsProvider).whenData((meals) => service.build(meals, DateTime.now()));
});
