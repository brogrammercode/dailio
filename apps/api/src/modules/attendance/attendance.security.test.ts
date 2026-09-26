import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: { findFirst: vi.fn(), findMany: vi.fn() },
  attendancePolicy: { findMany: vi.fn(), findFirst: vi.fn() },
  attendanceSession: { findFirst: vi.fn() },
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { UnprocessableError } from '../../lib/errors';

import {
  clockOut,
  getAttendanceFailureMessage,
  getPolicy,
  getSessionDetail,
} from './attendance.service';

describe('attendance tenant and branch authorization boundaries', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it('includes organization and branch scope when resolving a session detail', async () => {
    prismaMock.attendanceSession.findFirst.mockResolvedValue({
      id: 'session-1',
      member: { user_id: 'member-user', user: { id: 'member-user', name: 'Member' } },
      evidence: [],
      corrections: [],
    });

    await getSessionDetail(
      'manager-user',
      'organization-a',
      'branch-a',
      'session-1',
      new Set(['ATTENDANCE_READ_ALL']),
    );

    expect(prismaMock.attendanceSession.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'session-1',
          organization_id: 'organization-a',
          branch_id: 'branch-a',
        }),
      }),
    );
  });

  it('rejects a target member that is not active in the requested organization and branch', async () => {
    prismaMock.member.findFirst
      .mockResolvedValueOnce({ id: 'actor-membership' })
      .mockResolvedValueOnce(null);

    await expect(
      getPolicy(
        'organization-a',
        'branch-a',
        'manager-user',
        new Set(['ATTENDANCE_POLICY_READ']),
        'member-from-another-tenant',
      ),
    ).rejects.toThrow('Member policy target not found');

    expect(prismaMock.member.findFirst).toHaveBeenLastCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organization_id: 'organization-a',
          branch_id: 'branch-a',
          id: 'member-from-another-tenant',
          status: 'ACTIVE',
        }),
      }),
    );
  });

  it('scopes clock-out idempotency replay to the authorized session member', async () => {
    prismaMock.attendanceSession.findFirst.mockResolvedValueOnce({
      id: 'session-1',
      organization_id: 'organization-a',
      branch_id: 'branch-a',
      member_id: 'member-a',
      member: { user_id: 'member-user' },
    });
    prismaMock.attendanceSession.findFirst.mockResolvedValue({
      id: 'prior-session',
      member_id: 'member-a',
      evidence: [],
    });

    await clockOut(
      'member-user',
      'organization-a',
      'branch-a',
      {
        session_id: 'session-1',
        idempotency_key: 'clock-out-key-12345678',
        timezone: 'UTC',
      },
      new Set(),
    );

    expect(prismaMock.attendanceSession.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          idempotency_key_out: 'clock-out-key-12345678',
          organization_id: 'organization-a',
          branch_id: 'branch-a',
          member_id: 'member-a',
        },
      }),
    );
  });

  it('scopes the clock-out target lookup to the tenant and branch', async () => {
    prismaMock.attendanceSession.findFirst.mockResolvedValueOnce({
      id: 'session-1',
      organization_id: 'organization-a',
      branch_id: 'branch-a',
      member_id: 'member-a',
      member: { user_id: 'member-user' },
    });
    prismaMock.attendanceSession.findFirst.mockResolvedValueOnce(null);

    await expect(
      clockOut(
        'member-user',
        'organization-a',
        'branch-a',
        {
          session_id: 'session-1',
          idempotency_key: 'clock-out-key-12345678',
          timezone: 'UTC',
        },
        new Set(),
      ),
    ).rejects.toThrow();

    expect(prismaMock.attendanceSession.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'session-1',
          organization_id: 'organization-a',
          branch_id: 'branch-a',
        }),
      }),
    );
  });

  it('never copies unknown provider/database errors into member notifications', () => {
    expect(getAttendanceFailureMessage(new Error('database password leaked'))).toBe(
      'Attendance could not be validated. Please try again.',
    );
    expect(
      getAttendanceFailureMessage(
        new UnprocessableError('You are outside the branch attendance geofence'),
      ),
    ).toBe('You are outside the branch attendance geofence');
  });
});
