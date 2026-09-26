import 'package:flutter_test/flutter_test.dart';

import 'package:dailio/features/branch/pages/configure_member_page.dart';

void main() {
  test('normalizes subscription IDs and keeps a stale current value selectable',
      () {
    final options = normalizeSubscriptionOptions(
      [
        {
          'id': 'subscription-1',
          'status': 'ACTIVE',
          'plan': {'name': '3 Months'},
        },
        {
          'id': 'subscription-1',
          'status': 'ACTIVE',
          'plan': {'name': 'Duplicate'},
        },
      ],
      currentSubscriptionId: 'subscription-stale',
      currentPlanName: '1 Month',
    );

    expect(options, [
      {'id': 'subscription-1', 'label': '3 Months · active'},
      {'id': 'subscription-stale', 'label': '1 Month'},
    ]);
  });
}
