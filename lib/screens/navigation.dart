import 'package:flutter/material.dart';

import '../models/meal.dart';
import 'analyze/analyze_screen.dart';
import 'barcode/barcode_scanner_screen.dart';
import 'result/result_screen.dart';
import 'search/food_search_screen.dart';

/// Rutas compartidas entre pantallas.
abstract final class AppNavigation {
  static Future<T?> push<T>(BuildContext context, Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  static Future<void> analyzePlate(BuildContext context) => push(context, const AnalyzeScreen());

  static Future<void> scanProduct(BuildContext context) => push(context, const BarcodeScannerScreen());

  static Future<void> searchFood(BuildContext context) => push(context, const FoodSearchScreen());

  static Future<void> openMeal(BuildContext context, Meal meal) =>
      push(context, ResultScreen(meal: meal, isNew: false));

  /// Vuelve a la pantalla principal tras guardar una comida.
  static void backToHome(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);
}
