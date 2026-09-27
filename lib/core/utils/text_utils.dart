abstract final class TextUtils {
  static const _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n',
  };

  /// Minúsculas, sin tildes y sin espacios extra, para comparar nombres.
  static String normalize(String text) {
    final lower = text.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Limita la longitud y elimina caracteres de control de un texto ingresado.
  static String sanitize(String text, {int maxLength = 80}) {
    final cleaned = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
  }
}
