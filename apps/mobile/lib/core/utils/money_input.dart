import 'package:intl/intl.dart';

int? parseMoneyMinor(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = int.tryParse(parts[0]);
  final fraction =
      int.tryParse(parts.length == 1 ? '00' : parts[1].padRight(2, '0'));
  if (whole == null || fraction == null) return null;
  final minor = whole * 100 + fraction;
  return minor > 0 && minor <= 2147483647 ? minor : null;
}

String formatMoneyInput(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

String formatMoneyMinor(int minor, {String symbol = '₹'}) {
  final absolute = minor.abs();
  final whole = NumberFormat.decimalPattern('en_IN').format(absolute ~/ 100);
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  return '${minor < 0 ? '-' : ''}$symbol$whole.$fraction';
}
