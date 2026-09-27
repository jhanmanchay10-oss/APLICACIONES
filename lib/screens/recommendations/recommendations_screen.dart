import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../providers/core_providers.dart';
import '../../providers/meals_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/nutrition_widgets.dart';
import '../navigation.dart';
import 'criteria_screen.dart';

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(currentWeekSummaryProvider);
    final engine = ref.watch(recommendationEngineProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('¿Qué puedes mejorar?')),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: friendlyError(error)),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(
              'Ideas basadas en lo que registraste esta semana. Pequeños cambios sostenidos '
              'hacen una gran diferencia. 🌱',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            RecommendationList(recommendations: engine.weekly(data)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => AppNavigation.push(context, const CriteriaScreen()),
              icon: const Icon(Icons.traffic_outlined),
              label: const Text('¿Cómo funciona el semáforo?'),
            ),
          ],
        ),
      ),
    );
  }
}
