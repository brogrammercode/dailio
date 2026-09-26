import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: {
    findUnique: vi.fn(),
    update: vi.fn(),
  },
  auditLog: { create: vi.fn() },
  $transaction: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { updateMember } from './members.service';

describe('member reporting hierarchy', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    prismaMock.$transaction.mockImplementation(async (callback: (tx: unknown) => unknown) =>
      callback(prismaMock),
    );
  });

  it('accepts an active manager from the same branch', async () => {
    prismaMock.member.findUnique
      .mockResolvedValueOnce({
        id: 'member-1',
        organization_id: 'org-1',
        branch_id: 'branch-1',
      })
      .mockResolvedValueOnce({
        id: 'manager-1',
        organization_id: 'org-1',
        branch_id: 'branch-1',
        status: 'ACTIVE',
        manager_member_id: null,
      });
    prismaMock.member.update.mockResolvedValue({ id: 'member-1', manager_member_id: 'manager-1' });

    await updateMember('actor-1', 'org-1', 'branch-1', 'member-1', {
      manager_member_id: 'manager-1',
    });

    expect(prismaMock.member.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'member-1' },
        data: expect.objectContaining({ manager_member_id: 'manager-1' }),
      }),
    );
  });

  it('rejects a self-manager assignment before mutation', async () => {
    prismaMock.member.findUnique
      .mockResolvedValueOnce({
        id: 'member-1',
        organization_id: 'org-1',
        branch_id: 'branch-1',
      })
      .mockResolvedValueOnce({
        id: 'member-1',
        organization_id: 'org-1',
        branch_id: 'branch-1',
        status: 'ACTIVE',
        manager_member_id: null,
      });

    await expect(
      updateMember('actor-1', 'org-1', 'branch-1', 'member-1', {
        manager_member_id: 'member-1',
      }),
    ).rejects.toThrow('Reporting hierarchy cannot contain a cycle');
    expect(prismaMock.member.update).not.toHaveBeenCalled();
  });
});
