import '../core/utils/text_utils.dart';
import '../models/food_category.dart';
import '../models/food_item.dart';
import '../models/nutrients.dart';

/// Base de datos local de alimentos comunes (valores aproximados por 100 g,
/// principalmente de USDA FoodData Central y tablas de composición
/// latinoamericanas). Los platos preparados son estimaciones promedio.
class LocalFoodDatabase {
  const LocalFoodDatabase();

  List<FoodItem> get all => _foods;

  FoodItem? byId(String id) {
    for (final food in _foods) {
      if (food.id == id) return food;
    }
    return null;
  }

  /// Búsqueda tolerante: ignora tildes, plurales y palabras como "de" o "con",
  /// y acepta coincidencias parciales ("huevos cocidos" encuentra "Huevo").
  /// [minRatio] es la fracción mínima de palabras de la búsqueda que deben coincidir.
  List<FoodItem> search(String query, {int limit = 30, double minRatio = 0.5}) {
    final queryTokens = _tokens(query);
    if (queryTokens.isEmpty) return _foods.take(limit).toList();
    final joinedQuery = queryTokens.join(' ');

    final scored = <(FoodItem, double)>[];
    for (final food in _foods) {
      var best = 0.0;
      for (final candidate in [food.name, ...food.aliases]) {
        final tokens = _tokens(candidate);
        if (tokens.isEmpty) continue;
        final joined = tokens.join(' ');
        double score;
        if (joined == joinedQuery) {
          score = 100;
        } else if (joined.startsWith(joinedQuery)) {
          score = 80;
        } else {
          final matched = queryTokens.where((q) => tokens.any((t) => t == q || t.startsWith(q))).length;
          final ratio = matched / queryTokens.length;
          if (ratio < minRatio) continue;
          // Premia coincidir con más palabras y nombres cortos (más específicos).
          score = ratio * 60 + (matched / tokens.length) * 10;
        }
        // Coincidencias con el nombre principal pesan un poco más que con alias.
        if (candidate == food.name) score += 1;
        if (score > best) best = score;
      }
      if (best > 0) scored.add((food, best));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$1.name.length.compareTo(b.$1.name.length);
    });
    return scored.take(limit).map((entry) => entry.$1).toList();
  }

  /// Busca el alimento local que mejor coincide con un nombre detectado por IA.
  /// Solo acepta coincidencias completas para no perder nutrientes (ej. no
  /// confundir "papa a la huancaína" con "papa sancochada").
  FoodItem? bestMatch(String name) {
    final matches = search(name, limit: 1, minRatio: 1);
    return matches.isEmpty ? null : matches.first;
  }

  /// Palabras que no cambian el alimento (conectores, preparaciones simples y medidas).
  static const _stopWords = {
    'de', 'del', 'con', 'a', 'al', 'la', 'el', 'lo', 'los', 'las', 'en', 'y', 'un', 'una', 'para', 'sin',
    'cocido', 'cocida', 'sancochado', 'sancochada', 'hervido', 'hervida', 'entero', 'entera',
    'picado', 'picada', 'natural', 'porcion', 'vaso', 'taza', 'plato', 'unidad', 'grande', 'mediano',
    'mediana', 'pequeno', 'pequena',
  };

  static List<String> _tokens(String text) => TextUtils.normalize(text)
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(' ')
      .where((token) => token.isNotEmpty && !RegExp(r'^\d+$').hasMatch(token))
      .map(_singular)
      .where((token) => !_stopWords.contains(token))
      .toList();

  /// Singular aproximado en español: huevos → huevo, frejoles → frejol, panes → pan.
  static String _singular(String word) {
    if (word.length > 4 && word.endsWith('es')) {
      final stem = word.substring(0, word.length - 2);
      if (RegExp(r'[lnrdzj]$').hasMatch(stem)) return stem;
    }
    if (word.length > 3 && word.endsWith('s')) return word.substring(0, word.length - 1);
    return word;
  }
}

FoodItem _f(
  String id,
  String name,
  FoodCategory category, {
  required double kcal,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  double satFat = 0,
  double fiber = 0,
  double sugar = 0,
  double sodium = 0,
  double portion = 100,
  int nova = 1,
  List<String> aliases = const [],
}) =>
    FoodItem(
      id: 'local_$id',
      name: name,
      category: category,
      typicalPortionGrams: portion,
      novaGroup: nova,
      aliases: aliases,
      per100g: Nutrients(
        calories: kcal,
        protein: protein,
        carbohydrates: carbs,
        fat: fat,
        saturatedFat: satFat,
        fiber: fiber,
        sugar: sugar,
        sodiumMg: sodium,
      ),
    );

const _veg = FoodCategory.vegetable;
const _fruit = FoodCategory.fruit;

final List<FoodItem> _foods = [
  // Verduras
  _f('ensalada', 'Ensalada verde', _veg, kcal: 20, protein: 1.3, carbs: 3.5, fat: 0.2, fiber: 1.8, sugar: 1.5, sodium: 20, portion: 80, aliases: ['ensalada', 'lechuga', 'salad', 'green salad']),
  _f('tomate', 'Tomate', _veg, kcal: 18, protein: 0.9, carbs: 3.9, fat: 0.2, fiber: 1.2, sugar: 2.6, sodium: 5, portion: 100, aliases: ['tomato', 'jitomate']),
  _f('zanahoria', 'Zanahoria', _veg, kcal: 41, protein: 0.9, carbs: 9.6, fat: 0.2, fiber: 2.8, sugar: 4.7, sodium: 69, portion: 60, aliases: ['carrot']),
  _f('brocoli', 'Brócoli', _veg, kcal: 35, protein: 2.4, carbs: 7.2, fat: 0.4, fiber: 3.3, sugar: 1.4, sodium: 41, portion: 90, aliases: ['broccoli', 'brocoli cocido']),
  _f('espinaca', 'Espinaca', _veg, kcal: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 2.2, sugar: 0.4, sodium: 79, portion: 60, aliases: ['spinach']),
  _f('pepino', 'Pepino', _veg, kcal: 15, protein: 0.7, carbs: 3.6, fat: 0.1, fiber: 0.5, sugar: 1.7, sodium: 2, portion: 80, aliases: ['cucumber']),
  _f('cebolla', 'Cebolla', _veg, kcal: 40, protein: 1.1, carbs: 9.3, fat: 0.1, fiber: 1.7, sugar: 4.2, sodium: 4, portion: 50, aliases: ['onion', 'cebolla roja', 'salsa criolla']),
  _f('palta', 'Palta', _veg, kcal: 160, protein: 2, carbs: 8.5, fat: 14.7, satFat: 2.1, fiber: 6.7, sugar: 0.7, sodium: 7, portion: 50, aliases: ['aguacate', 'avocado', 'guacamole']),
  _f('verduras_salteadas', 'Verduras salteadas', _veg, kcal: 65, protein: 2, carbs: 7, fat: 3.5, satFat: 0.5, fiber: 2.5, sugar: 3, sodium: 180, portion: 120, nova: 3, aliases: ['vegetales salteados', 'stir fry vegetables', 'verduras']),
  _f('choclo', 'Choclo', _veg, kcal: 96, protein: 3.4, carbs: 21, fat: 1.5, satFat: 0.2, fiber: 2.4, sugar: 4.5, sodium: 1, portion: 100, aliases: ['maiz', 'elote', 'corn', 'mazorca']),
  _f('pimiento', 'Pimiento', _veg, kcal: 26, protein: 1, carbs: 6, fat: 0.3, fiber: 2.1, sugar: 4.2, sodium: 4, portion: 60, aliases: ['pimenton', 'bell pepper', 'aji']),
  _f('zapallo', 'Zapallo', _veg, kcal: 26, protein: 1, carbs: 6.5, fat: 0.1, fiber: 0.5, sugar: 2.8, sodium: 1, portion: 100, aliases: ['calabaza', 'pumpkin', 'squash']),
  _f('vainitas', 'Vainitas', _veg, kcal: 31, protein: 1.8, carbs: 7, fat: 0.2, fiber: 2.7, sugar: 3.3, sodium: 6, portion: 80, aliases: ['judias verdes', 'green beans', 'ejotes']),

  // Frutas
  _f('manzana', 'Manzana', _fruit, kcal: 52, protein: 0.3, carbs: 14, fat: 0.2, fiber: 2.4, sugar: 10.4, sodium: 1, portion: 150, aliases: ['apple']),
  _f('platano', 'Plátano', _fruit, kcal: 89, protein: 1.1, carbs: 23, fat: 0.3, satFat: 0.1, fiber: 2.6, sugar: 12.2, sodium: 1, portion: 120, aliases: ['banana', 'banano', 'guineo']),
  _f('naranja', 'Naranja', _fruit, kcal: 47, protein: 0.9, carbs: 12, fat: 0.1, fiber: 2.4, sugar: 9.4, portion: 150, aliases: ['orange', 'mandarina']),
  _f('fresa', 'Fresas', _fruit, kcal: 32, protein: 0.7, carbs: 7.7, fat: 0.3, fiber: 2, sugar: 4.9, sodium: 1, portion: 100, aliases: ['fresa', 'frutilla', 'strawberry', 'strawberries']),
  _f('papaya', 'Papaya', _fruit, kcal: 43, protein: 0.5, carbs: 11, fat: 0.3, fiber: 1.7, sugar: 7.8, sodium: 8, portion: 150, aliases: ['papaya picada']),
  _f('pina', 'Piña', _fruit, kcal: 50, protein: 0.5, carbs: 13, fat: 0.1, fiber: 1.4, sugar: 9.9, sodium: 1, portion: 120, aliases: ['pineapple', 'anana']),
  _f('mango', 'Mango', _fruit, kcal: 60, protein: 0.8, carbs: 15, fat: 0.4, fiber: 1.6, sugar: 13.7, sodium: 1, portion: 150, aliases: []),
  _f('uvas', 'Uvas', _fruit, kcal: 69, protein: 0.7, carbs: 18, fat: 0.2, fiber: 0.9, sugar: 15.5, sodium: 2, portion: 100, aliases: ['uva', 'grapes']),
  _f('ensalada_frutas', 'Ensalada de frutas', _fruit, kcal: 55, protein: 0.7, carbs: 14, fat: 0.2, fiber: 1.8, sugar: 11, sodium: 3, portion: 200, aliases: ['fruit salad', 'frutas picadas', 'fruta']),

  // Cereales y tubérculos
  _f('arroz_blanco', 'Arroz blanco', FoodCategory.refinedGrain, kcal: 130, protein: 2.7, carbs: 28, fat: 0.3, satFat: 0.1, fiber: 0.4, sugar: 0.1, sodium: 1, portion: 150, nova: 1, aliases: ['arroz', 'white rice', 'rice', 'arroz cocido']),
  _f('arroz_integral', 'Arroz integral', FoodCategory.wholeGrain, kcal: 123, protein: 2.7, carbs: 26, fat: 1, satFat: 0.2, fiber: 1.6, sugar: 0.4, sodium: 4, portion: 150, aliases: ['brown rice']),
  _f('quinua', 'Quinua', FoodCategory.wholeGrain, kcal: 120, protein: 4.4, carbs: 21, fat: 1.9, satFat: 0.2, fiber: 2.8, sugar: 0.9, sodium: 7, portion: 150, aliases: ['quinoa']),
  _f('avena', 'Avena cocida', FoodCategory.wholeGrain, kcal: 71, protein: 2.5, carbs: 12, fat: 1.5, satFat: 0.3, fiber: 1.7, sugar: 0.3, sodium: 4, portion: 250, aliases: ['avena', 'oatmeal', 'oats', 'porridge']),
  _f('pan_blanco', 'Pan blanco', FoodCategory.refinedGrain, kcal: 265, protein: 9, carbs: 49, fat: 3.2, satFat: 0.7, fiber: 2.7, sugar: 5, sodium: 490, portion: 60, nova: 3, aliases: ['pan', 'bread', 'pan frances', 'marraqueta', 'pan de molde']),
  _f('pan_integral', 'Pan integral', FoodCategory.wholeGrain, kcal: 247, protein: 13, carbs: 41, fat: 3.4, satFat: 0.7, fiber: 7, sugar: 6, sodium: 450, portion: 60, nova: 3, aliases: ['whole wheat bread', 'pan de trigo integral']),
  _f('pasta', 'Pasta cocida', FoodCategory.refinedGrain, kcal: 158, protein: 5.8, carbs: 31, fat: 0.9, satFat: 0.2, fiber: 1.8, sugar: 0.6, sodium: 1, portion: 180, aliases: ['pasta', 'fideos', 'tallarines', 'spaghetti', 'macarrones']),
  _f('papa', 'Papa sancochada', FoodCategory.tuber, kcal: 87, protein: 1.9, carbs: 20, fat: 0.1, fiber: 1.8, sugar: 0.9, sodium: 4, portion: 150, aliases: ['papa', 'patata', 'potato', 'papa cocida', 'boiled potato']),
  _f('papas_fritas', 'Papas fritas', FoodCategory.fastFood, kcal: 312, protein: 3.4, carbs: 41, fat: 15, satFat: 2.3, fiber: 3.8, sugar: 0.3, sodium: 210, portion: 120, nova: 3, aliases: ['french fries', 'fries', 'papas', 'patatas fritas']),
  _f('camote', 'Camote', FoodCategory.tuber, kcal: 90, protein: 2, carbs: 21, fat: 0.2, fiber: 3.3, sugar: 6.5, sodium: 36, portion: 120, aliases: ['batata', 'sweet potato', 'boniato']),
  _f('yuca', 'Yuca', FoodCategory.tuber, kcal: 160, protein: 1.4, carbs: 38, fat: 0.3, fiber: 1.8, sugar: 1.7, sodium: 14, portion: 120, aliases: ['mandioca', 'cassava']),
  _f('tortilla_maiz', 'Tortilla de maíz', FoodCategory.wholeGrain, kcal: 218, protein: 5.7, carbs: 45, fat: 2.9, satFat: 0.4, fiber: 6.3, sugar: 0.9, sodium: 45, portion: 50, nova: 3, aliases: ['tortilla', 'corn tortilla', 'arepa']),
  _f('cereal_azucarado', 'Cereal de desayuno azucarado', FoodCategory.sweets, kcal: 390, protein: 6, carbs: 85, fat: 3.5, satFat: 1, fiber: 3, sugar: 32, sodium: 450, portion: 30, nova: 4, aliases: ['cereal', 'corn flakes', 'cereal chocolate']),
  _f('granola', 'Granola', FoodCategory.wholeGrain, kcal: 471, protein: 10, carbs: 64, fat: 20, satFat: 4, fiber: 7, sugar: 24, sodium: 30, portion: 40, nova: 3, aliases: []),

  // Legumbres
  _f('lentejas', 'Lentejas', FoodCategory.legume, kcal: 116, protein: 9, carbs: 20, fat: 0.4, satFat: 0.1, fiber: 7.9, sugar: 1.8, sodium: 2, portion: 180, aliases: ['lentils', 'guiso de lentejas']),
  _f('frejoles', 'Frejoles', FoodCategory.legume, kcal: 127, protein: 8.7, carbs: 23, fat: 0.5, satFat: 0.1, fiber: 6.4, sugar: 0.3, sodium: 2, portion: 180, aliases: ['frijoles', 'porotos', 'beans', 'menestra', 'caraotas']),
  _f('garbanzos', 'Garbanzos', FoodCategory.legume, kcal: 164, protein: 8.9, carbs: 27, fat: 2.6, satFat: 0.3, fiber: 7.6, sugar: 4.8, sodium: 7, portion: 160, aliases: ['chickpeas', 'hummus']),

  // Proteínas
  _f('pollo_plancha', 'Pollo a la plancha', FoodCategory.leanProtein, kcal: 165, protein: 31, fat: 3.6, satFat: 1, sodium: 74, portion: 120, aliases: ['pollo', 'chicken', 'pechuga', 'grilled chicken', 'chicken breast']),
  _f('pollo_brasa', 'Pollo a la brasa', FoodCategory.leanProtein, kcal: 215, protein: 25, carbs: 1, fat: 12.5, satFat: 3.5, sodium: 420, portion: 200, nova: 3, aliases: ['pollo asado', 'roast chicken', 'pollo rostizado']),
  _f('pollo_frito', 'Pollo frito', FoodCategory.fastFood, kcal: 260, protein: 22, carbs: 9, fat: 15, satFat: 4, fiber: 0.4, sodium: 520, portion: 150, nova: 3, aliases: ['fried chicken', 'broaster', 'nuggets']),
  _f('carne_res', 'Carne de res', FoodCategory.redMeat, kcal: 250, protein: 26, fat: 15, satFat: 6, sodium: 72, portion: 120, aliases: ['bistec', 'beef', 'steak', 'carne', 'lomo']),
  _f('cerdo', 'Carne de cerdo', FoodCategory.redMeat, kcal: 242, protein: 27, fat: 14, satFat: 5, sodium: 62, portion: 120, aliases: ['pork', 'chuleta', 'chancho']),
  _f('pescado', 'Pescado', FoodCategory.fish, kcal: 105, protein: 23, fat: 1, satFat: 0.2, sodium: 80, portion: 150, aliases: ['fish', 'filete de pescado', 'pescado a la plancha', 'salmon', 'tilapia', 'bonito']),
  _f('atun', 'Atún en conserva', FoodCategory.fish, kcal: 116, protein: 26, fat: 0.8, satFat: 0.2, sodium: 340, portion: 80, nova: 3, aliases: ['tuna', 'atun']),
  _f('huevo', 'Huevo', FoodCategory.egg, kcal: 155, protein: 13, carbs: 1.1, fat: 11, satFat: 3.3, sugar: 1.1, sodium: 124, portion: 60, aliases: ['egg', 'huevo cocido', 'huevo duro', 'huevo sancochado', 'huevo hervido', 'eggs', 'boiled egg']),
  _f('huevo_frito', 'Huevo frito', FoodCategory.egg, kcal: 196, protein: 13.6, carbs: 0.8, fat: 15, satFat: 4.3, sugar: 0.4, sodium: 207, portion: 60, aliases: ['fried egg', 'huevos revueltos', 'scrambled eggs']),
  _f('salchicha', 'Salchicha', FoodCategory.processedMeat, kcal: 290, protein: 11, carbs: 3, fat: 26, satFat: 10, sugar: 1.5, sodium: 950, portion: 60, nova: 4, aliases: ['hot dog', 'sausage', 'salchicha frankfurt']),
  _f('jamon', 'Jamón', FoodCategory.processedMeat, kcal: 145, protein: 21, carbs: 1.5, fat: 6, satFat: 2, sugar: 1, sodium: 1200, portion: 40, nova: 4, aliases: ['ham', 'jamonada', 'embutido']),
  _f('tofu', 'Tofu', FoodCategory.legume, kcal: 76, protein: 8, carbs: 1.9, fat: 4.8, satFat: 0.7, fiber: 0.3, sodium: 7, portion: 120, nova: 3, aliases: []),

  // Lácteos
  _f('leche', 'Leche', FoodCategory.dairy, kcal: 61, protein: 3.2, carbs: 4.8, fat: 3.3, satFat: 1.9, sugar: 5, sodium: 43, portion: 250, aliases: ['milk', 'leche entera', 'leche descremada']),
  _f('yogur_natural', 'Yogur natural', FoodCategory.dairy, kcal: 61, protein: 3.5, carbs: 4.7, fat: 3.3, satFat: 2.1, sugar: 4.7, sodium: 46, portion: 150, aliases: ['yogurt natural', 'plain yogurt', 'yogur griego']),
  _f('yogur_azucarado', 'Yogur bebible azucarado', FoodCategory.sweets, kcal: 90, protein: 2.8, carbs: 15, fat: 2, satFat: 1.3, sugar: 13, sodium: 45, portion: 200, nova: 4, aliases: ['yogurt', 'yogur', 'yogur de fresa', 'flavored yogurt']),
  _f('queso_fresco', 'Queso fresco', FoodCategory.dairy, kcal: 264, protein: 18, carbs: 3, fat: 20, satFat: 12, sugar: 1, sodium: 620, portion: 40, nova: 3, aliases: ['queso', 'cheese', 'queso blanco']),

  // Frutos secos y grasas
  _f('mani', 'Maní', FoodCategory.nutsSeeds, kcal: 567, protein: 26, carbs: 16, fat: 49, satFat: 7, fiber: 8.5, sugar: 4, sodium: 18, portion: 30, aliases: ['cacahuate', 'peanuts', 'frutos secos', 'almendras', 'nueces', 'nuts']),
  _f('aceite_oliva', 'Aceite de oliva', FoodCategory.fatsOils, kcal: 884, fat: 100, satFat: 14, portion: 10, nova: 2, aliases: ['olive oil', 'aceite']),
  _f('mantequilla', 'Mantequilla', FoodCategory.fatsOils, kcal: 717, protein: 0.9, fat: 81, satFat: 51, sodium: 11, portion: 10, nova: 2, aliases: ['butter', 'margarina']),
  _f('mayonesa', 'Mayonesa', FoodCategory.fatsOils, kcal: 680, protein: 1, carbs: 1, fat: 75, satFat: 12, sugar: 1, sodium: 635, portion: 15, nova: 4, aliases: ['mayo', 'mayonnaise', 'salsa de mayonesa']),

  // Platos preparados (estimaciones promedio)
  _f('lomo_saltado', 'Lomo saltado', FoodCategory.mixedDish, kcal: 150, protein: 10, carbs: 11, fat: 7.5, satFat: 2.5, fiber: 1.2, sugar: 2, sodium: 420, portion: 300, nova: 3, aliases: ['beef stir fry']),
  _f('aji_gallina', 'Ají de gallina', FoodCategory.mixedDish, kcal: 170, protein: 10, carbs: 9, fat: 10.5, satFat: 4, fiber: 0.8, sugar: 1.5, sodium: 380, portion: 250, nova: 3, aliases: []),
  _f('ceviche', 'Ceviche', FoodCategory.fish, kcal: 90, protein: 14, carbs: 6, fat: 1, satFat: 0.2, fiber: 1, sugar: 2, sodium: 420, portion: 250, aliases: ['cebiche']),
  _f('arroz_con_pollo', 'Arroz con pollo', FoodCategory.mixedDish, kcal: 155, protein: 9, carbs: 19, fat: 4.5, satFat: 1.2, fiber: 1.3, sugar: 1, sodium: 360, portion: 300, nova: 3, aliases: ['chicken and rice']),
  _f('sopa_verduras', 'Sopa de verduras', _veg, kcal: 35, protein: 1.5, carbs: 6, fat: 0.8, satFat: 0.2, fiber: 1.5, sugar: 2, sodium: 290, portion: 300, nova: 3, aliases: ['sopa', 'vegetable soup', 'caldo', 'crema de verduras']),
  _f('pizza', 'Pizza', FoodCategory.fastFood, kcal: 266, protein: 11, carbs: 33, fat: 10, satFat: 4.5, fiber: 2.3, sugar: 3.6, sodium: 600, portion: 200, nova: 4, aliases: []),
  _f('hamburguesa', 'Hamburguesa', FoodCategory.fastFood, kcal: 254, protein: 13, carbs: 25, fat: 12, satFat: 4.5, fiber: 1.4, sugar: 5, sodium: 500, portion: 220, nova: 4, aliases: ['burger', 'hamburger', 'cheeseburger']),
  _f('empanada', 'Empanada', FoodCategory.mixedDish, kcal: 290, protein: 9, carbs: 30, fat: 15, satFat: 5.5, fiber: 1.5, sugar: 3, sodium: 450, portion: 120, nova: 3, aliases: ['empanada de carne', 'pastel']),
  _f('sandwich', 'Sándwich', FoodCategory.mixedDish, kcal: 230, protein: 11, carbs: 26, fat: 9, satFat: 3, fiber: 2, sugar: 3.5, sodium: 600, portion: 180, nova: 3, aliases: ['sandwich', 'sanguche', 'emparedado']),

  // Dulces, snacks y bebidas
  _f('galletas', 'Galletas dulces', FoodCategory.sweets, kcal: 480, protein: 6, carbs: 68, fat: 20, satFat: 9, fiber: 2, sugar: 30, sodium: 350, portion: 30, nova: 4, aliases: ['cookies', 'galleta', 'biscuits']),
  _f('torta', 'Torta / pastel', FoodCategory.sweets, kcal: 370, protein: 4.5, carbs: 52, fat: 16, satFat: 6, fiber: 1, sugar: 35, sodium: 300, portion: 90, nova: 4, aliases: ['cake', 'queque', 'bizcocho', 'keke']),
  _f('chocolate', 'Chocolate', FoodCategory.sweets, kcal: 535, protein: 7.7, carbs: 59, fat: 30, satFat: 18, fiber: 3.4, sugar: 52, sodium: 79, portion: 25, nova: 4, aliases: ['chocolate bar', 'chocolatina']),
  _f('helado', 'Helado', FoodCategory.sweets, kcal: 207, protein: 3.5, carbs: 24, fat: 11, satFat: 7, fiber: 0.7, sugar: 21, sodium: 80, portion: 100, nova: 4, aliases: ['ice cream']),
  _f('papitas', 'Papitas de bolsa', FoodCategory.snack, kcal: 536, protein: 7, carbs: 53, fat: 35, satFat: 3.5, fiber: 4.4, sugar: 0.3, sodium: 525, portion: 40, nova: 4, aliases: ['chips', 'papas de bolsa', 'snack', 'nachos', 'doritos']),
  _f('gaseosa', 'Gaseosa', FoodCategory.sugaryDrink, kcal: 42, carbs: 10.6, sugar: 10.6, sodium: 4, portion: 500, nova: 4, aliases: ['soda', 'refresco', 'coca cola', 'inca kola', 'cola']),
  _f('jugo_envasado', 'Jugo envasado', FoodCategory.sugaryDrink, kcal: 48, protein: 0.2, carbs: 12, sugar: 11, sodium: 5, portion: 250, nova: 4, aliases: ['nectar', 'juice', 'jugo de caja', 'refresco de fruta']),
  _f('jugo_natural', 'Jugo de fruta natural', FoodCategory.sugaryDrink, kcal: 45, protein: 0.7, carbs: 10.4, fat: 0.2, fiber: 0.2, sugar: 8.4, sodium: 1, portion: 250, aliases: ['jugo de naranja', 'orange juice', 'jugo', 'zumo']),
  _f('chicha_morada', 'Chicha morada', FoodCategory.sugaryDrink, kcal: 50, carbs: 12.5, sugar: 11, sodium: 3, portion: 250, nova: 3, aliases: ['chicha']),
  _f('cafe', 'Café sin azúcar', FoodCategory.beverage, kcal: 2, protein: 0.1, sodium: 2, portion: 200, aliases: ['cafe', 'coffee', 'te', 'infusion', 'tea']),
  _f('agua', 'Agua', FoodCategory.beverage, kcal: 0, portion: 250, aliases: ['water']),

  // Cocina peruana y más (estimaciones promedio por 100 g)
  _f('causa', 'Causa limeña', FoodCategory.mixedDish, kcal: 165, protein: 5, carbs: 20, fat: 7, satFat: 1.2, fiber: 1.8, sugar: 1, sodium: 300, portion: 200, nova: 3, aliases: ['causa', 'causa rellena', 'causa de pollo', 'causa de atun']),
  _f('papa_huancaina', 'Papa a la huancaína', FoodCategory.mixedDish, kcal: 150, protein: 4, carbs: 15, fat: 8, satFat: 3, fiber: 1.5, sugar: 1.5, sodium: 280, portion: 250, nova: 3, aliases: ['huancaina', 'papa huancaina', 'salsa huancaina']),
  _f('arroz_chaufa', 'Arroz chaufa', FoodCategory.mixedDish, kcal: 175, protein: 7, carbs: 25, fat: 5, satFat: 1.2, fiber: 1, sugar: 1.5, sodium: 520, portion: 350, nova: 3, aliases: ['chaufa', 'arroz frito', 'fried rice', 'aeropuerto']),
  _f('tallarines_verdes', 'Tallarines verdes', FoodCategory.mixedDish, kcal: 160, protein: 6, carbs: 20, fat: 6.5, satFat: 2.5, fiber: 1.5, sugar: 1.5, sodium: 300, portion: 350, nova: 3, aliases: ['tallarin verde', 'pesto']),
  _f('tallarines_rojos', 'Tallarines rojos', FoodCategory.mixedDish, kcal: 150, protein: 7, carbs: 20, fat: 4.5, satFat: 1.2, fiber: 1.8, sugar: 3, sodium: 330, portion: 350, nova: 3, aliases: ['tallarin rojo', 'spaghetti con salsa', 'pasta con salsa roja']),
  _f('tallarin_saltado', 'Tallarín saltado', FoodCategory.mixedDish, kcal: 165, protein: 9, carbs: 19, fat: 6, satFat: 1.6, fiber: 1.4, sugar: 2, sodium: 480, portion: 350, nova: 3, aliases: ['tallarin saltado de pollo', 'tallarin saltado de carne']),
  _f('seco', 'Seco de res', FoodCategory.mixedDish, kcal: 140, protein: 12, carbs: 6, fat: 7.5, satFat: 2.8, fiber: 1.2, sugar: 1, sodium: 380, portion: 250, nova: 3, aliases: ['seco', 'seco de carne', 'seco de cordero', 'seco de pollo', 'seco con frejoles']),
  _f('estofado', 'Estofado de pollo', FoodCategory.mixedDish, kcal: 115, protein: 10, carbs: 8, fat: 5, satFat: 1.3, fiber: 1.5, sugar: 2, sodium: 330, portion: 300, nova: 3, aliases: ['estofado', 'guiso de pollo']),
  _f('pollo_saltado', 'Pollo saltado', FoodCategory.mixedDish, kcal: 140, protein: 11, carbs: 10, fat: 6.5, satFat: 1.5, fiber: 1.2, sugar: 2, sodium: 430, portion: 300, nova: 3, aliases: ['saltado de pollo']),
  _f('cau_cau', 'Cau cau', FoodCategory.mixedDish, kcal: 110, protein: 9, carbs: 9, fat: 4.5, satFat: 1.5, fiber: 1.2, sugar: 0.8, sodium: 350, portion: 300, nova: 3, aliases: ['cau cau de mondongo']),
  _f('carapulcra', 'Carapulcra', FoodCategory.mixedDish, kcal: 170, protein: 9, carbs: 18, fat: 7, satFat: 2.2, fiber: 2, sugar: 1, sodium: 350, portion: 300, nova: 3, aliases: ['sopa seca con carapulcra']),
  _f('olluquito', 'Olluquito con charqui', FoodCategory.mixedDish, kcal: 95, protein: 6, carbs: 10, fat: 3.5, satFat: 1, fiber: 1.5, sugar: 2, sodium: 380, portion: 300, nova: 3, aliases: ['olluquito', 'olluco con carne']),
  _f('rocoto_relleno', 'Rocoto relleno', FoodCategory.mixedDish, kcal: 150, protein: 8, carbs: 9, fat: 9, satFat: 4, fiber: 1.5, sugar: 3, sodium: 350, portion: 250, nova: 3, aliases: []),
  _f('adobo', 'Adobo de cerdo', FoodCategory.redMeat, kcal: 170, protein: 15, carbs: 3, fat: 11, satFat: 3.8, fiber: 0.5, sugar: 1, sodium: 450, portion: 250, nova: 3, aliases: ['adobo', 'adobo arequipeño']),
  _f('anticuchos', 'Anticuchos', FoodCategory.redMeat, kcal: 150, protein: 22, carbs: 3, fat: 5.5, satFat: 1.8, fiber: 0.3, sugar: 0.5, sodium: 400, portion: 150, nova: 3, aliases: ['anticucho', 'corazon de res']),
  _f('chicharron', 'Chicharrón de cerdo', FoodCategory.redMeat, kcal: 380, protein: 25, fat: 31, satFat: 11, sodium: 550, portion: 120, nova: 3, aliases: ['chicharron', 'chicharron de chancho']),
  _f('pan_chicharron', 'Pan con chicharrón', FoodCategory.mixedDish, kcal: 270, protein: 12, carbs: 25, fat: 14, satFat: 4.5, fiber: 1.5, sugar: 2, sodium: 550, portion: 200, nova: 3, aliases: ['sanguche de chicharron']),
  _f('tamal', 'Tamal', FoodCategory.mixedDish, kcal: 200, protein: 6, carbs: 22, fat: 10, satFat: 3.5, fiber: 2, sugar: 1, sodium: 400, portion: 150, nova: 3, aliases: ['tamales', 'humita', 'tamalito verde']),
  _f('juane', 'Juane', FoodCategory.mixedDish, kcal: 200, protein: 8, carbs: 22, fat: 9, satFat: 2.5, fiber: 1, sugar: 0.5, sodium: 380, portion: 300, nova: 3, aliases: []),
  _f('tacu_tacu', 'Tacu tacu', FoodCategory.mixedDish, kcal: 190, protein: 7, carbs: 26, fat: 6.5, satFat: 1, fiber: 5, sugar: 0.5, sodium: 320, portion: 250, nova: 3, aliases: []),
  _f('caldo_gallina', 'Caldo de gallina', FoodCategory.mixedDish, kcal: 70, protein: 6, carbs: 5, fat: 3, satFat: 0.9, fiber: 0.3, sugar: 0.5, sodium: 350, portion: 400, nova: 3, aliases: ['caldo de pollo', 'sopa de pollo', 'aguadito', 'chilcano']),
  _f('salchipapa', 'Salchipapa', FoodCategory.fastFood, kcal: 280, protein: 8, carbs: 25, fat: 17, satFat: 5, fiber: 2.5, sugar: 1, sodium: 600, portion: 300, nova: 4, aliases: ['salchipapas']),
  _f('tortilla_verduras', 'Tortilla de verduras', FoodCategory.egg, kcal: 150, protein: 9, carbs: 5, fat: 10.5, satFat: 2.5, fiber: 1.2, sugar: 2, sodium: 300, portion: 150, nova: 3, aliases: ['omelette', 'tortilla de huevo', 'tortilla de espinaca']),

  // Frutas y verduras andinas y amazónicas
  _f('lucuma', 'Lúcuma', _fruit, kcal: 99, protein: 1.5, carbs: 25, fat: 0.5, fiber: 1.3, sugar: 10, sodium: 5, portion: 100, aliases: []),
  _f('chirimoya', 'Chirimoya', _fruit, kcal: 75, protein: 1.6, carbs: 18, fat: 0.7, fiber: 3, sugar: 13, sodium: 7, portion: 150, aliases: []),
  _f('granadilla', 'Granadilla', _fruit, kcal: 97, protein: 2.4, carbs: 23, fat: 0.7, fiber: 6, sugar: 11, sodium: 20, portion: 100, aliases: []),
  _f('maracuya', 'Maracuyá', _fruit, kcal: 97, protein: 2.2, carbs: 23, fat: 0.7, fiber: 10, sugar: 11, sodium: 28, portion: 50, aliases: ['fruta de la pasion', 'passion fruit']),
  _f('aguaymanto', 'Aguaymanto', _fruit, kcal: 53, protein: 1.9, carbs: 11, fat: 0.7, fiber: 4.9, sugar: 8, sodium: 1, portion: 80, aliases: ['physalis', 'uchuva']),
  _f('mandarina', 'Mandarina', _fruit, kcal: 53, protein: 0.8, carbs: 13.3, fat: 0.3, fiber: 1.8, sugar: 10.6, sodium: 2, portion: 100, aliases: ['tangerina']),
  _f('pera', 'Pera', _fruit, kcal: 57, protein: 0.4, carbs: 15, fat: 0.1, fiber: 3.1, sugar: 9.8, sodium: 1, portion: 160, aliases: ['pear']),
  _f('sandia', 'Sandía', _fruit, kcal: 30, protein: 0.6, carbs: 7.6, fat: 0.2, fiber: 0.4, sugar: 6.2, sodium: 1, portion: 250, aliases: ['patilla', 'watermelon']),
  _f('melon', 'Melón', _fruit, kcal: 34, protein: 0.8, carbs: 8.2, fat: 0.2, fiber: 0.9, sugar: 7.9, sodium: 16, portion: 200, aliases: ['melon']),
  _f('durazno', 'Durazno', _fruit, kcal: 39, protein: 0.9, carbs: 9.5, fat: 0.3, fiber: 1.5, sugar: 8.4, portion: 150, aliases: ['melocoton', 'peach']),
  _f('limon', 'Limón', _fruit, kcal: 29, protein: 1.1, carbs: 9.3, fat: 0.3, fiber: 2.8, sugar: 2.5, sodium: 2, portion: 30, aliases: ['lima', 'lemon']),
  _f('beterraga', 'Beterraga', _veg, kcal: 43, protein: 1.6, carbs: 9.6, fat: 0.2, fiber: 2.8, sugar: 6.8, sodium: 78, portion: 80, aliases: ['remolacha', 'betarraga', 'beet']),
  _f('caigua', 'Caigua', _veg, kcal: 17, protein: 0.6, carbs: 3.9, fat: 0.1, fiber: 1.2, sugar: 1.5, sodium: 2, portion: 100, aliases: ['caigua rellena']),
  _f('olluco', 'Olluco', FoodCategory.tuber, kcal: 62, protein: 1.1, carbs: 14, fat: 0.1, fiber: 0.9, sugar: 1, sodium: 5, portion: 100, aliases: ['ulluco', 'papa lisa']),
  _f('platano_sancochado', 'Plátano de isla sancochado', FoodCategory.tuber, kcal: 116, protein: 0.8, carbs: 31, fat: 0.2, fiber: 2.3, sugar: 14, sodium: 5, portion: 150, aliases: ['platano verde', 'platano de isla', 'platano maduro', 'tacacho']),
  _f('habas', 'Habas', FoodCategory.legume, kcal: 88, protein: 7.6, carbs: 15, fat: 0.4, fiber: 5.4, sugar: 1.8, sodium: 5, portion: 100, aliases: ['haba', 'fava beans']),
  _f('arvejas', 'Arvejas', FoodCategory.legume, kcal: 84, protein: 5.4, carbs: 15.6, fat: 0.2, fiber: 5.5, sugar: 5.9, sodium: 3, portion: 80, aliases: ['guisantes', 'chicharos', 'peas']),
  _f('mote', 'Mote', FoodCategory.wholeGrain, kcal: 110, protein: 2.5, carbs: 22, fat: 1.2, fiber: 3, sugar: 0.5, sodium: 10, portion: 100, aliases: ['maiz mote', 'mote de maiz']),
  _f('cancha', 'Cancha serrana', FoodCategory.snack, kcal: 430, protein: 9, carbs: 70, fat: 14, satFat: 2, fiber: 7, sugar: 1, sodium: 400, portion: 30, nova: 3, aliases: ['cancha', 'maiz tostado']),
  _f('chifles', 'Chifles', FoodCategory.snack, kcal: 520, protein: 2, carbs: 58, fat: 31, satFat: 9, fiber: 4, sugar: 3, sodium: 400, portion: 40, nova: 3, aliases: ['platano frito', 'chips de platano']),

  // Más proteínas y lácteos
  _f('pavo', 'Pavo', FoodCategory.leanProtein, kcal: 150, protein: 29, fat: 3, satFat: 1, sodium: 70, portion: 120, aliases: ['pechuga de pavo', 'turkey']),
  _f('higado', 'Hígado de res', FoodCategory.redMeat, kcal: 175, protein: 27, carbs: 5, fat: 5, satFat: 1.9, sodium: 80, portion: 100, aliases: ['higado', 'higado encebollado', 'liver']),
  _f('sangrecita', 'Sangrecita', FoodCategory.leanProtein, kcal: 180, protein: 18, carbs: 5, fat: 10, satFat: 2.5, fiber: 0.5, sodium: 300, portion: 120, nova: 3, aliases: ['sangrecita de pollo']),
  _f('trucha', 'Trucha', FoodCategory.fish, kcal: 140, protein: 20, fat: 6.2, satFat: 1.1, sodium: 50, portion: 150, aliases: ['trucha frita', 'trout']),
  _f('caballa', 'Caballa / jurel', FoodCategory.fish, kcal: 160, protein: 19, fat: 9, satFat: 2.5, sodium: 90, portion: 150, aliases: ['caballa', 'jurel', 'anchoveta', 'sardina', 'mackerel']),
  _f('chorizo', 'Chorizo', FoodCategory.processedMeat, kcal: 450, protein: 24, carbs: 2, fat: 38, satFat: 14, sodium: 1200, portion: 50, nova: 4, aliases: ['chorizo parrillero', 'longaniza']),
  _f('leche_evaporada', 'Leche evaporada', FoodCategory.dairy, kcal: 135, protein: 6.8, carbs: 10, fat: 7.6, satFat: 4.6, sugar: 10, sodium: 106, portion: 30, nova: 3, aliases: ['leche de tarro', 'gloria', 'leche en lata']),

  // Bebidas y postres peruanos
  _f('cafe_leche', 'Café con leche', FoodCategory.dairy, kcal: 45, protein: 2, carbs: 5, fat: 1.8, satFat: 1.1, sugar: 5, sodium: 30, portion: 250, aliases: ['cafe con leche', 'latte']),
  _f('emoliente', 'Emoliente', FoodCategory.sugaryDrink, kcal: 40, carbs: 10, sugar: 9, sodium: 5, portion: 250, nova: 3, aliases: []),
  _f('limonada', 'Limonada', FoodCategory.sugaryDrink, kcal: 40, carbs: 10.5, sugar: 10, sodium: 1, portion: 250, nova: 3, aliases: ['limonada frozen', 'agua de limon']),
  _f('quinua_bebida', 'Quinua con manzana (bebida)', FoodCategory.sugaryDrink, kcal: 60, protein: 1.2, carbs: 13, fat: 0.4, fiber: 0.8, sugar: 9, sodium: 5, portion: 250, nova: 3, aliases: ['quaker', 'avena con manzana', 'bebida de quinua']),
  _f('mazamorra', 'Mazamorra morada', FoodCategory.sweets, kcal: 95, protein: 0.3, carbs: 23, fat: 0.1, fiber: 0.6, sugar: 16, sodium: 10, portion: 200, nova: 3, aliases: ['mazamorra', 'clasico']),
  _f('arroz_leche', 'Arroz con leche', FoodCategory.sweets, kcal: 140, protein: 3.3, carbs: 25, fat: 3, satFat: 1.8, fiber: 0.2, sugar: 14, sodium: 45, portion: 200, nova: 3, aliases: []),
  _f('picarones', 'Picarones', FoodCategory.sweets, kcal: 320, protein: 4, carbs: 45, fat: 14, satFat: 2.5, fiber: 1.5, sugar: 22, sodium: 120, portion: 120, nova: 3, aliases: ['picaron']),
  _f('alfajor', 'Alfajor', FoodCategory.sweets, kcal: 430, protein: 5, carbs: 65, fat: 17, satFat: 9, fiber: 1, sugar: 38, sodium: 150, portion: 40, nova: 4, aliases: ['alfajores', 'king kong']),
];
