import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/daily_tips.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/meal.dart';
import '../../models/traffic_light.dart';
import '../../models/weekly_summary.dart';
import '../../providers/core_providers.dart';
import '../../providers/meals_provider.dart';
import '../../providers/settings_provider.dart';
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
    final aiEnabled = ref.watch(aiClientProvider).enabled;
    final now = DateTime.now();
    final name = settings.userName.isEmpty ? '' : ', ${settings.userName}';
    final todayMeals = (meals.value ?? const <Meal>[]).where((meal) => AppDates.isSameDay(meal.createdAt, now)).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(mealsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _Hero(
                greeting: '${_greeting(now)}$name 👋',
                todayMeals: todayMeals,
                aiEnabled: aiEnabled,
                onAnalyze: () => AppNavigation.analyzePlate(context),
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _QuickTile(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Escanear producto',
                        subtitle: 'Código de barras o etiqueta',
                        onTap: () => AppNavigation.scanProduct(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickTile(
                        icon: Icons.search_rounded,
                        title: 'Buscar alimento',
                        subtitle: 'Escribe lo que comiste',
                        onTap: () => AppNavigation.searchFood(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _AssistantCard(onTap: () => ref.read(tabIndexProvider.notifier).select(AppTab.assistant)),
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
                          child: Row(
                            children: [
                              Text('🍽️', style: TextStyle(fontSize: 32)),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text('Aún no registras comidas. Toma una foto de tu próximo plato y '
                                    'mira su semáforo.'),
                              ),
                            ],
                          ),
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
                color: theme.colorScheme.secondaryContainer,
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
                            color: theme.colorScheme.onSecondaryContainer,
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

/// Cabecera con saludo, estado del día y la acción principal.
class _Hero extends StatelessWidget {
  const _Hero({required this.greeting, required this.todayMeals, required this.aiEnabled, required this.onAnalyze});

  final String greeting;
  final List<Meal> todayMeals;
  final bool aiEnabled;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayLight = todayMeals.isEmpty
        ? null
        : TrafficLight.fromAverage(
            todayMeals.map((meal) => meal.trafficLight.value).reduce((a, b) => a + b) / todayMeals.length,
          );
    const onHero = Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.leaf, AppColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.leaf.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: theme.textTheme.headlineSmall?.copyWith(color: onHero)),
                    const SizedBox(height: 4),
                    Text(
                      '¿Qué vas a comer hoy?',
                      style: theme.textTheme.bodyLarge?.copyWith(color: onHero.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const NutriLogo(size: 44),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                text: todayMeals.isEmpty
                    ? 'Sin registros hoy'
                    : '${todayMeals.length} ${todayMeals.length == 1 ? 'comida' : 'comidas'} hoy '
                        '${todayLight?.emoji ?? ''}',
              ),
              _Pill(text: aiEnabled ? '✨ IA activa' : 'Modo manual'),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Analizar plato. Toma una foto y la IA reconoce cada alimento',
            excludeSemantics: true,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onAnalyze,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.photo_camera_rounded, color: AppColors.leaf, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analizar plato',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Toma una foto y la IA reconoce cada alimento',
                              style: TextStyle(fontSize: 13, color: Color(0xFF55615A)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: AppColors.leaf),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Pregúntale a Nutri, tu asistente de nutrición con IA',
      excludeSemantics: true,
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                  child: Icon(Icons.auto_awesome, color: scheme.tertiary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pregúntale a Nutri',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onTertiaryContainer),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Asistente con IA: dudas, ideas y recomendaciones con fuentes confiables',
                        style: TextStyle(fontSize: 13, color: scheme.onTertiaryContainer.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onTertiaryContainer),
              ],
            ),
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
