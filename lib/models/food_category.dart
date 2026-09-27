/// Grupo de alimento. Se usa para evaluar variedad, frutas y verduras,
/// fuentes de proteína y una aproximación de azúcares añadidos.
enum FoodCategory {
  vegetable('Verdura', '🥦'),
  fruit('Fruta', '🍎'),
  legume('Legumbre', '🫘'),
  wholeGrain('Cereal integral', '🌾'),
  refinedGrain('Cereal refinado', '🍚'),
  tuber('Tubérculo', '🥔'),
  leanProtein('Carne magra / ave', '🍗'),
  redMeat('Carne roja', '🥩'),
  processedMeat('Carne procesada', '🌭'),
  fish('Pescado / marisco', '🐟'),
  egg('Huevo', '🥚'),
  dairy('Lácteo', '🥛'),
  nutsSeeds('Frutos secos / semillas', '🥜'),
  fatsOils('Grasas y aceites', '🫒'),
  sweets('Dulces', '🍰'),
  sugaryDrink('Bebida azucarada', '🥤'),
  beverage('Bebida', '☕'),
  snack('Snack', '🍿'),
  fastFood('Comida rápida', '🍔'),
  mixedDish('Plato preparado', '🍲'),
  other('Otro', '🍽️');

  const FoodCategory(this.label, this.emoji);

  final String label;
  final String emoji;

  bool get isFruitOrVegetable => this == vegetable || this == fruit;

  bool get isProteinSource => const {
        legume,
        leanProtein,
        redMeat,
        processedMeat,
        fish,
        egg,
        dairy,
        nutsSeeds,
      }.contains(this);

  bool get isWholeGrainOrLegume => this == wholeGrain || this == legume;

  /// Categorías cuyo azúcar se considera, por aproximación, azúcar añadido/libre.
  /// Frutas enteras, verduras y lácteos naturales quedan fuera.
  bool get sugarCountsAsAdded => const {
        sweets,
        sugaryDrink,
        snack,
        fastFood,
        mixedDish,
        refinedGrain,
        other,
      }.contains(this);

  static FoodCategory fromName(String? name) => FoodCategory.values.firstWhere(
        (category) => category.name == name,
        orElse: () => FoodCategory.other,
      );
}
