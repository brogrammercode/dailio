import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  subscription: { findMany: vi.fn(), updateMany: vi.fn() },
  ledgerEntry: { findMany: vi.fn() },
  paymentRequest: { findMany: vi.fn() },
}));
const notifyMock = vi.hoisted(() => vi.fn());
const retryMock = vi.hoisted(() => vi.fn());
const reviewersMock = vi.hoisted(() => vi.fn());

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));
vi.mock('./notifications.service', () => ({
  notify: notifyMock,
  findBranchRecipientUserIds: reviewersMock,
  retryFailedNotificationDeliveries: retryMock,
}));

import {
  runNotificationDeliveryRetries,
  runPendingPaymentReviewNotifications,
  runOverdueFeeNotifications,
  runSubscriptionExpiryNotifications,
} from './scheduled-jobs.service';

describe('scheduled notification jobs', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    reviewersMock.mockResolvedValue([]);
  });

  it('notifies once per expiring subscription and uses a stable daily dedupe key', async () => {
    const now = new Date('2026-09-29T10:00:00.000Z');
    prismaMock.subscription.findMany.mockResolvedValue([
      {
        id: 'subscription-a',
        organization_id: 'org-a',
        branch_id: 'branch-a',
        end_date: new Date('2026-10-02T10:00:00.000Z'),
        status: 'ACTIVE',
        member: { user_id: 'user-a' },
        branch: { timezone: 'Asia/Kolkata' },
      },
    ]);

    await runSubscriptionExpiryNotifications(now);

    expect(notifyMock).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'SUBSCRIPTION_EXPIRING',
        recipientUserIds: ['user-a'],
        dedupeKey: 'subscription:subscription-a:expiring:2026-09-29',
      }),
    );
  });

  it('delegates failed delivery retry to the bounded central delivery worker', async () => {
    retryMock.mockResolvedValue({ scanned: 2, retried: 1 });

    await expect(
      runNotificationDeliveryRetries(new Date('2026-09-29T10:00:00.000Z')),
    ).resolves.toEqual({ scanned: 2, retried: 1 });
    expect(retryMock).toHaveBeenCalledWith(expect.any(Date), 100);
  });

  it('notifies the member for an overdue ledger entry', async () => {
    prismaMock.ledgerEntry.findMany.mockResolvedValue([
      {
        id: 'ledger-a',
        organization_id: 'org-a',
        branch_id: 'branch-a',
        member_id: 'member-a',
        member: { user_id: 'user-a' },
        branch: { timezone: 'Asia/Kolkata' },
      },
    ]);

    await runOverdueFeeNotifications(new Date('2026-09-29T10:00:00.000Z'));

    expect(notifyMock).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FEE_OVERDUE',
        recipientUserIds: ['user-a'],
        dedupeKey: 'ledger-entry:ledger-a:overdue:2026-09-29',
      }),
    );
  });

  it('reminds permissioned reviewers about stale payment requests', async () => {
    prismaMock.paymentRequest.findMany.mockResolvedValue([
      {
        id: 'request-a',
        organization_id: 'org-a',
        branch_id: 'branch-a',
        status: 'REQUESTED',
      },
    ]);
    reviewersMock.mockResolvedValue(['reviewer-a']);

    await runPendingPaymentReviewNotifications(new Date('2026-09-29T10:00:00.000Z'));

    expect(notifyMock).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'PAYMENT_REVIEW_REMINDER',
        recipientUserIds: ['reviewer-a'],
        dedupeKey: 'payment-request:request-a:review-reminder:2026-09-29',
      }),
    );
  });
});
