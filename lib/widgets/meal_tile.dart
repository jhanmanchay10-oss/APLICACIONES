import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';
import '../core/utils/formatters.dart';
import '../models/meal.dart';
import 'common.dart';
import 'traffic_light_indicator.dart';

class MealTile extends StatelessWidget {
  const MealTile({super.key, required this.meal, required this.onTap, required this.showCalories});

  final Meal meal;
  final VoidCallback onTap;
  final bool showCalories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      '${meal.mealType.label} · ${AppDates.time(meal.createdAt)}',
      if (showCalories) '${meal.isEstimate ? '≈ ' : ''}${Fmt.kcal(meal.totals.calories)}',
    ].join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              MealPhoto(path: meal.photoPath, size: 60, fallbackEmoji: meal.mealType.emoji),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(details,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TrafficLightBadge(light: meal.trafficLight, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
