import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/nutrients.dart';
import '../models/nutrition_assessment.dart';
import 'common.dart';
import 'traffic_light_indicator.dart';

/// Tarjeta principal: semáforo + titular + explicación.
class AssessmentHeader extends StatelessWidget {
  const AssessmentHeader({super.key, required this.assessment});

  final NutritionAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = assessment.trafficLight;
    final color = AppColors.forLight(light);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softFor(light, theme.brightness),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          TrafficLightIndicator(light: light, lampSize: 30),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${light.emoji} ${light.label}',
                  style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(light.headline, style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                Text(assessment.summary, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección "¿Por qué?" y "¿Qué puedes mejorar?".
class AssessmentDetails extends StatelessWidget {
  const AssessmentDetails({super.key, required this.assessment});

  final NutritionAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final factors = [...assessment.strengths, ...assessment.concerns];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('¿Por qué?'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (factors.isEmpty)
                  const ListTile(title: Text('No hay suficientes datos para explicar el resultado.')),
                for (final factor in factors)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      factor.isPositive ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: factor.isPositive
                          ? AppColors.green
                          : (factor.isHighConcern ? AppColors.red : AppColors.orange),
                    ),
                    title: Text(factor.explanation, style: const TextStyle(fontSize: 14.5)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader('💡 ¿Qué puedes mejorar?'),
        RecommendationList(recommendations: assessment.improvements),
      ],
    );
  }
}

class RecommendationList extends StatelessWidget {
  const RecommendationList({super.key, required this.recommendations});

  final List<Recommendation> recommendations;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final tip in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(tip.message, style: const TextStyle(height: 1.4, fontSize: 14.5))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
}

/// Cuadrícula de nutrientes con etiquetas claras.
class NutrientGrid extends StatelessWidget {
  const NutrientGrid({
    super.key,
    required this.nutrients,
    required this.showCalories,
    this.isEstimate = false,
    this.showSaturatedFat = true,
  });

  final Nutrients nutrients;
  final bool showCalories;
  final bool isEstimate;
  final bool showSaturatedFat;

  @override
  Widget build(BuildContext context) {
    final prefix = isEstimate ? '≈ ' : '';
    final items = <(String, String, String)>[
      if (showCalories) ('🔥', isEstimate ? 'Calorías estimadas' : 'Calorías', '$prefix${Fmt.kcal(nutrients.calories)}'),
      ('💪', 'Proteínas', '$prefix${Fmt.grams(nutrients.protein)}'),
      ('🍞', 'Carbohidratos', '$prefix${Fmt.grams(nutrients.carbohydrates)}'),
      ('🥑', 'Grasas', '$prefix${Fmt.grams(nutrients.fat)}'),
      if (showSaturatedFat) ('🧈', 'Grasas saturadas', '$prefix${Fmt.grams(nutrients.saturatedFat)}'),
      ('🌾', 'Fibra', '$prefix${Fmt.grams(nutrients.fiber)}'),
      ('🍬', 'Azúcares', '$prefix${Fmt.grams(nutrients.sugar)}'),
      ('🧂', 'Sodio', '$prefix${Fmt.mg(nutrients.sodiumMg)}'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (emoji, label, value) in items)
              SizedBox(width: width, child: _NutrientTile(emoji: emoji, label: label, value: value)),
          ],
        );
      },
    );
  }
}

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({required this.emoji, required this.label, required this.value});

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Distribución de la energía entre proteínas, carbohidratos y grasas.
class MacroChart extends StatelessWidget {
  const MacroChart({super.key, required this.nutrients});

  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) {
    final protein = nutrients.protein * 4;
    final carbs = nutrients.carbohydrates * 4;
    final fat = nutrients.fat * 9;
    final total = protein + carbs + fat;
    if (total <= 0) return const SizedBox.shrink();

    final slices = [
      ('Proteínas', protein, const Color(0xFF3F7CC7)),
      ('Carbohidratos', carbs, const Color(0xFFE7B53C)),
      ('Grasas', fat, const Color(0xFF9A6BC9)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: [
                    for (final (_, value, color) in slices)
                      PieChartSectionData(value: value, color: color, radius: 26, showTitle: false),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Origen de la energía', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  for (final (label, value, color) in slices)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label)),
                          Text('${(value / total * 100).round()} %',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
