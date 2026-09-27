import '../../core/config/nutrition_criteria.dart';
import '../../models/nutrition_assessment.dart';
import 'nutrition_analyzer.dart';

/// Identificadores estables de factores; los usa el motor de recomendaciones.
abstract final class FactorIds {
  static const fruitVegGood = 'fruit_veg_good';
  static const fruitVegSome = 'fruit_veg_some';
  static const fruitVegNone = 'fruit_veg_none';
  static const fiberHigh = 'fiber_high';
  static const fiberSource = 'fiber_source';
  static const protein = 'protein';
  static const variety = 'variety';
  static const wholeGrain = 'whole_grain';
  static const sugarHigh = 'sugar_high';
  static const sugarMedium = 'sugar_medium';
  static const saturatedFatHigh = 'saturated_fat_high';
  static const saturatedFatMedium = 'saturated_fat_medium';
  static const sodiumHigh = 'sodium_high';
  static const sodiumMedium = 'sodium_medium';
  static const ultraProcessedHigh = 'ultra_processed_high';
  static const ultraProcessedSome = 'ultra_processed_some';
}

/// Calcula los factores positivos y negativos de un perfil nutricional.
/// No usa las calorías como criterio.
class NutritionScore {
  const NutritionScore(this.criteria);

  final NutritionCriteria criteria;

  List<ScoreFactor> factorsFor(NutritionProfile profile) {
    if (profile.isEmpty) return const [];
    final c = criteria;
    final factors = <ScoreFactor>[];

    // Frutas y verduras.
    if (profile.fruitVegShare >= c.fruitVegGoodShare) {
      factors.add(const ScoreFactor(
        id: FactorIds.fruitVegGood,
        points: 2,
        explanation: 'Tiene una buena proporción de frutas o verduras.',
      ));
    } else if (profile.fruitVegGrams > 0) {
      factors.add(const ScoreFactor(
        id: FactorIds.fruitVegSome,
        points: 1,
        explanation: 'Incluye algo de frutas o verduras.',
      ));
    } else if (profile.isMeal) {
      factors.add(const ScoreFactor(
        id: FactorIds.fruitVegNone,
        points: -1,
        explanation: 'No se detectaron frutas ni verduras.',
      ));
    }

    // Fibra.
    if (profile.fiberPer100g >= c.fiberHighPer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.fiberHigh,
        points: 2,
        explanation: 'Es rico en fibra.',
      ));
    } else if (profile.fiberPer100g >= c.fiberSourcePer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.fiberSource,
        points: 1,
        explanation: 'Es una fuente de fibra.',
      ));
    }

    // Proteína.
    if (profile.hasProteinSource || profile.proteinEnergyShare >= c.proteinEnergyShare) {
      factors.add(const ScoreFactor(
        id: FactorIds.protein,
        points: 1,
        explanation: 'Aporta una fuente de proteína.',
      ));
    }

    // Variedad y cereales integrales/legumbres (solo en comidas con varios alimentos).
    if (profile.isMeal && profile.foodGroups.length >= c.varietyGroupsForBonus) {
      factors.add(ScoreFactor(
        id: FactorIds.variety,
        points: 1,
        explanation: 'Combina ${profile.foodGroups.length} grupos de alimentos distintos.',
      ));
    }
    if (profile.hasWholeGrainOrLegume) {
      factors.add(const ScoreFactor(
        id: FactorIds.wholeGrain,
        points: 1,
        explanation: 'Incluye cereales integrales o legumbres.',
      ));
    }

    // Azúcares añadidos (aproximación).
    if (profile.addedSugarPer100g > c.addedSugarHighPer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.sugarHigh,
        points: -2,
        explanation: 'Tiene un nivel alto de azúcares añadidos.',
      ));
    } else if (profile.addedSugarPer100g > c.addedSugarLowPer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.sugarMedium,
        points: -1,
        explanation: 'Contiene una cantidad moderada de azúcares añadidos.',
      ));
    }

    // Grasas saturadas.
    if (profile.saturatedFatPer100g > c.saturatedFatHighPer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.saturatedFatHigh,
        points: -2,
        explanation: 'Es alto en grasas saturadas.',
      ));
    } else if (profile.saturatedFatPer100g > c.saturatedFatLowPer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.saturatedFatMedium,
        points: -1,
        explanation: 'Tiene una cantidad moderada de grasas saturadas.',
      ));
    }

    // Sodio.
    if (profile.sodiumMgPer100g > c.sodiumHighMgPer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.sodiumHigh,
        points: -2,
        explanation: 'Es alto en sodio (sal).',
      ));
    } else if (profile.sodiumMgPer100g > c.sodiumLowMgPer100g) {
      factors.add(const ScoreFactor(
        id: FactorIds.sodiumMedium,
        points: -1,
        explanation: 'Tiene una cantidad moderada de sodio.',
      ));
    }

    // Nivel de procesamiento.
    if (profile.ultraProcessedShare >= c.ultraProcessedHighShare) {
      factors.add(const ScoreFactor(
        id: FactorIds.ultraProcessedHigh,
        points: -2,
        explanation: 'Está compuesto principalmente por productos ultraprocesados.',
      ));
    } else if (profile.ultraProcessedGrams > 0) {
      factors.add(const ScoreFactor(
        id: FactorIds.ultraProcessedSome,
        points: -1,
        explanation: 'Incluye algún producto ultraprocesado.',
      ));
    }

    return factors;
  }
}
