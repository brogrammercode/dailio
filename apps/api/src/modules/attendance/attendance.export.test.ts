import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  branch: { findFirst: vi.fn() },
  member: { findFirst: vi.fn(), findMany: vi.fn() },
  attendanceSession: { findMany: vi.fn() },
  auditLog: { create: vi.fn() },
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { exportSessions } from './attendance.service';

describe('attendance export audit', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    prismaMock.branch.findFirst.mockResolvedValue({ timezone: 'UTC', week_start: 1 });
    prismaMock.attendanceSession.findMany.mockResolvedValue([]);
    prismaMock.auditLog.create.mockResolvedValue({ id: 'audit-1' });
  });

  it('records a branch-scoped export audit after applying report scope', async () => {
    const csv = await exportSessions(
      'owner-user',
      'organization-1',
      'branch-1',
      { period: 'this_month', limit: 50 },
      new Set(['ATTENDANCE_READ_ALL']),
    );

    expect(csv).toContain('member_id');
    expect(prismaMock.auditLog.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        organization_id: 'organization-1',
        branch_id: 'branch-1',
        actor_id: 'owner-user',
        action: 'EXPORT',
        target_type: 'AttendanceSessionExport',
        target_id: 'branch-1',
        after_state: {
          period: 'this_month',
          row_count: 0,
          role_filter: null,
        },
      }),
    });
  });
});
