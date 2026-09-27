import 'traffic_light.dart';

/// Un factor que sumó o restó puntos al evaluar un alimento o comida.
class ScoreFactor {
  const ScoreFactor({
    required this.id,
    required this.points,
    required this.explanation,
  });

  final String id;
  final int points;
  final String explanation;

  bool get isPositive => points > 0;

  /// Un factor "alto" (-2 o menos) indica un nutriente en nivel elevado.
  bool get isHighConcern => points <= -2;
}

class Recommendation {
  const Recommendation({required this.emoji, required this.message});

  final String emoji;
  final String message;
}

class NutritionAssessment {
  const NutritionAssessment({
    required this.trafficLight,
    required this.score,
    required this.factors,
    required this.summary,
    required this.improvements,
  });

  final TrafficLight trafficLight;
  final int score;
  final List<ScoreFactor> factors;
  final String summary;
  final List<Recommendation> improvements;

  Iterable<ScoreFactor> get strengths => factors.where((factor) => factor.isPositive);
  Iterable<ScoreFactor> get concerns => factors.where((factor) => !factor.isPositive);
}
