/// ÚNICO lugar donde viven los umbrales del semáforo.
///
/// Los valores por defecto se basan en referencias públicas y DEBEN ser
/// validados por un profesional de la nutrición antes de publicar:
///
/// * Azúcares, grasas saturadas y sal por 100 g: umbrales "bajo/alto" del
///   etiquetado frontal tipo semáforo de la FSA del Reino Unido (2016).
///   Sal 1,5 g ≈ sodio 600 mg; sal 0,3 g ≈ sodio 120 mg.
/// * Fibra: "fuente de fibra" ≥ 3 g/100 g y "alto en fibra" ≥ 6 g/100 g
///   (Reglamento CE 1924/2006).
/// * Proteína: "fuente de proteína" cuando aporta ≥ 12 % de la energía
///   (Reglamento CE 1924/2006).
/// * Resumen semanal: OMS — ≥ 400 g/día de frutas y verduras, azúcares libres
///   < 10 % de la energía (~50 g/día), sodio < 2000 mg/día, fibra ≥ 25 g/día.
/// * Procesamiento: clasificación NOVA (grupo 4 = ultraprocesado).
///
/// Se puede sobrescribir en tiempo de ejecución con [NutritionCriteria.fromJson]
/// (por ejemplo, desde una tabla remota) sin recompilar la aplicación.
class NutritionCriteria {
  const NutritionCriteria({
    this.addedSugarLowPer100g = 5,
    this.addedSugarHighPer100g = 22.5,
    this.saturatedFatLowPer100g = 1.5,
    this.saturatedFatHighPer100g = 5,
    this.sodiumLowMgPer100g = 120,
    this.sodiumHighMgPer100g = 600,
    this.fiberSourcePer100g = 3,
    this.fiberHighPer100g = 6,
    this.proteinEnergyShare = 0.12,
    this.fruitVegGoodShare = 0.3,
    this.ultraProcessedHighShare = 0.5,
    this.varietyGroupsForBonus = 3,
    this.greenMinScore = 2,
    this.redMaxScore = -3,
    this.highConcernsForRed = 2,
    this.dailyFruitVegGrams = 400,
    this.fruitVegServingGrams = 80,
    this.dailyAddedSugarMaxGrams = 50,
    this.dailySodiumMaxMg = 2000,
    this.dailyFiberGoalGrams = 25,
  });

  final double addedSugarLowPer100g;
  final double addedSugarHighPer100g;
  final double saturatedFatLowPer100g;
  final double saturatedFatHighPer100g;
  final double sodiumLowMgPer100g;
  final double sodiumHighMgPer100g;
  final double fiberSourcePer100g;
  final double fiberHighPer100g;
  final double proteinEnergyShare;
  final double fruitVegGoodShare;
  final double ultraProcessedHighShare;
  final int varietyGroupsForBonus;

  /// Puntuación mínima para verde (sin factores de preocupación alta).
  final int greenMinScore;

  /// Puntuación igual o inferior que resulta en rojo.
  final int redMaxScore;

  /// Número de nutrientes en nivel alto que resultan en rojo.
  final int highConcernsForRed;

  final double dailyFruitVegGrams;
  final double fruitVegServingGrams;
  final double dailyAddedSugarMaxGrams;
  final double dailySodiumMaxMg;
  final double dailyFiberGoalGrams;

  static const standard = NutritionCriteria();

  factory NutritionCriteria.fromJson(Map<String, dynamic> json) {
    double read(String key, double fallback) => (json[key] as num?)?.toDouble() ?? fallback;
    int readInt(String key, int fallback) => (json[key] as num?)?.toInt() ?? fallback;
    const d = standard;
    return NutritionCriteria(
      addedSugarLowPer100g: read('added_sugar_low_per_100g', d.addedSugarLowPer100g),
      addedSugarHighPer100g: read('added_sugar_high_per_100g', d.addedSugarHighPer100g),
      saturatedFatLowPer100g: read('saturated_fat_low_per_100g', d.saturatedFatLowPer100g),
      saturatedFatHighPer100g: read('saturated_fat_high_per_100g', d.saturatedFatHighPer100g),
      sodiumLowMgPer100g: read('sodium_low_mg_per_100g', d.sodiumLowMgPer100g),
      sodiumHighMgPer100g: read('sodium_high_mg_per_100g', d.sodiumHighMgPer100g),
      fiberSourcePer100g: read('fiber_source_per_100g', d.fiberSourcePer100g),
      fiberHighPer100g: read('fiber_high_per_100g', d.fiberHighPer100g),
      proteinEnergyShare: read('protein_energy_share', d.proteinEnergyShare),
      fruitVegGoodShare: read('fruit_veg_good_share', d.fruitVegGoodShare),
      ultraProcessedHighShare: read('ultra_processed_high_share', d.ultraProcessedHighShare),
      varietyGroupsForBonus: readInt('variety_groups_for_bonus', d.varietyGroupsForBonus),
      greenMinScore: readInt('green_min_score', d.greenMinScore),
      redMaxScore: readInt('red_max_score', d.redMaxScore),
      highConcernsForRed: readInt('high_concerns_for_red', d.highConcernsForRed),
      dailyFruitVegGrams: read('daily_fruit_veg_grams', d.dailyFruitVegGrams),
      fruitVegServingGrams: read('fruit_veg_serving_grams', d.fruitVegServingGrams),
      dailyAddedSugarMaxGrams: read('daily_added_sugar_max_grams', d.dailyAddedSugarMaxGrams),
      dailySodiumMaxMg: read('daily_sodium_max_mg', d.dailySodiumMaxMg),
      dailyFiberGoalGrams: read('daily_fiber_goal_grams', d.dailyFiberGoalGrams),
    );
  }
}
