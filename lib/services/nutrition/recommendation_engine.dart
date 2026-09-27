import '../../core/config/nutrition_criteria.dart';
import '../../models/nutrition_assessment.dart';
import '../../models/traffic_light.dart';
import '../../models/weekly_summary.dart';
import 'nutrition_analyzer.dart';
import 'nutrition_score.dart';

/// Genera explicaciones y sugerencias positivas, prácticas y sin culpa.
class RecommendationEngine {
  const RecommendationEngine({this.criteria = NutritionCriteria.standard});

  final NutritionCriteria criteria;

  static const _tipsByFactor = <String, Recommendation>{
    FactorIds.fruitVegNone: Recommendation(
      emoji: '🥦',
      message: 'Añade una porción de verduras o una fruta para sumar color y nutrientes.',
    ),
    FactorIds.fruitVegSome: Recommendation(
      emoji: '🥗',
      message: 'Podrías aumentar la porción de verduras para equilibrar el plato.',
    ),
    FactorIds.sugarHigh: Recommendation(
      emoji: '🍓',
      message: 'Alterna con opciones sin azúcar añadido, como fruta fresca o yogur natural.',
    ),
    FactorIds.sugarMedium: Recommendation(
      emoji: '💧',
      message: 'Prueba versiones con menos azúcar o acompaña con agua en lugar de bebidas dulces.',
    ),
    FactorIds.saturatedFatHigh: Recommendation(
      emoji: '🫒',
      message: 'Elige con más frecuencia preparaciones a la plancha, al horno o con aceite vegetal.',
    ),
    FactorIds.saturatedFatMedium: Recommendation(
      emoji: '🐟',
      message: 'Alterna con pescado, legumbres o carnes magras durante la semana.',
    ),
    FactorIds.sodiumHigh: Recommendation(
      emoji: '🌿',
      message: 'Sazona con hierbas, limón o especias y reduce la sal y las salsas industriales.',
    ),
    FactorIds.sodiumMedium: Recommendation(
      emoji: '🧂',
      message: 'Prueba el plato antes de añadir sal; muchas veces no hace falta más.',
    ),
    FactorIds.ultraProcessedHigh: Recommendation(
      emoji: '🥕',
      message: 'Cuando puedas, cambia algún producto ultraprocesado por una versión casera o natural.',
    ),
    FactorIds.ultraProcessedSome: Recommendation(
      emoji: '🍳',
      message: 'Combinar productos envasados con alimentos frescos ayuda a equilibrar.',
    ),
  };

  String summaryFor(TrafficLight light, List<ScoreFactor> factors) {
    final strengths = factors.where((factor) => factor.isPositive).toList();
    final concerns = factors.where((factor) => !factor.isPositive).toList()
      ..sort((a, b) => a.points.compareTo(b.points));

    final positive = strengths.isEmpty ? null : _lowerFirst(strengths.first.explanation);
    final negative = concerns.isEmpty ? null : _lowerFirst(concerns.first.explanation);

    return switch (light) {
      TrafficLight.green => positive == null
          ? 'Es una buena opción dentro de una alimentación equilibrada.'
          : 'Buena elección: ${_trimDot(positive)}. Encaja bien en una alimentación equilibrada.',
      TrafficLight.orange => [
          if (positive != null) 'Tiene cosas buenas: ${_trimDot(positive)}.',
          if (negative != null) 'Para equilibrar, ten en cuenta que ${_trimDot(negative)}.',
          if (positive == null && negative == null) 'Puede formar parte de tu día; conviene complementarlo.',
        ].join(' '),
      TrafficLight.red => [
          if (negative != null) 'Conviene disfrutarlo con menos frecuencia: ${_trimDot(negative)}.',
          if (negative == null) 'Conviene disfrutarlo con menos frecuencia.',
          if (positive != null) 'Aun así, ${_trimDot(positive)}.',
        ].join(' '),
    };
  }

  List<Recommendation> improvementsFor(List<ScoreFactor> factors, NutritionProfile profile) {
    final ids = factors.map((factor) => factor.id).toSet();
    final tips = <Recommendation>[
      for (final factor in factors.where((factor) => !factor.isPositive).toList()
        ..sort((a, b) => a.points.compareTo(b.points)))
        ?_tipsByFactor[factor.id],
    ];

    if (!ids.contains(FactorIds.fiberHigh) && !ids.contains(FactorIds.fiberSource) && profile.isMeal) {
      tips.add(const Recommendation(
        emoji: '🌾',
        message: 'Suma fibra con cereales integrales, legumbres o más verduras.',
      ));
    }
    if (!ids.contains(FactorIds.protein) && profile.isMeal) {
      tips.add(const Recommendation(
        emoji: '🫘',
        message: 'Incluye una fuente de proteína como legumbres, huevo, pescado o pollo.',
      ));
    }
    if (tips.isEmpty) {
      tips.add(const Recommendation(
        emoji: '🌈',
        message: 'Sigue variando frutas y verduras de distintos colores durante la semana.',
      ));
    }
    return tips.take(4).toList();
  }

  List<Recommendation> weekly(WeeklySummary summary) {
    final t = summary.current;
    final c = criteria;
    if (!t.hasData) {
      return const [
        Recommendation(
          emoji: '📸',
          message: 'Registra algunas comidas esta semana para recibir recomendaciones personalizadas.',
        ),
      ];
    }

    final servingsGoal = c.dailyFruitVegGrams / c.fruitVegServingGrams;
    final tips = <Recommendation>[];

    if (t.fruitVegServingsPerDay < servingsGoal) {
      tips.add(Recommendation(
        emoji: '🥦',
        message: 'Esta semana llevas unas ${t.fruitVegServingsPerDay.toStringAsFixed(1)} porciones de '
            'frutas y verduras al día. Añadir una más en cada comida te acerca a las '
            '${servingsGoal.round()} recomendadas.',
      ));
    }
    if (t.fiberPerDay < c.dailyFiberGoalGrams * 0.7) {
      tips.add(const Recommendation(
        emoji: '🌾',
        message: 'Podrías incorporar más alimentos ricos en fibra: avena, legumbres, pan integral o frutas con piel.',
      ));
    }
    if (t.proteinSourceTypes < 3) {
      tips.add(const Recommendation(
        emoji: '🐟',
        message: 'Has tenido poca variedad de fuentes de proteína. Prueba alternar legumbres, pescado, huevo y aves.',
      ));
    }
    if (t.mealCount >= 5 && t.distinctFoods < t.mealCount) {
      tips.add(const Recommendation(
        emoji: '🌈',
        message: 'Podrías aumentar la variedad: prueba un alimento nuevo o una verdura de otro color.',
      ));
    }
    if (t.ultraProcessedMeals > t.mealCount / 3) {
      tips.add(const Recommendation(
        emoji: '🥕',
        message: 'Varias comidas incluyeron ultraprocesados. Planificar un par de preparaciones caseras puede ayudar.',
      ));
    }
    if (t.addedSugarPerDay > c.dailyAddedSugarMaxGrams) {
      tips.add(const Recommendation(
        emoji: '💧',
        message: 'Los azúcares añadidos estuvieron algo altos. El agua y la fruta entera son grandes aliadas.',
      ));
    }
    if (t.sodiumMgPerDay > c.dailySodiumMaxMg) {
      tips.add(const Recommendation(
        emoji: '🌿',
        message: 'El sodio estuvo por encima de lo recomendado. Las hierbas y especias dan sabor sin sal extra.',
      ));
    }

    final greens = summary.countMeals(TrafficLight.green);
    tips.insert(
      0,
      Recommendation(
        emoji: '👏',
        message: greens > 0
            ? '¡Bien hecho! Llevas $greens ${greens == 1 ? 'comida' : 'comidas'} en verde esta semana.'
            : 'Cada registro cuenta: ya estás prestando atención a lo que comes.',
      ),
    );
    return tips;
  }

  static String _lowerFirst(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

  static String _trimDot(String text) => text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}
