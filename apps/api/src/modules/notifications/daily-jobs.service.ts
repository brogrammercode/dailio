import { Prisma } from '@prisma/client';

import { logger } from '../../config/logger';
import { prisma } from '../../lib/prisma';
import {
  purgeExpiredAttendanceEvidence,
  reviewOpenAttendanceSessions,
} from '../attendance/attendance.service';

import {
  runOverdueFeeNotifications,
  runAnnouncementExpiry,
  runNotificationDeliveryRetries,
  runPendingPaymentReviewNotifications,
  runScheduledAnnouncementPublishing,
  runSubscriptionExpiryNotifications,
} from './scheduled-jobs.service';

const dailyCoordinatorKey = 'DAILY_NOTIFICATION_COORDINATOR';
const leaseMinutes = 5;

function utcBusinessDate(date = new Date()) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

async function claimDailyRun(jobKey: string, businessDate: Date) {
  const now = new Date();
  const leaseUntil = new Date(now.getTime() + leaseMinutes * 60_000);

  try {
    const run = await prisma.dailyJobRun.create({
      data: { job_key: jobKey, business_date: businessDate, lease_until: leaseUntil },
    });
    return { status: 'CLAIMED' as const, run };
  } catch (error) {
    if ((error as { code?: string }).code !== 'P2002') throw error;
  }

  const existing = await prisma.dailyJobRun.findUnique({
    where: { job_key_business_date: { job_key: jobKey, business_date: businessDate } },
  });
  if (!existing) return { status: 'RETRY' as const };
  if (existing.status === 'COMPLETED') return { status: 'COMPLETED' as const, run: existing };
  if (existing.status === 'RUNNING' && existing.lease_until && existing.lease_until > now) {
    return { status: 'RUNNING' as const, run: existing };
  }

  const reclaimed = await prisma.dailyJobRun.updateMany({
    where: {
      id: existing.id,
      OR: [
        { status: 'FAILED' },
        { status: 'RUNNING', lease_until: { lt: now } },
        { status: 'RUNNING', lease_until: null },
      ],
    },
    data: {
      status: 'RUNNING',
      lease_until: leaseUntil,
      attempt_count: { increment: 1 },
      last_error: null,
      started_at: now,
      completed_at: null,
    },
  });
  if (reclaimed.count === 0) return { status: 'RUNNING' as const, run: existing };
  const run = await prisma.dailyJobRun.findUnique({ where: { id: existing.id } });
  return run ? { status: 'CLAIMED' as const, run } : { status: 'RETRY' as const };
}

export async function runDailyNotificationCoordinator() {
  const businessDate = utcBusinessDate();
  const claim = await claimDailyRun(dailyCoordinatorKey, businessDate);
  if (claim.status !== 'CLAIMED' || !claim.run) {
    return { status: claim.status.toLowerCase(), job: dailyCoordinatorKey };
  }

  try {
    const [
      attendanceReview,
      evidenceRetention,
      subscriptionExpiry,
      overdueFees,
      paymentReviewReminders,
      scheduledAnnouncements,
      expiredAnnouncements,
      deliveryRetries,
    ] = await Promise.all([
      reviewOpenAttendanceSessions(),
      purgeExpiredAttendanceEvidence(),
      runSubscriptionExpiryNotifications(),
      runOverdueFeeNotifications(),
      runPendingPaymentReviewNotifications(),
      runScheduledAnnouncementPublishing(),
      runAnnouncementExpiry(),
      runNotificationDeliveryRetries(),
    ]);
    await prisma.dailyJobRun.update({
      where: { id: claim.run.id },
      data: { status: 'COMPLETED', lease_until: null, completed_at: new Date() },
    });
    return {
      status: 'completed',
      job: dailyCoordinatorKey,
      attendance_review: attendanceReview,
      evidence_retention: evidenceRetention,
      subscription_expiry: subscriptionExpiry,
      overdue_fees: overdueFees,
      payment_review_reminders: paymentReviewReminders,
      scheduled_announcements: scheduledAnnouncements,
      expired_announcements: expiredAnnouncements,
      delivery_retries: deliveryRetries,
    };
  } catch (error) {
    const safeError =
      error instanceof Prisma.PrismaClientKnownRequestError ? error.code : 'JOB_FAILED';
    await prisma.dailyJobRun.update({
      where: { id: claim.run.id },
      data: { status: 'FAILED', lease_until: null, last_error: safeError },
    });
    logger.error('Daily notification coordinator failed', { error: safeError });
    throw error;
  }
}
