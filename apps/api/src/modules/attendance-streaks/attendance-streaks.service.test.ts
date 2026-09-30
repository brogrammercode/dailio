import { describe, expect, it } from 'vitest';

import { calculateStreakFromDates, recurringWeekdayDates } from './attendance-streaks.service';

describe('attendance streak calculation', () => {
  it('ignores a holiday gap without counting it as attendance', () => {
    expect(
      calculateStreakFromDates(
        ['2026-01-01', '2026-01-02', '2026-01-04'],
        ['2026-01-03'],
        '2026-01-04',
      ),
    ).toEqual({
      current: 3,
      best: 3,
      lastAttendanceDate: '2026-01-04',
    });
  });

  it('resets on an ordinary missed day and counts attendance on holidays', () => {
    expect(
      calculateStreakFromDates(['2026-01-01', '2026-01-03', '2026-01-04'], [], '2026-01-04')
        .current,
    ).toBe(2);

    expect(
      calculateStreakFromDates(['2026-01-01', '2026-01-03'], ['2026-01-02'], '2026-01-03').current,
    ).toBe(2);
  });

  it('expands recurring weekdays using ISO weekday numbers', () => {
    expect([...recurringWeekdayDates([2, 7], '2026-01-05', '2026-01-11')]).toEqual([
      '2026-01-06',
      '2026-01-11',
    ]);
  });
});
