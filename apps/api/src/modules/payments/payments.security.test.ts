import { describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: { findFirst: vi.fn() },
  paymentRequest: { findUnique: vi.fn(), findFirst: vi.fn() },
  $transaction: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { createPaymentRequest, updatePaymentRequest } from './payments.service';

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

  it('does not allow a different member to edit a payment request', async () => {
    prismaMock.paymentRequest.findFirst.mockResolvedValue({
      member: { user_id: 'original-submitter' },
      status: 'REQUESTED',
      amount_minor_unit: 1000,
      evidence: [],
    });

    await expect(
      updatePaymentRequest('different-user', 'org-1', 'branch-1', 'request-1', {
        reference: 'UPI-UPDATED',
      }),
    ).rejects.toThrow('Only the submitting member can edit this payment request');
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });
});
