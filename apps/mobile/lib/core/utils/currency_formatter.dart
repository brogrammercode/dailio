import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Converts paise (minor units) to formatted INR string.
  static String formatPaise(int paise) {
    final rupees = paise / 100.0;
    return _inrFormatter.format(rupees);
  }

  static String formatRupees(double rupees) => _inrFormatter.format(rupees);
}
