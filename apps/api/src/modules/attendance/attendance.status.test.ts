import { describe, expect, it, vi } from 'vitest';

vi.mock('../../lib/prisma', () => ({ prisma: {} }));

import { deriveAttendanceStatus } from './attendance.service';

const policy = (overrides: Record<string, unknown> = {}) => ({
  min_session_minutes: 30,
  max_open_session_hours: 24,
  ...overrides,
});

describe('attendance derived status', () => {
  it('marks a session incomplete when it is shorter than the minimum', () => {
    expect(
      deriveAttendanceStatus(null, 29, policy(), { lateMinutes: 0, earlyLeaveMinutes: 0 }),
    ).toBe('INCOMPLETE');
  });

  it('marks a session incomplete when it exceeds the maximum open duration', () => {
    expect(
      deriveAttendanceStatus(null, 1_441, policy({ max_open_session_hours: 24 }), {
        lateMinutes: 0,
        earlyLeaveMinutes: 0,
      }),
    ).toBe('INCOMPLETE');
  });

  it('preserves late status before early-departure status', () => {
    expect(
      deriveAttendanceStatus('LATE', 60, policy(), { lateMinutes: 5, earlyLeaveMinutes: 10 }),
    ).toBe('LATE');
  });

  it('marks a qualifying early departure and otherwise marks presence', () => {
    expect(
      deriveAttendanceStatus(null, 60, policy(), { lateMinutes: 0, earlyLeaveMinutes: 10 }),
    ).toBe('LEFT_EARLY');
    expect(
      deriveAttendanceStatus(null, 60, policy(), { lateMinutes: 0, earlyLeaveMinutes: 0 }),
    ).toBe('PRESENT');
  });
});
