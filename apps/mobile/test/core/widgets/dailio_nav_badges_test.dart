import 'package:flutter_test/flutter_test.dart';

import 'package:dailio/core/widgets/dailio_nav_badges.dart';

void main() {
  setUp(() => DailioNavBadgeController.reset());

  test('stores positive counts and removes empty badges', () {
    DailioNavBadgeController.setCount('attendance', 3);
    expect(DailioNavBadgeController.counts.value['attendance'], 3);

    DailioNavBadgeController.setCount('attendance', 0);
    expect(
        DailioNavBadgeController.counts.value.containsKey('attendance'), false);
  });

  test('caps displayed counts at 99', () {
    DailioNavBadgeController.setCount('payments', 120);
    expect(DailioNavBadgeController.counts.value['payments'], 99);
  });
}
