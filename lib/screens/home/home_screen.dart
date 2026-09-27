import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/daily_tips.dart';
import '../../core/utils/date_utils.dart';
import '../../models/traffic_light.dart';
import '../../models/weekly_summary.dart';
import '../../providers/meals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/action_card.dart';
import '../../widgets/common.dart';
import '../../widgets/meal_tile.dart';
import '../../widgets/nutri_logo.dart';
import '../../widgets/traffic_light_indicator.dart';
import '../navigation.dart';
import '../shell/app_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _greeting(DateTime now) {
    if (now.hour >= 5 && now.hour < 12) return 'Buenos días';
    if (now.hour >= 12 && now.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final meals = ref.watch(mealsProvider);
    final summary = ref.watch(currentWeekSummaryProvider);
    final now = DateTime.now();
    final name = settings.userName.isEmpty ? '' : ', ${settings.userName}';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(mealsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting(now)}$name 👋', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text('¿Qué vas a comer hoy?',
                            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const NutriLogo(size: 52),
                ],
              ),
              const SizedBox(height: 24),
              ActionCard(
                icon: Icons.photo_camera_rounded,
                title: 'Analizar plato',
                subtitle: 'Toma una foto y revisa los alimentos',
                highlighted: true,
                onTap: () => AppNavigation.analyzePlate(context),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Escanear producto',
                subtitle: 'Lee el código de barras de un envase',
                onTap: () => AppNavigation.scanProduct(context),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.search_rounded,
                title: 'Buscar alimento',
                subtitle: 'Registra un alimento por su nombre',
                onTap: () => AppNavigation.searchFood(context),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                'Tu semana',
                action: 'Ver detalle',
                onAction: () => ref.read(tabIndexProvider.notifier).select(AppTab.weekly),
              ),
              summary.when(
                data: (data) => _WeekCard(summary: data),
                loading: () => const SizedBox(height: 90, child: LoadingView()),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                'Últimas comidas',
                action: 'Historial',
                onAction: () => ref.read(tabIndexProvider.notifier).select(AppTab.history),
              ),
              meals.when(
                data: (items) => items.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Aún no registras comidas. ¡Empieza analizando tu próximo plato! 🍽️'),
                        ),
                      )
                    : Column(
                        children: [
                          for (final meal in items.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: MealTile(
                                meal: meal,
                                showCalories: settings.showCalories,
                                onTap: () => AppNavigation.openMeal(context, meal),
                              ),
                            ),
                        ],
                      ),
                loading: () => const SizedBox(height: 90, child: LoadingView()),
                error: (error, _) => const InfoBanner(
                  message: 'No pudimos cargar tus comidas.',
                  tone: BannerTone.warning,
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader('Consejo del día'),
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Text('🌿', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tipOfTheDay(now),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final day in summary.days)
                  Column(
                    children: [
                      Text(
                        AppDates.weekdayShort(day.date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: AppDates.isSameDay(day.date, DateTime.now()) ? FontWeight.w900 : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TrafficDot(light: day.trafficLight, size: 22),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final light in TrafficLight.values)
                  Semantics(
                    label: '${summary.countMeals(light)} comidas en ${light.label.toLowerCase()}',
                    excludeSemantics: true,
                    child: Text(
                      '${light.emoji} ${summary.countMeals(light)}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
