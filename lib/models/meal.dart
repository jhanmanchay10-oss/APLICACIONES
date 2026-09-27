import 'food_item.dart';
import 'nutrients.dart';
import 'traffic_light.dart';

enum MealType {
  breakfast('Desayuno', '🌅'),
  lunch('Almuerzo', '☀️'),
  dinner('Cena', '🌙'),
  snack('Merienda', '🍏');

  const MealType(this.label, this.emoji);

  final String label;
  final String emoji;

  static MealType suggestedFor(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return breakfast;
    if (hour >= 11 && hour < 16) return lunch;
    if (hour >= 19 || hour < 5) return dinner;
    return snack;
  }

  static MealType fromName(String? name) =>
      MealType.values.firstWhere((type) => type.name == name, orElse: () => MealType.snack);
}

enum MealSource { photo, barcode, search }

/// Un alimento dentro de una comida, con su cantidad en gramos.
class MealFood {
  const MealFood({required this.food, required this.grams, this.confidence});

  final FoodItem food;
  final double grams;

  /// Confianza de la IA (0-1) cuando el alimento proviene de una foto.
  final double? confidence;

  Nutrients get nutrients => food.per100g.scale(grams / 100);

  MealFood copyWith({FoodItem? food, double? grams}) =>
      MealFood(food: food ?? this.food, grams: grams ?? this.grams, confidence: confidence);

  Map<String, dynamic> toJson() => {'food': food.toJson(), 'grams': grams, 'confidence': confidence};

  factory MealFood.fromJson(Map<String, dynamic> json) => MealFood(
        food: FoodItem.fromJson(Map<String, dynamic>.from(json['food'] as Map)),
        grams: (json['grams'] as num).toDouble(),
        confidence: (json['confidence'] as num?)?.toDouble(),
      );
}

class Meal {
  const Meal({
    required this.id,
    required this.createdAt,
    required this.mealType,
    required this.name,
    required this.foods,
    required this.trafficLight,
    required this.score,
    required this.source,
    this.photoPath,
    this.synced = false,
  });

  final String id;
  final DateTime createdAt;
  final MealType mealType;
  final String name;
  final List<MealFood> foods;
  final TrafficLight trafficLight;
  final int score;
  final MealSource source;
  final String? photoPath;
  final bool synced;

  /// Los valores de una foto siempre son estimaciones.
  bool get isEstimate => source == MealSource.photo;

  Nutrients get totals => foods.fold(Nutrients.zero, (sum, item) => sum + item.nutrients);

  double get totalGrams => foods.fold(0, (sum, item) => sum + item.grams);

  Meal copyWith({bool? synced, String? photoPath}) => Meal(
        id: id,
        createdAt: createdAt,
        mealType: mealType,
        name: name,
        foods: foods,
        trafficLight: trafficLight,
        score: score,
        source: source,
        photoPath: photoPath ?? this.photoPath,
        synced: synced ?? this.synced,
      );

  static String defaultName(List<MealFood> foods) {
    if (foods.isEmpty) return 'Comida';
    final names = foods.take(3).map((item) => item.food.name).toList();
    final joined = names.length == 1
        ? names.first
        : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
    return foods.length > 3 ? '$joined…' : joined;
  }
}
