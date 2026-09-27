import '../../core/config/nutrition_criteria.dart';
import '../../models/meal.dart';
import '../../models/nutrition_assessment.dart';
import '../../models/traffic_light.dart';
import 'nutrition_analyzer.dart';
import 'nutrition_score.dart';
import 'recommendation_engine.dart';

/// Punto de entrada del sistema del semáforo:
/// alimentos → perfil → factores → color → explicación y mejoras.
class TrafficLightService {
  const TrafficLightService({
    this.criteria = NutritionCriteria.standard,
    this.analyzer = const NutritionAnalyzer(),
    this.recommendations = const RecommendationEngine(),
  });

  final NutritionCriteria criteria;
  final NutritionAnalyzer analyzer;
  final RecommendationEngine recommendations;

  NutritionAssessment assess(List<MealFood> foods) {
    final profile = analyzer.analyze(foods);
    final factors = NutritionScore(criteria).factorsFor(profile);
    final score = factors.fold<int>(0, (sum, factor) => sum + factor.points);
    final light = colorFor(score: score, factors: factors);

    return NutritionAssessment(
      trafficLight: light,
      score: score,
      factors: factors,
      summary: recommendations.summaryFor(light, factors),
      improvements: recommendations.improvementsFor(factors, profile),
    );
  }

  TrafficLight colorFor({required int score, required List<ScoreFactor> factors}) {
    final highConcerns = factors.where((factor) => factor.isHighConcern).length;
    if (score <= criteria.redMaxScore || highConcerns >= criteria.highConcernsForRed) {
      return TrafficLight.red;
    }
    if (score >= criteria.greenMinScore && highConcerns == 0) return TrafficLight.green;
    return TrafficLight.orange;
  }
}
