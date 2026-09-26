import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: { findFirst: vi.fn() },
  attendanceSession: { findFirst: vi.fn(), create: vi.fn() },
  attendancePolicy: { findMany: vi.fn() },
  auditLog: { create: vi.fn() },
  $transaction: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { createManualSession } from './attendance.service';

describe('manual attendance records', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    prismaMock.$transaction.mockImplementation(async (callback: (tx: unknown) => unknown) =>
      callback(prismaMock),
    );
    prismaMock.attendanceSession.findFirst.mockResolvedValue(null);
    prismaMock.attendanceSession.create.mockResolvedValue({
      id: 'session-1',
      state: 'CLOSED',
      source: 'ADMIN',
      derived_status: 'MANUAL',
    });
    prismaMock.member.findFirst
      .mockResolvedValueOnce({
        id: 'member-1',
        branch: { status: 'ACTIVE', timezone: 'Asia/Kolkata' },
      })
      .mockResolvedValueOnce({
        id: 'member-1',
        role_id: null,
        role_assignments: [],
      });
    prismaMock.attendancePolicy.findMany.mockResolvedValue([
      {
        id: 'policy-1',
        version: 4,
        member_id: null,
        role_id: null,
        allow_manual_entry: true,
        effective_from: new Date('2026-09-01T00:00:00.000Z'),
        effective_to: null,
      },
    ]);
  });

  it('creates an audited ADMIN/MANUAL record only when the policy allows it', async () => {
    const result = await createManualSession(
      'manager-1',
      'org-1',
      'branch-1',
      {
        member_id: 'member-1',
        clock_in_at: '2026-09-26T08:00:00.000Z',
        clock_out_at: '2026-09-26T16:00:00.000Z',
        reason: 'Member forgot to punch in at the front desk',
        idempotency_key: 'manual-record-123',
      },
      new Set(['ATTENDANCE_CREATE_ALL']),
    );

    expect(result.source).toBe('ADMIN');
    expect(prismaMock.attendanceSession.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          source: 'ADMIN',
          derived_status: 'MANUAL',
          worked_minutes: 480,
          idempotency_key_in: 'manual-record-123',
        }),
      }),
    );
    expect(prismaMock.auditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          reason: 'Member forgot to punch in at the front desk',
          target_type: 'AttendanceSession',
        }),
      }),
    );
  });

  it('rejects an unauthorized manual-record command', async () => {
    await expect(
      createManualSession(
        'member-1',
        'org-1',
        'branch-1',
        {
          member_id: 'member-1',
          clock_in_at: '2026-09-26T08:00:00.000Z',
          reason: 'Attempted manual record',
          idempotency_key: 'manual-record-456',
        },
        new Set(['ATTENDANCE_CREATE_SELF']),
      ),
    ).rejects.toThrow('Manual attendance entry permission is required');
  });
});
