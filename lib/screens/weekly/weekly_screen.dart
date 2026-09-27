import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/nutrition_criteria.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../models/traffic_light.dart';
import '../../models/weekly_summary.dart';
import '../../providers/core_providers.dart';
import '../../providers/meals_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/traffic_light_indicator.dart';
import '../shell/app_shell.dart';

class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySummaryProvider);
    final offset = ref.watch(weekOffsetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi semana')),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: friendlyError(error)),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Semana anterior',
                  onPressed: ref.read(weekOffsetProvider.notifier).previous,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    offset == 0 ? 'Esta semana · ${AppDates.weekRange(data.weekStart)}' : AppDates.weekRange(data.weekStart),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Semana siguiente',
                  onPressed: offset < 0 ? ref.read(weekOffsetProvider.notifier).next : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DaysCard(summary: data),
            const SizedBox(height: 16),
            const SectionHeader('Resumen'),
            _CountsRow(summary: data),
            const SizedBox(height: 16),
            if (data.current.hasData) ...[
              const SectionHeader('Comidas por día'),
              _MealsChart(summary: data),
              const SizedBox(height: 16),
            ],
            const SectionHeader('Tendencias'),
            _TrendsCard(summary: data, goals: ref.watch(nutritionCriteriaProvider)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => ref.read(tabIndexProvider.notifier).select(AppTab.recommendations),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('¿Qué puedo mejorar?'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaysCard extends StatelessWidget {
  const _DaysCard({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final day in summary.days)
              ListTile(
                dense: true,
                title: Text(
                  AppDates.weekdayName(day.date),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppDates.isSameDay(day.date, DateTime.now()) ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  day.meals.isEmpty
                      ? 'Sin registros'
                      : '${day.meals.length} ${day.meals.length == 1 ? 'comida' : 'comidas'}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Semantics(
                  label: day.trafficLight == null ? 'Sin registros' : 'Día en ${day.trafficLight!.label}',
                  child: TrafficDot(light: day.trafficLight, size: 22),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final light in TrafficLight.values) ...[
            Expanded(
              child: Card(
                color: AppColors.softFor(light, Theme.of(context).brightness),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text(light.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 6),
                      Text('${summary.countMeals(light)}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text('comidas', style: Theme.of(context).textTheme.bodySmall),
                      Text('${summary.countDays(light)} días', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
            if (light != TrafficLight.red) const SizedBox(width: 10),
          ],
        ],
      );
}

class _MealsChart extends StatelessWidget {
  const _MealsChart({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final maxMeals = summary.days.fold<int>(1, (max, day) => day.meals.length > max ? day.meals.length : max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxMeals.toDouble(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 11)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= summary.days.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(AppDates.weekdayShort(summary.days[index].date),
                            style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < summary.days.length; i++) _group(i, summary.days[i]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BarChartGroupData _group(int index, DaySummary day) {
    var from = 0.0;
    final stacks = <BarChartRodStackItem>[];
    for (final light in [TrafficLight.green, TrafficLight.orange, TrafficLight.red]) {
      final count = day.meals.where((meal) => meal.trafficLight == light).length;
      if (count == 0) continue;
      stacks.add(BarChartRodStackItem(from, from + count, AppColors.forLight(light)));
      from += count;
    }
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: from,
          width: 18,
          rodStackItems: stacks,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}

class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.summary, required this.goals});

  final WeeklySummary summary;
  final NutritionCriteria goals;

  @override
  Widget build(BuildContext context) {
    final current = summary.current;
    final previous = summary.previous;
    if (!current.hasData) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Registra comidas para ver tus tendencias de la semana.'),
        ),
      );
    }
    final hasPrevious = previous.hasData;
    final rows = <_Trend>[
      _Trend('🥦', 'Frutas y verduras', '${Fmt.number(current.fruitVegServingsPerDay)} de ${(goals.dailyFruitVegGrams / goals.fruitVegServingGrams).round()} porciones/día',
          current.fruitVegServingsPerDay, previous.fruitVegServingsPerDay, higherIsBetter: true),
      _Trend('🌾', 'Fibra', '${Fmt.grams(current.fiberPerDay)} de ${goals.dailyFiberGoalGrams.round()} g/día', current.fiberPerDay, previous.fiberPerDay,
          higherIsBetter: true),
      _Trend('🌈', 'Variedad', '${current.distinctFoods} alimentos distintos', current.distinctFoods.toDouble(),
          previous.distinctFoods.toDouble(), higherIsBetter: true),
      _Trend('🐟', 'Fuentes de proteína', '${current.proteinSourceTypes} tipos', current.proteinSourceTypes.toDouble(),
          previous.proteinSourceTypes.toDouble(), higherIsBetter: true),
      _Trend('🏭', 'Ultraprocesados', '${current.ultraProcessedMeals} comidas', current.ultraProcessedMeals.toDouble(),
          previous.ultraProcessedMeals.toDouble(), higherIsBetter: false),
      _Trend('🍬', 'Azúcares añadidos', '≈ ${Fmt.grams(current.addedSugarPerDay)}/día', current.addedSugarPerDay,
          previous.addedSugarPerDay, higherIsBetter: false),
      _Trend('🧂', 'Sodio', '≈ ${Fmt.mg(current.sodiumMgPerDay)}/día', current.sodiumMgPerDay,
          previous.sodiumMgPerDay, higherIsBetter: false),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final row in rows)
              ListTile(
                leading: Text(row.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(row.label),
                subtitle: Text(row.value),
                trailing: hasPrevious ? _TrendArrow(trend: row) : null,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                hasPrevious
                    ? 'Las flechas comparan con la semana anterior. Los promedios usan solo los días con registros.'
                    : 'Los promedios usan solo los días con registros.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Trend {
  const _Trend(this.emoji, this.label, this.value, this.current, this.previous, {required this.higherIsBetter});

  final String emoji;
  final String label;
  final String value;
  final double current;
  final double previous;
  final bool higherIsBetter;
}

class _TrendArrow extends StatelessWidget {
  const _TrendArrow({required this.trend});

  final _Trend trend;

  @override
  Widget build(BuildContext context) {
    final difference = trend.current - trend.previous;
    final threshold = (trend.previous.abs() * 0.05).clamp(0.1, double.infinity);
    if (difference.abs() < threshold) {
      return const Icon(Icons.trending_flat, semanticLabel: 'Sin cambios');
    }
    final up = difference > 0;
    final good = up == trend.higherIsBetter;
    return Icon(
      up ? Icons.trending_up : Icons.trending_down,
      color: good ? AppColors.green : AppColors.orange,
      semanticLabel: good ? 'Mejoró' : 'Empeoró',
    );
  }
}
