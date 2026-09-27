import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/meal.dart';
import '../../models/traffic_light.dart';
import '../../providers/meals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/meal_tile.dart';
import '../navigation.dart';

class HistoryFilterNotifier extends Notifier<TrafficLight?> {
  @override
  TrafficLight? build() => null;

  void toggle(TrafficLight light) => state = state == light ? null : light;
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, TrafficLight?>(HistoryFilterNotifier.new);

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(mealsProvider);
    final filter = ref.watch(historyFilterProvider);
    final showCalories = ref.watch(settingsProvider.select((settings) => settings.showCalories));

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: meals.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: friendlyError(error), onRetry: () => ref.invalidate(mealsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              emoji: '📅',
              title: 'Tu historial está vacío',
              message: 'Cada comida que registres aparecerá aquí con su semáforo.',
              action: FilledButton.icon(
                onPressed: () => AppNavigation.analyzePlate(context),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Analizar un plato'),
              ),
            );
          }
          final filtered = filter == null ? items : items.where((meal) => meal.trafficLight == filter).toList();
          final groups = <DateTime, List<Meal>>{};
          for (final meal in filtered) {
            groups.putIfAbsent(AppDates.dateOnly(meal.createdAt), () => []).add(meal);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final light in TrafficLight.values)
                    FilterChip(
                      label: Text('${light.emoji} ${light.label[0]}${light.label.substring(1).toLowerCase()}'),
                      selected: filter == light,
                      onSelected: (_) => ref.read(historyFilterProvider.notifier).toggle(light),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay comidas con este filtro.', textAlign: TextAlign.center),
                ),
              for (final entry in groups.entries) ...[
                SectionHeader(AppDates.dayLabel(entry.key)),
                for (final meal in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MealTile(
                      meal: meal,
                      showCalories: showCalories,
                      onTap: () => AppNavigation.openMeal(context, meal),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
