import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/traffic_light.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';

/// Explica de forma transparente los criterios del semáforo.
class CriteriaScreen extends ConsumerWidget {
  const CriteriaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(nutritionCriteriaProvider);
    final theme = Theme.of(context);
    String n(double value) => value == value.roundToDouble() ? value.round().toString() : value.toString();

    final positives = [
      '🥦 Frutas y verduras (más puntos si son ≥ ${(c.fruitVegGoodShare * 100).round()} % del plato)',
      '🌾 Fibra (fuente ≥ ${n(c.fiberSourcePer100g)} g/100 g · alto ≥ ${n(c.fiberHighPer100g)} g/100 g)',
      '💪 Fuente de proteína',
      '🌈 Variedad (≥ ${c.varietyGroupsForBonus} grupos de alimentos)',
      '🫘 Cereales integrales o legumbres',
    ];
    final negatives = [
      '🍬 Azúcares añadidos (moderado > ${n(c.addedSugarLowPer100g)} g · alto > ${n(c.addedSugarHighPer100g)} g por 100 g)',
      '🧈 Grasas saturadas (moderado > ${n(c.saturatedFatLowPer100g)} g · alto > ${n(c.saturatedFatHighPer100g)} g por 100 g)',
      '🧂 Sodio (moderado > ${n(c.sodiumLowMgPer100g)} mg · alto > ${n(c.sodiumHighMgPer100g)} mg por 100 g)',
      '🏭 Productos ultraprocesados (clasificación NOVA 4)',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cómo funciona')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            'El semáforo evalúa la calidad nutricional del conjunto, no las calorías. '
            'Cada aspecto suma o resta puntos y el total define el color.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          for (final light in TrafficLight.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                color: AppColors.softFor(light, theme.brightness),
                child: ListTile(
                  leading: Text(light.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(light.label, style: TextStyle(color: AppColors.forLight(light), fontWeight: FontWeight.w800)),
                  subtitle: Text(switch (light) {
                    TrafficLight.green => 'Puntuación ≥ ${c.greenMinScore} y ningún nutriente en nivel alto.',
                    TrafficLight.orange => 'Tiene aspectos positivos y otros que conviene equilibrar.',
                    TrafficLight.red =>
                      'Puntuación ≤ ${c.redMaxScore} o ${c.highConcernsForRed} o más nutrientes en nivel alto.',
                  }),
                ),
              ),
            ),
          const SectionHeader('Suman puntos'),
          for (final item in positives) _Bullet(item),
          const SectionHeader('Restan puntos'),
          for (final item in negatives) _Bullet(item),
          const SizedBox(height: 16),
          const InfoBanner(
            message: 'Referencias: umbrales del etiquetado frontal de la FSA (Reino Unido), declaraciones '
                'nutricionales de la UE (Reglamento 1924/2006), recomendaciones de la OMS y la clasificación '
                'NOVA. Es una herramienta educativa y no reemplaza la orientación profesional.',
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
      );
}
