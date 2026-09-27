import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/food_item.dart';
import '../../models/meal.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/nutrition_widgets.dart';
import '../navigation.dart';
import '../result/meal_editor_screen.dart';

/// Ficha de un producto envasado con su semáforo nutricional.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.product});

  final FoodItem product;

  static const _novaLabels = {
    1: 'Sin procesar o mínimamente procesado',
    2: 'Ingrediente culinario procesado',
    3: 'Procesado',
    4: 'Ultraprocesado',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showCalories = ref.watch(settingsProvider.select((settings) => settings.showCalories));
    final assessment = ref.watch(trafficLightServiceProvider).assess([MealFood(food: product, grams: 100)]);

    return Scaffold(
      appBar: AppBar(title: const Text('Producto')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Registrar en mis comidas'),
            onPressed: () => AppNavigation.push(
              context,
              MealEditorScreen(
                initialFoods: [MealFood(food: product, grams: product.typicalPortionGrams)],
                source: MealSource.barcode,
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 84,
                  child: product.imageUrl == null
                      ? ColoredBox(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: const Center(child: Text('📦', style: TextStyle(fontSize: 36))),
                        )
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          semanticLabel: 'Imagen de ${product.name}',
                          errorBuilder: (_, _, _) => const Center(child: Text('📦', style: TextStyle(fontSize: 36))),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.titleLarge),
                    if (product.brand != null) Text(product.brand!, style: theme.textTheme.bodyMedium),
                    if (product.servingSize != null)
                      Text('Porción: ${product.servingSize}', style: theme.textTheme.bodySmall),
                    if (product.barcode != null)
                      Text('Código: ${product.barcode}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AssessmentHeader(assessment: assessment),
          const SizedBox(height: 12),
          AssessmentDetails(assessment: assessment),
          const SizedBox(height: 12),
          const SectionHeader('Información nutricional (por 100 g)'),
          NutrientGrid(nutrients: product.per100g, showCalories: showCalories),
          const SizedBox(height: 12),
          MacroChart(nutrients: product.per100g),
          const SizedBox(height: 12),
          const SectionHeader('Información adicional'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Categoría'),
                  subtitle: Text('${product.category.emoji} ${product.category.label}'),
                ),
                if (product.novaGroup != null)
                  ListTile(
                    leading: const Icon(Icons.factory_outlined),
                    title: Text('Procesamiento (NOVA ${product.novaGroup})'),
                    subtitle: Text(_novaLabels[product.novaGroup] ?? 'Sin información'),
                  ),
                if (product.nutriScoreGrade != null && product.nutriScoreGrade!.length == 1)
                  ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Nutri-Score (Open Food Facts)'),
                    subtitle: Text(product.nutriScoreGrade!.toUpperCase()),
                  ),
              ],
            ),
          ),
          if (product.ingredients != null) ...[
            const SizedBox(height: 12),
            const SectionHeader('Ingredientes'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(product.ingredients!, style: const TextStyle(height: 1.4)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Datos de Open Food Facts, una base colaborativa. Verifica la etiqueta del envase si tienes dudas.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
