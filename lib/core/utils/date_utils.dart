import 'package:intl/intl.dart';

abstract final class AppDates {
  static DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Lunes de la semana de [date].
  static DateTime startOfWeek(DateTime date) =>
      dateOnly(date).subtract(Duration(days: date.weekday - DateTime.monday));

  static String dayLabel(DateTime date, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final target = dateOnly(date);
    final difference = today.difference(target).inDays;
    if (difference == 0) return 'Hoy';
    if (difference == 1) return 'Ayer';
    return capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(date));
  }

  static String time(DateTime date) => DateFormat.Hm('es').format(date);

  static String weekdayName(DateTime date) => capitalize(DateFormat.EEEE('es').format(date));

  static String weekdayShort(DateTime date) => capitalize(DateFormat.E('es').format(date)).replaceAll('.', '');

  static String weekRange(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    final format = DateFormat("d MMM", 'es');
    return '${format.format(weekStart)} – ${format.format(end)}';
  }

  static String capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
