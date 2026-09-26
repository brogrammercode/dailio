import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  branch: { findFirst: vi.fn() },
  member: { findFirst: vi.fn(), findMany: vi.fn() },
  attendanceSession: { findMany: vi.fn() },
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { listSessions } from './attendance.service';

describe('attendance reporting scope', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    prismaMock.branch.findFirst.mockResolvedValue({ timezone: 'UTC', week_start: 1 });
    prismaMock.member.findFirst.mockResolvedValue({ id: 'manager-1' });
    prismaMock.member.findMany.mockResolvedValue([
      { id: 'manager-1', manager_member_id: null },
      { id: 'direct-1', manager_member_id: 'manager-1' },
      { id: 'nested-1', manager_member_id: 'direct-1' },
      { id: 'unrelated-1', manager_member_id: null },
    ]);
    prismaMock.attendanceSession.findMany.mockResolvedValue([]);
  });

  it('returns the acting member and all descendants for team scope', async () => {
    await listSessions(
      'user-1',
      'org-1',
      'branch-1',
      { period: 'today', limit: 50 },
      new Set(['ATTENDANCE_READ_TEAM']),
    );

    expect(prismaMock.attendanceSession.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          member_id: { in: ['manager-1', 'direct-1', 'nested-1'] },
        }),
      }),
    );
  });

  it('keeps self scope when team permission is absent', async () => {
    await listSessions(
      'user-1',
      'org-1',
      'branch-1',
      { period: 'today', limit: 50 },
      new Set(['ATTENDANCE_READ_SELF']),
    );

    expect(prismaMock.member.findMany).not.toHaveBeenCalled();
    expect(prismaMock.attendanceSession.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ member_id: { in: ['manager-1'] } }),
      }),
    );
  });

  it('includes effective secondary role assignments in role-filtered reports', async () => {
    await listSessions(
      'user-1',
      'org-1',
      'branch-1',
      { period: 'today', limit: 50, role_id: 'coach-role' },
      new Set(['ATTENDANCE_READ_BRANCH']),
    );

    expect(prismaMock.attendanceSession.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          member: expect.objectContaining({
            OR: expect.arrayContaining([
              { role_id: 'coach-role' },
              expect.objectContaining({
                role_assignments: expect.objectContaining({
                  some: expect.objectContaining({ role_id: 'coach-role' }),
                }),
              }),
            ]),
          }),
        }),
      }),
    );
  });
});
