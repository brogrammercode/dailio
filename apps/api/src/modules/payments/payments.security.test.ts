import { describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: { findFirst: vi.fn() },
  paymentRequest: { findUnique: vi.fn() },
  $transaction: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { createPaymentRequest } from './payments.service';

describe('payment request tenant and idempotency isolation', () => {
  it('does not replay an idempotency key from another member or tenant', async () => {
    prismaMock.member.findFirst.mockResolvedValue({ id: 'member-1' });
    prismaMock.paymentRequest.findUnique.mockResolvedValue({
      organization_id: 'other-org',
      branch_id: 'other-branch',
      member_id: 'other-member',
    });

    await expect(
      createPaymentRequest('user-1', 'org-1', 'branch-1', 'same-key', {
        subscription_id: 'sub-1',
        amount_minor_unit: 1000,
        currency: 'INR',
        method: 'UPI',
        evidence: [],
      }),
    ).rejects.toThrow('another tenant context');
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });
});
