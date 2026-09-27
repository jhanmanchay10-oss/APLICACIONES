import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _oneDecimal = NumberFormat('#,##0.0', 'es');
  static final _integer = NumberFormat('#,##0', 'es');

  static String grams(double value) => '${value < 10 ? _oneDecimal.format(value) : _integer.format(value)} g';

  static String mg(double value) => '${_integer.format(value)} mg';

  static String kcal(double value) => '${_integer.format(value)} kcal';

  static String number(double value) => value < 10 ? _oneDecimal.format(value) : _integer.format(value);
}
