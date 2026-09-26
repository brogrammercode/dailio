import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: { findFirst: vi.fn() },
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { resolveEffectivePermissions } from './authorization.service';

describe('effective authorization role assignments', () => {
  beforeEach(() => vi.clearAllMocks());

  it('keeps permissions when a legacy member has no primary role but has an active assignment', async () => {
    prismaMock.member.findFirst.mockResolvedValue({
      role: null,
      role_assignments: [
        {
          role: {
            system_key: null,
            permissions: ['ATTENDANCE_READ_SELF'],
          },
        },
      ],
    });

    await expect(resolveEffectivePermissions('user-1', 'org-1', 'branch-1')).resolves.toEqual(
      new Set(['ATTENDANCE_READ_SELF']),
    );
    expect(prismaMock.member.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organization_id: 'org-1',
          branch_id: 'branch-1',
        }),
      }),
    );
  });

  it('recognizes an owner through an effective role assignment', async () => {
    prismaMock.member.findFirst.mockResolvedValue({
      role: null,
      role_assignments: [
        {
          role: {
            system_key: 'OWNER',
            permissions: [],
          },
        },
      ],
    });

    await expect(resolveEffectivePermissions('user-1', 'org-1', 'branch-1')).resolves.toEqual(
      new Set(['ALL']),
    );
  });
});
