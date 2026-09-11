import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _dateFormatter = DateFormat('dd MMM yyyy');
  static final _dateTimeFormatter = DateFormat('dd MMM yyyy, hh:mm a');
  static final _timeFormatter = DateFormat('hh:mm a');
  static final _monthFormatter = DateFormat('MMMM yyyy');

  static String formatDate(DateTime date) =>
      _dateFormatter.format(date.toLocal());
  static String formatDateTime(DateTime date) =>
      _dateTimeFormatter.format(date.toLocal());
  static String formatTime(DateTime date) =>
      _timeFormatter.format(date.toLocal());
  static String formatMonth(DateTime date) =>
      _monthFormatter.format(date.toLocal());

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final local = date.toLocal();
    return local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
  }

  static String relativeLabel(DateTime date) {
    if (isToday(date)) return 'Today';
    if (isYesterday(date)) return 'Yesterday';
    return formatDate(date);
  }
}
