import 'package:flutter_test/flutter_test.dart';

import 'package:dailio/core/utils/branch_time.dart';

void main() {
  setUpAll(BranchTime.initialize);

  test('converts UTC instants to branch-local wall time', () {
    final branchTime = BranchTime.toBranch(
      DateTime.utc(2026, 1, 15, 4, 0),
      'Asia/Kolkata',
    );

    expect(branchTime.year, 2026);
    expect(branchTime.month, 1);
    expect(branchTime.day, 15);
    expect(branchTime.hour, 9);
    expect(branchTime.minute, 30);
  });

  test('converts branch-local picker fields to UTC', () {
    final utc = BranchTime.wallTimeToUtc(
      DateTime(2026, 1, 15, 9, 30),
      'Asia/Kolkata',
    );

    expect(utc, DateTime.utc(2026, 1, 15, 4, 0));
  });

  test('falls back safely for an unknown timezone', () {
    final utc = BranchTime.wallTimeToUtc(
      DateTime(2026, 1, 15, 9, 30),
      'Not/ARealTimezone',
    );

    expect(utc, DateTime.utc(2026, 1, 15, 9, 30));
  });
}
