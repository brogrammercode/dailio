import { describe, expect, it, vi } from 'vitest';

vi.mock('../../lib/prisma', () => ({ prisma: {} }));

import { calculateAttendanceVariance, validateShiftWindow } from './attendance.service';

const policy = {
  shift_enforcement_enabled: true,
  early_arrival_minutes: 30,
  late_grace_minutes: 15,
};

const overnightShift = {
  start_time: '22:00',
  end_time: '06:00',
  is_overnight: true,
  week_days: [1], // Monday shift; Tuesday after midnight belongs to Monday.
};

describe('attendance shift enforcement', () => {
  it('allows an overnight clock-in after midnight for the previous scheduled day', () => {
    expect(() =>
      validateShiftWindow(
        overnightShift,
        policy,
        new Date('2026-09-29T02:00:00.000Z'),
        'UTC',
        'clock_in',
      ),
    ).not.toThrow();
  });

  it('rejects the gap between an overnight shift end and the next shift start', () => {
    expect(() =>
      validateShiftWindow(
        overnightShift,
        policy,
        new Date('2026-09-29T12:00:00.000Z'),
        'UTC',
        'clock_in',
      ),
    ).toThrow('Clock-in is before the allowed shift window');
  });

  it('allows overnight clock-out on the following local calendar day', () => {
    expect(() =>
      validateShiftWindow(
        overnightShift,
        policy,
        new Date('2026-09-29T05:30:00.000Z'),
        'UTC',
        'clock_out',
      ),
    ).not.toThrow();
  });

  it('calculates overnight late arrival and early departure against the local end time', () => {
    const clockIn = new Date('2026-09-28T22:20:00.000Z');
    const clockOut = new Date('2026-09-29T05:30:00.000Z');

    expect(calculateAttendanceVariance(overnightShift, policy, clockIn, 'UTC')).toEqual({
      lateMinutes: 5,
      earlyLeaveMinutes: 0,
    });
    expect(calculateAttendanceVariance(overnightShift, policy, clockOut, 'UTC', clockIn)).toEqual({
      lateMinutes: 5,
      earlyLeaveMinutes: 30,
    });
  });

  it('keeps the real late duration for a post-midnight overnight clock-in', () => {
    const clockIn = new Date('2026-09-29T02:00:00.000Z');

    expect(calculateAttendanceVariance(overnightShift, policy, clockIn, 'UTC')).toEqual({
      lateMinutes: 225,
      earlyLeaveMinutes: 0,
    });
  });

  it('does not turn an on-time clock-in into a late clock-out', () => {
    const shift = {
      start_time: '09:00',
      end_time: '17:00',
      is_overnight: false,
      week_days: [1, 2, 3, 4, 5],
    };
    const clockIn = new Date('2026-09-28T09:00:00.000Z');
    const clockOut = new Date('2026-09-28T17:00:00.000Z');

    expect(calculateAttendanceVariance(shift, policy, clockOut, 'UTC', clockIn)).toEqual({
      lateMinutes: 0,
      earlyLeaveMinutes: 0,
    });
  });
});
