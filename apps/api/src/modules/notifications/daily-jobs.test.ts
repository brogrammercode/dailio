import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  dailyJobRun: {
    create: vi.fn(),
    findUnique: vi.fn(),
    updateMany: vi.fn(),
    update: vi.fn(),
  },
}));

const reviewOpenMock = vi.hoisted(() => vi.fn());
const retentionMock = vi.hoisted(() => vi.fn());
const expiryMock = vi.hoisted(() => vi.fn());
const overdueMock = vi.hoisted(() => vi.fn());
const paymentReviewMock = vi.hoisted(() => vi.fn());
const scheduledAnnouncementsMock = vi.hoisted(() => vi.fn());
const announcementExpiryMock = vi.hoisted(() => vi.fn());
const retryMock = vi.hoisted(() => vi.fn());
const monthlyReportsMock = vi.hoisted(() => vi.fn());

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));
vi.mock('../../config/logger', () => ({ logger: { error: vi.fn() } }));
vi.mock('../attendance/attendance.service', () => ({
  reviewOpenAttendanceSessions: reviewOpenMock,
  purgeExpiredAttendanceEvidence: retentionMock,
}));
vi.mock('./scheduled-jobs.service', () => ({
  runSubscriptionExpiryNotifications: expiryMock,
  runOverdueFeeNotifications: overdueMock,
  runPendingPaymentReviewNotifications: paymentReviewMock,
  runScheduledAnnouncementPublishing: scheduledAnnouncementsMock,
  runAnnouncementExpiry: announcementExpiryMock,
  runNotificationDeliveryRetries: retryMock,
}));
vi.mock('./monthly-reports.service', () => ({
  runMonthlyMemberReports: monthlyReportsMock,
  previousMonthPeriod: () => ({
    start: new Date('2026-08-01T00:00:00.000Z'),
    end: new Date('2026-09-01T00:00:00.000Z'),
    label: 'August 2026',
  }),
}));

import { runDailyNotificationCoordinator } from './daily-jobs.service';

describe('daily notification coordinator claim and lease behavior', () => {
  const claimedRun = {
    id: 'run-a',
    status: 'RUNNING',
    lease_until: new Date('2026-09-29T10:05:00.000Z'),
  };

  beforeEach(() => {
    vi.resetAllMocks();
    prismaMock.dailyJobRun.create.mockResolvedValue(claimedRun);
    prismaMock.dailyJobRun.update.mockResolvedValue({});
    reviewOpenMock.mockResolvedValue({ scanned: 0 });
    retentionMock.mockResolvedValue({ scanned: 0 });
    expiryMock.mockResolvedValue({ scanned: 0, notified: 0 });
    overdueMock.mockResolvedValue({ scanned: 0, notified: 0 });
    paymentReviewMock.mockResolvedValue({ scanned: 0, notified: 0 });
    scheduledAnnouncementsMock.mockResolvedValue({ scanned: 0, published: 0 });
    announcementExpiryMock.mockResolvedValue({ expired: 0 });
    retryMock.mockResolvedValue({ scanned: 0, retried: 0 });
    monthlyReportsMock.mockResolvedValue({ branches: 0, sent: 0, skipped: 0 });
  });

  it('completes one claimed run after all bounded jobs finish', async () => {
    const result = await runDailyNotificationCoordinator();

    expect(result.status).toBe('completed');
    expect(prismaMock.dailyJobRun.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'run-a' },
        data: expect.objectContaining({ status: 'COMPLETED' }),
      }),
    );
  });

  it('does not rerun a completed run when another app open already won', async () => {
    prismaMock.dailyJobRun.create.mockRejectedValue({ code: 'P2002' });
    prismaMock.dailyJobRun.findUnique.mockResolvedValue({
      id: 'run-a',
      status: 'COMPLETED',
      lease_until: null,
    });

    const result = await runDailyNotificationCoordinator();

    expect(result).toEqual({
      status: 'completed',
      job: 'DAILY_NOTIFICATION_COORDINATOR',
    });
    expect(reviewOpenMock).not.toHaveBeenCalled();
  });

  it('reclaims an expired lease and records a failed run for retry', async () => {
    prismaMock.dailyJobRun.create.mockRejectedValue({ code: 'P2002' });
    prismaMock.dailyJobRun.findUnique
      .mockResolvedValueOnce({
        id: 'run-a',
        status: 'RUNNING',
        lease_until: new Date('2020-01-01T00:00:00.000Z'),
      })
      .mockResolvedValueOnce(claimedRun);
    prismaMock.dailyJobRun.updateMany.mockResolvedValue({ count: 1 });
    expiryMock.mockRejectedValue(new Error('temporary job failure'));

    await expect(runDailyNotificationCoordinator()).rejects.toThrow('temporary job failure');
    expect(prismaMock.dailyJobRun.updateMany).toHaveBeenCalled();
    expect(prismaMock.dailyJobRun.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'FAILED', last_error: 'JOB_FAILED' }),
      }),
    );
  });
});
