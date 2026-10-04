import 'food_category.dart';
import 'nutrients.dart';

enum FoodSource { local, openFoodFacts, ai, custom }

/// Alimento o producto con sus nutrientes por cada 100 g.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.per100g,
    required this.category,
    this.typicalPortionGrams = 100,
    this.novaGroup,
    this.aliases = const [],
    this.barcode,
    this.brand,
    this.servingSize,
    this.ingredients,
    this.imageUrl,
    this.nutriScoreGrade,
    this.source = FoodSource.local,
    this.warnings = const [],
  });

  final String id;
  final String name;
  final Nutrients per100g;
  final FoodCategory category;
  final double typicalPortionGrams;

  /// Clasificación NOVA de procesamiento (1 = sin procesar, 4 = ultraprocesado).
  final int? novaGroup;
  final List<String> aliases;
  final String? barcode;
  final String? brand;
  final String? servingSize;
  final String? ingredients;
  final String? imageUrl;
  final String? nutriScoreGrade;
  final FoodSource source;

  /// Octógonos de advertencia leídos de la etiqueta (high_sugar, high_sodium,
  /// high_saturated_fat, contains_trans_fat).
  final List<String> warnings;

  bool get isUltraProcessed => (novaGroup ?? 1) >= 4;

  /// El azúcar de este alimento se cuenta como añadido (aproximación).
  bool get hasAddedSugar {
    if (category.sugarCountsAsAdded) return true;
    return source == FoodSource.openFoodFacts && (novaGroup ?? 1) >= 3;
  }

  FoodItem copyWith({String? name, FoodCategory? category}) => FoodItem(
        id: id,
        name: name ?? this.name,
        per100g: per100g,
        category: category ?? this.category,
        typicalPortionGrams: typicalPortionGrams,
        novaGroup: novaGroup,
        aliases: aliases,
        barcode: barcode,
        brand: brand,
        servingSize: servingSize,
        ingredients: ingredients,
        imageUrl: imageUrl,
        nutriScoreGrade: nutriScoreGrade,
        source: source,
        warnings: warnings,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'per100g': per100g.toJson(),
        'category': category.name,
        'typical_portion_grams': typicalPortionGrams,
        'nova_group': novaGroup,
        'barcode': barcode,
        'brand': brand,
        'serving_size': servingSize,
        'ingredients': ingredients,
        'image_url': imageUrl,
        'nutriscore_grade': nutriScoreGrade,
        'source': source.name,
        'warnings': warnings,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String,
        per100g: Nutrients.fromJson(Map<String, dynamic>.from(json['per100g'] as Map)),
        category: FoodCategory.fromName(json['category'] as String?),
        typicalPortionGrams: (json['typical_portion_grams'] as num?)?.toDouble() ?? 100,
        novaGroup: (json['nova_group'] as num?)?.toInt(),
        barcode: json['barcode'] as String?,
        brand: json['brand'] as String?,
        servingSize: json['serving_size'] as String?,
        ingredients: json['ingredients'] as String?,
        imageUrl: json['image_url'] as String?,
        nutriScoreGrade: json['nutriscore_grade'] as String?,
        source: FoodSource.values.firstWhere(
          (source) => source.name == json['source'],
          orElse: () => FoodSource.custom,
        ),
        warnings: (json['warnings'] as List?)?.whereType<String>().toList() ?? const [],
      );
}
