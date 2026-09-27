import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/text_utils.dart';
import '../../models/food_item.dart';
import '../../models/meal.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../navigation.dart';
import '../search/food_search_screen.dart';
import 'result_screen.dart';

/// "Alimentos detectados": el usuario revisa, corrige y confirma los alimentos.
class MealEditorScreen extends ConsumerStatefulWidget {
  const MealEditorScreen({
    super.key,
    required this.initialFoods,
    required this.source,
    this.photo,
    this.lowConfidence = false,
    this.notice,
  });

  final List<MealFood> initialFoods;
  final MealSource source;
  final File? photo;
  final bool lowConfidence;
  final String? notice;

  @override
  ConsumerState<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends ConsumerState<MealEditorScreen> {
  late final List<MealFood> _foods = [...widget.initialFoods];
  late MealType _mealType = MealType.suggestedFor(DateTime.now());
  final _nameController = TextEditingController();

  bool get _fromPhoto => widget.source == MealSource.photo;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addFood() async {
    final food = await AppNavigation.push<FoodItem>(context, const FoodSearchScreen(pickMode: true));
    if (food == null || !mounted) return;
    setState(() => _foods.add(MealFood(food: food, grams: food.typicalPortionGrams)));
  }

  Future<void> _replaceFood(int index) async {
    final food = await AppNavigation.push<FoodItem>(context, const FoodSearchScreen(pickMode: true));
    if (food == null || !mounted) return;
    setState(() => _foods[index] = MealFood(food: food, grams: _foods[index].grams));
  }

  Future<void> _editQuantity(int index) async {
    final grams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuantitySheet(food: _foods[index].food, initialGrams: _foods[index].grams),
    );
    if (grams != null && mounted) setState(() => _foods[index] = _foods[index].copyWith(grams: grams));
  }

  void _remove(int index) {
    final removed = _foods[index];
    setState(() => _foods.removeAt(index));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('${removed.food.name} eliminado'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => setState(() => _foods.insert(index.clamp(0, _foods.length), removed)),
        ),
      ));
  }

  void _confirm() {
    final assessment = ref.read(trafficLightServiceProvider).assess(_foods);
    final customName = TextUtils.sanitize(_nameController.text);
    final meal = Meal(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      mealType: _mealType,
      name: customName.isEmpty ? Meal.defaultName(_foods) : customName,
      foods: List.unmodifiable(_foods),
      trafficLight: assessment.trafficLight,
      score: assessment.score,
      source: widget.source,
      photoPath: widget.photo?.path,
    );
    AppNavigation.push(context, ResultScreen(meal: meal, isNew: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_fromPhoto ? 'Alimentos detectados' : 'Tu comida')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (widget.photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(widget.photo!, height: 180, fit: BoxFit.cover, semanticLabel: 'Foto del plato'),
              ),
              const SizedBox(height: 14),
            ],
            if (widget.lowConfidence && _foods.isNotEmpty) ...[
              const InfoBanner(
                tone: BannerTone.warning,
                message: 'No estamos seguros de haber identificado correctamente estos alimentos. '
                    'Revísalos y corrígelos si es necesario.',
              ),
              const SizedBox(height: 12),
            ],
            if (widget.notice != null) ...[
              InfoBanner(message: widget.notice!),
              const SizedBox(height: 12),
            ],
            if (_fromPhoto && _foods.isNotEmpty) ...[
              const InfoBanner(
                icon: Icons.straighten,
                message: 'Las cantidades son estimadas. Toca un alimento para ajustarla.',
              ),
              const SizedBox(height: 12),
            ],
            const SectionHeader('Alimentos'),
            if (_foods.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Aún no hay alimentos. Agrega los que forman parte de tu comida.'),
                ),
              ),
            for (var i = 0; i < _foods.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FoodRow(
                  item: _foods[i],
                  estimated: _fromPhoto,
                  onEdit: () => _editQuantity(i),
                  onReplace: () => _replaceFood(i),
                  onRemove: () => _remove(i),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _addFood,
              icon: const Icon(Icons.add),
              label: const Text('Agregar alimento'),
            ),
            const SizedBox(height: 20),
            const SectionHeader('Tipo de comida'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in MealType.values)
                  ChoiceChip(
                    label: Text('${type.emoji} ${type.label}'),
                    selected: type == _mealType,
                    onSelected: (_) => setState(() => _mealType = type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre de la comida (opcional)',
                hintText: _foods.isEmpty ? 'Ej. Almuerzo en casa' : Meal.defaultName(_foods),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _foods.isEmpty ? null : _confirm,
              icon: const Icon(Icons.check),
              label: const Text('Confirmar alimentos'),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes editar, eliminar o agregar alimentos antes de ver el resultado.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.item,
    required this.estimated,
    required this.onEdit,
    required this.onReplace,
    required this.onRemove,
  });

  final MealFood item;
  final bool estimated;
  final VoidCallback onEdit;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = item.confidence;
    final quantity = '${estimated ? 'Cantidad estimada: ' : ''}${Fmt.grams(item.grams)}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Text(item.food.category.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.food.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(quantity, style: theme.textTheme.bodySmall),
                    if (confidence != null && confidence < AppConstants.lowConfidenceThreshold)
                      Text('Confianza baja: revisa este alimento',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de ${item.food.name}',
                onSelected: (value) => switch (value) {
                  'edit' => onEdit(),
                  'replace' => onReplace(),
                  _ => onRemove(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar cantidad')),
                  PopupMenuItem(value: 'replace', child: Text('Cambiar alimento')),
                  PopupMenuItem(value: 'remove', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior para ajustar la cantidad en gramos.
class QuantitySheet extends StatefulWidget {
  const QuantitySheet({super.key, required this.food, required this.initialGrams});

  final FoodItem food;
  final double initialGrams;

  @override
  State<QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<QuantitySheet> {
  late double _grams = widget.initialGrams.clamp(1, AppConstants.maxFoodGrams).toDouble();
  late final _controller = TextEditingController(text: _grams.round().toString());

  double get _max => (widget.food.typicalPortionGrams * 3).clamp(300, AppConstants.maxFoodGrams).toDouble();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(double value) {
    setState(() => _grams = value.clamp(1, AppConstants.maxFoodGrams).toDouble());
    _controller.text = _grams.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final portion = widget.food.typicalPortionGrams;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.food.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cantidad', suffixText: 'g'),
            onChanged: (text) {
              final value = double.tryParse(text.replaceAll(',', '.'));
              if (value != null && value > 0) setState(() => _grams = value.clamp(1, AppConstants.maxFoodGrams));
            },
          ),
          Slider(
            value: _grams.clamp(1, _max),
            min: 1,
            max: _max,
            divisions: (_max / 5).round(),
            label: Fmt.grams(_grams),
            onChanged: _set,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final factor in const [0.5, 1.0, 1.5, 2.0])
                ActionChip(
                  label: Text(factor == 1 ? 'Porción (${portion.round()} g)' : '×$factor'),
                  onPressed: () => _set(portion * factor),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context, _grams), child: const Text('Guardar cantidad')),
        ],
      ),
    );
  }
}
