import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// Branch-local time helpers for attendance UI and manager corrections.
///
/// The API remains authoritative. These helpers only convert an instant for
/// display or convert a user-selected branch wall time back to UTC before it
/// is submitted.
class BranchTime {
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    _initialized = true;
  }

  static timezone.Location location(String name) {
    initialize();
    try {
      return timezone.getLocation(name);
    } catch (_) {
      return timezone.UTC;
    }
  }

  static DateTime toBranch(DateTime instant, String? branchTimezone) {
    final location = BranchTime.location(branchTimezone ?? 'Asia/Kolkata');
    return timezone.TZDateTime.from(instant.toUtc(), location);
  }

  static DateTime now(String? branchTimezone) =>
      timezone.TZDateTime.now(location(branchTimezone ?? 'Asia/Kolkata'));

  /// Converts a picker value whose fields represent branch-local wall time to
  /// an absolute UTC instant. The picker value must not be interpreted using
  /// the device timezone.
  static DateTime wallTimeToUtc(DateTime wallTime, String? branchTimezone) {
    final location = BranchTime.location(branchTimezone ?? 'Asia/Kolkata');
    return timezone.TZDateTime(
      location,
      wallTime.year,
      wallTime.month,
      wallTime.day,
      wallTime.hour,
      wallTime.minute,
      wallTime.second,
      wallTime.millisecond,
      wallTime.microsecond,
    ).toUtc();
  }

  static DateTime wallFields(DateTime value) => DateTime(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
        value.millisecond,
        value.microsecond,
      );
}
