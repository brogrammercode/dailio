import 'package:flutter/foundation.dart';

/// Counts shown on primary destinations. Values are server-backed page counts
/// and are intentionally small, local to the active organization/branch.
class DailioNavBadgeController {
  DailioNavBadgeController._();

  static final ValueNotifier<Map<String, int>> counts =
      ValueNotifier(<String, int>{});

  static void setCount(String key, int value) {
    final next = Map<String, int>.from(counts.value);
    if (value <= 0) {
      next.remove(key);
    } else {
      next[key] = value > 99 ? 99 : value;
    }
    counts.value = next;
  }

  static void reset() => counts.value = <String, int>{};
}
