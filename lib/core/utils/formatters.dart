import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );

  static String currency(num amount) => _currency.format(amount);

  static final DateFormat _shortDate = DateFormat('d MMM yyyy');

  static String shortDate(DateTime date) => _shortDate.format(date);

  static final DateFormat _timeOnly = DateFormat('h:mm a');

  /// Chat-style timestamp: just the time for today, otherwise a short date.
  static String messageTime(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return isToday ? _timeOnly.format(date) : _shortDate.format(date);
  }
}
