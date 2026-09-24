import { describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  subscription: { findUnique: vi.fn() },
  $transaction: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { assignSubscription } from './subscriptions.service';

describe('subscription idempotency isolation', () => {
  it('does not replay an idempotency key for another member or tenant', async () => {
    prismaMock.subscription.findUnique.mockResolvedValue({
      organization_id: 'other-org',
      branch_id: 'other-branch',
      member_id: 'other-member',
    });

    await expect(
      assignSubscription('user-1', 'org-1', 'branch-1', 'member-1', 'same-key', {
        plan_id: 'plan-1',
        start_date: '2026-01-01T00:00:00.000Z',
      }),
    ).rejects.toThrow('another subscription');
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });
});
