import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: { findFirst: vi.fn() },
  attendanceSession: { findFirst: vi.fn() },
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { getActiveSession } from './attendance.service';

describe('active attendance session scope', () => {
  beforeEach(() => vi.resetAllMocks());

  it('requires an active member in an active branch', async () => {
    prismaMock.member.findFirst.mockResolvedValue(null);

    await expect(getActiveSession('user-1', 'org-1', 'branch-1')).resolves.toBeNull();

    expect(prismaMock.member.findFirst).toHaveBeenCalledWith({
      where: {
        organization_id: 'org-1',
        branch_id: 'branch-1',
        user_id: 'user-1',
        status: 'ACTIVE',
        branch: { status: 'ACTIVE' },
      },
    });
    expect(prismaMock.attendanceSession.findFirst).not.toHaveBeenCalled();
  });
});
