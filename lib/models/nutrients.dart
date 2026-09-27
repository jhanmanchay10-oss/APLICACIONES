/// Valores nutricionales. Todas las masas en gramos excepto el sodio (mg).
class Nutrients {
  const Nutrients({
    this.calories = 0,
    this.protein = 0,
    this.carbohydrates = 0,
    this.fat = 0,
    this.saturatedFat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodiumMg = 0,
  });

  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double saturatedFat;
  final double fiber;
  final double sugar;
  final double sodiumMg;

  static const zero = Nutrients();

  Nutrients operator +(Nutrients other) => Nutrients(
        calories: calories + other.calories,
        protein: protein + other.protein,
        carbohydrates: carbohydrates + other.carbohydrates,
        fat: fat + other.fat,
        saturatedFat: saturatedFat + other.saturatedFat,
        fiber: fiber + other.fiber,
        sugar: sugar + other.sugar,
        sodiumMg: sodiumMg + other.sodiumMg,
      );

  Nutrients scale(double factor) => Nutrients(
        calories: calories * factor,
        protein: protein * factor,
        carbohydrates: carbohydrates * factor,
        fat: fat * factor,
        saturatedFat: saturatedFat * factor,
        fiber: fiber * factor,
        sugar: sugar * factor,
        sodiumMg: sodiumMg * factor,
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbohydrates': carbohydrates,
        'fat': fat,
        'saturated_fat': saturatedFat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium_mg': sodiumMg,
      };

  factory Nutrients.fromJson(Map<String, dynamic> json) => Nutrients(
        calories: _toDouble(json['calories']),
        protein: _toDouble(json['protein']),
        carbohydrates: _toDouble(json['carbohydrates']),
        fat: _toDouble(json['fat']),
        saturatedFat: _toDouble(json['saturated_fat']),
        fiber: _toDouble(json['fiber']),
        sugar: _toDouble(json['sugar']),
        sodiumMg: _toDouble(json['sodium_mg']),
      );

  static double _toDouble(Object? value) {
    if (value is num) return value.isFinite ? value.toDouble().clamp(0, 100000) : 0;
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return 0;
  }
}
