abstract final class AppConstants {
  static const appName = 'NutriSemáforo';
  static const slogan = 'Conoce lo que comes. Mejora tus hábitos.';
  static const version = '1.0.0';

  static const openFoodFactsBaseUrl = 'https://world.openfoodfacts.org';

  /// Open Food Facts pide identificar la aplicación en el User-Agent.
  static const openFoodFactsUserAgent = 'NutriSemaforo/1.0 (Android; contacto: app@nutrisemaforo.local)';

  static const requestTimeout = Duration(seconds: 20);
  static const analysisTimeout = Duration(seconds: 90);

  /// Por debajo de esta confianza se avisa al usuario y se sugiere revisar.
  static const lowConfidenceThreshold = 0.6;

  static const maxImageDimension = 1280.0;
  static const imageQuality = 80;
  static const maxFoodGrams = 3000.0;
}
