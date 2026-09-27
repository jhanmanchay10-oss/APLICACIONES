import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../models/meal.dart';
import '../../providers/core_providers.dart';
import '../../providers/meals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/nutrition_widgets.dart';
import '../navigation.dart';

/// Resultado nutricional de una comida nueva o guardada.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.meal, required this.isNew});

  final Meal meal;
  final bool isNew;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      var meal = widget.meal;
      if (meal.photoPath != null) {
        final stored = await ref.read(photoStorageProvider).saveMealPhoto(File(meal.photoPath!), meal.id);
        meal = meal.copyWith(photoPath: stored);
      }
      await ref.read(mealsProvider.notifier).add(meal);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      AppNavigation.backToHome(context);
      messenger.showSnackBar(const SnackBar(content: Text('Comida guardada en tu historial ✅')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar esta comida?'),
        content: const Text('Se borrará de tu historial y no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(mealsProvider.notifier).remove(widget.meal);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meal = widget.meal;
    final assessment = ref.watch(trafficLightServiceProvider).assess(meal.foods);
    final showCalories = ref.watch(settingsProvider.select((settings) => settings.showCalories));
    final totals = meal.totals;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Resultado' : meal.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (!widget.isNew)
            IconButton(tooltip: 'Eliminar comida', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      bottomNavigationBar: widget.isNew
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Guardar en mi historial'),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (!widget.isNew && meal.photoPath != null) ...[
            MealPhoto(path: meal.photoPath, radius: 20),
            const SizedBox(height: 14),
          ],
          if (!widget.isNew) ...[
            Text(
              '${meal.mealType.emoji} ${meal.mealType.label} · ${AppDates.dayLabel(meal.createdAt)} · '
              '${AppDates.time(meal.createdAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
          ],
          AssessmentHeader(assessment: assessment),
          if (meal.isEstimate) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              message: 'Los valores se calcularon a partir de una foto y son estimaciones, no valores exactos.',
            ),
          ],
          const SizedBox(height: 12),
          AssessmentDetails(assessment: assessment),
          const SizedBox(height: 12),
          const SectionHeader('Información nutricional'),
          NutrientGrid(nutrients: totals, showCalories: showCalories, isEstimate: meal.isEstimate),
          const SizedBox(height: 12),
          MacroChart(nutrients: totals),
          const SizedBox(height: 12),
          const SectionHeader('Alimentos'),
          Card(
            child: Column(
              children: [
                for (final item in meal.foods)
                  ListTile(
                    leading: Text(item.food.category.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(item.food.name),
                    subtitle: Text(item.food.category.label),
                    trailing: Text(
                      '${meal.isEstimate ? '≈ ' : ''}${Fmt.grams(item.grams)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'El semáforo considera frutas y verduras, fibra, proteínas, variedad, azúcares añadidos, '
            'grasas saturadas, sodio y nivel de procesamiento; no se basa en las calorías. '
            'Es orientativo y no reemplaza la consulta con un profesional.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
