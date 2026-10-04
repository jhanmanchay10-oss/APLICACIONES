import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/food_item.dart';
import '../../models/meal.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../barcode/product_screen.dart';
import '../navigation.dart';
import '../result/meal_editor_screen.dart';

/// Búsqueda de alimentos. En [pickMode] devuelve el alimento elegido.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<FoodItem>? _onlineResults;
  bool _searchingOnline = false;
  String? _onlineError;
  bool _estimating = false;
  String? _estimateError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchOnline() async {
    setState(() {
      _searchingOnline = true;
      _onlineError = null;
    });
    try {
      final results = await ref.read(openFoodFactsServiceProvider).search(_query);
      if (mounted) setState(() => _onlineResults = results);
    } catch (error) {
      if (mounted) setState(() => _onlineError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _searchingOnline = false);
    }
  }

  /// Calcula con IA lo que escribió el usuario (ej. "2 huevos cocidos").
  Future<void> _estimateWithAi() async {
    setState(() {
      _estimating = true;
      _estimateError = null;
    });
    try {
      final result = await ref.read(foodRecognitionServiceProvider).estimateFromText(_query);
      if (!mounted) return;
      if (widget.pickMode) {
        Navigator.pop(context, result.foods.first.food);
        return;
      }
      await AppNavigation.push(
        context,
        MealEditorScreen(initialFoods: result.foods, source: MealSource.search, lowConfidence: result.isLowConfidence),
      );
    } catch (error) {
      if (mounted) setState(() => _estimateError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  void _select(FoodItem food) {
    if (widget.pickMode) {
      Navigator.pop(context, food);
      return;
    }
    if (food.source == FoodSource.openFoodFacts) {
      AppNavigation.push(context, ProductScreen(product: food));
      return;
    }
    AppNavigation.push(
      context,
      MealEditorScreen(
        initialFoods: [MealFood(food: food, grams: food.typicalPortionGrams)],
        source: MealSource.search,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(localFoodDatabaseProvider).search(_query);
    final online = _onlineResults;
    final aiEnabled = ref.watch(foodRecognitionServiceProvider).enabled;

    return Scaffold(
      appBar: AppBar(title: Text(widget.pickMode ? 'Agregar alimento' : 'Buscar alimento')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 60,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Ej. 2 huevos cocidos, lomo saltado…',
                  prefixIcon: const Icon(Icons.search),
                  counterText: '',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _query = '';
                              _onlineResults = null;
                            });
                          },
                        ),
                ),
                onChanged: (value) => setState(() {
                  _query = value.trim();
                  _onlineResults = null;
                  _onlineError = null;
                  _estimateError = null;
                }),
                onSubmitted: (_) {
                  if (_query.length >= 2) _searchOnline();
                },
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  SectionHeader(_query.isEmpty ? 'Alimentos frecuentes' : 'Alimentos'),
                  if (local.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(aiEnabled
                          ? 'No está en la lista local. Calcúlalo con IA o busca en productos envasados.'
                          : 'No encontramos ese alimento en la lista. Prueba buscar en productos envasados.'),
                    ),
                  if (aiEnabled && _query.length >= 2) ...[
                    _AiEstimateCard(query: _query, loading: _estimating, onTap: _estimateWithAi),
                    if (_estimateError != null) ...[
                      const SizedBox(height: 8),
                      InfoBanner(message: _estimateError!, tone: BannerTone.warning),
                    ],
                    const SizedBox(height: 12),
                  ],
                  for (final food in local) _FoodResult(food: food, onTap: () => _select(food)),
                  if (_query.length >= 2) ...[
                    const SizedBox(height: 12),
                    const SectionHeader('Productos envasados'),
                    if (_searchingOnline)
                      const Padding(padding: EdgeInsets.all(24), child: LoadingView())
                    else if (_onlineError != null)
                      InfoBanner(message: _onlineError!, tone: BannerTone.warning)
                    else if (online == null)
                      OutlinedButton.icon(
                        onPressed: _searchOnline,
                        icon: const Icon(Icons.travel_explore),
                        label: Text('Buscar "$_query" en Open Food Facts'),
                      )
                    else if (online.isEmpty)
                      const Text('No se encontraron productos.')
                    else
                      for (final food in online) _FoodResult(food: food, onTap: () => _select(food)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodResult extends StatelessWidget {
  const _FoodResult({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (food.brand != null) food.brand!,
      food.category.label,
      '${Fmt.number(food.per100g.calories)} kcal / 100 g',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Text(food.category.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(food.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.add_circle_outline),
        ),
      ),
    );
  }
}

class _AiEstimateCard extends StatelessWidget {
  const _AiEstimateCard({required this.query, required this.loading, required this.onTap});

  final String query;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        onTap: loading ? null : onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: loading
            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.auto_awesome, color: scheme.onPrimaryContainer),
        title: Text(
          loading ? 'Calculando con IA…' : 'Calcular "$query" con IA',
          style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Reconoce cualquier alimento o plato. Puedes escribir cantidades.',
          style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}
