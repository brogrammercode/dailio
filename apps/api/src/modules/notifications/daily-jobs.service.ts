import { Prisma } from '@prisma/client';
import { ulid } from 'ulid';

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
import { runMonthlyMemberReports, previousMonthPeriod } from './monthly-reports.service';

const dailyCoordinatorKey = 'DAILY_NOTIFICATION_COORDINATOR';
const leaseMinutes = 5;
let coordinatorInFlight = false;

function utcBusinessDate(date = new Date()) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

async function claimDailyRun(jobKey: string, businessDate: Date) {
  const now = new Date();
  const leaseUntil = new Date(now.getTime() + leaseMinutes * 60_000);

  // The coordinator can be triggered by several app opens at the same time.
  // Claim atomically so a normal cross-process race does not emit a noisy
  // Prisma P2002 error or hold a connection while the loser retries.
  const rawClient = prisma as typeof prisma & {
    $executeRaw?: (query: TemplateStringsArray, ...values: unknown[]) => Promise<number>;
  };
  let inserted: number;
  if (typeof rawClient.$executeRaw === 'function') {
    inserted = await rawClient.$executeRaw`
      INSERT INTO "daily_job_runs"
        ("id", "job_key", "business_date", "status", "lease_until", "attempt_count", "started_at", "updated_at")
      VALUES
        (${ulid()}, ${jobKey}, ${businessDate}, 'RUNNING'::"DailyJobRunStatus", ${leaseUntil}, 1, ${now}, ${now})
      ON CONFLICT ("job_key", "business_date") DO NOTHING
    `;
  } else {
    // Kept for the isolated service tests, whose Prisma stub only models the
    // delegate methods used by the original implementation.
    try {
      const run = await prisma.dailyJobRun.create({
        data: { job_key: jobKey, business_date: businessDate, lease_until: leaseUntil },
      });
      return { status: 'CLAIMED' as const, run };
    } catch (error) {
      if ((error as { code?: string }).code !== 'P2002') throw error;
      inserted = 0;
    }
  }
  if (inserted === 1) {
    const run = await prisma.dailyJobRun.findUnique({
      where: { job_key_business_date: { job_key: jobKey, business_date: businessDate } },
    });
    return run ? { status: 'CLAIMED' as const, run } : { status: 'RETRY' as const };
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
  if (coordinatorInFlight) {
    return { status: 'running', job: dailyCoordinatorKey };
  }
  coordinatorInFlight = true;
  try {
    return await runDailyNotificationCoordinatorInternal();
  } finally {
    coordinatorInFlight = false;
  }
}

async function runDailyNotificationCoordinatorInternal() {
  const businessDate = utcBusinessDate();
  const claim = await claimDailyRun(dailyCoordinatorKey, businessDate);
  if (claim.status !== 'CLAIMED' || !claim.run) {
    return { status: claim.status.toLowerCase(), job: dailyCoordinatorKey };
  }

  const reportPeriod = previousMonthPeriod();
  const reportClaim = await claimDailyRun('MONTHLY_MEMBER_REPORT', reportPeriod.start);

  try {
    // Keep maintenance database pressure bounded. These jobs are triggered by
    // app-open and cron, so running all scans concurrently can starve normal
    // attendance/fees/member requests on small connection pools.
    const attendanceReview = await reviewOpenAttendanceSessions();
    const evidenceRetention = await purgeExpiredAttendanceEvidence();
    const subscriptionExpiry = await runSubscriptionExpiryNotifications();
    const overdueFees = await runOverdueFeeNotifications();
    const paymentReviewReminders = await runPendingPaymentReviewNotifications();
    const scheduledAnnouncements = await runScheduledAnnouncementPublishing();
    const expiredAnnouncements = await runAnnouncementExpiry();
    const deliveryRetries = await runNotificationDeliveryRetries();
    const monthlyMemberReports =
      reportClaim.status === 'CLAIMED'
        ? await runMonthlyMemberReports(reportPeriod)
        : {
            status: reportClaim.status.toLowerCase(),
            branches: 0,
            sent: 0,
            skipped: 0,
          };
    if (reportClaim.status === 'CLAIMED' && reportClaim.run) {
      await prisma.dailyJobRun.update({
        where: { id: reportClaim.run.id },
        data: { status: 'COMPLETED', lease_until: null, completed_at: new Date() },
      });
    }
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
      monthly_member_reports: monthlyMemberReports,
    };
  } catch (error) {
    const safeError =
      error instanceof Prisma.PrismaClientKnownRequestError ? error.code : 'JOB_FAILED';
    await prisma.dailyJobRun.update({
      where: { id: claim.run.id },
      data: { status: 'FAILED', lease_until: null, last_error: safeError },
    });
    if (reportClaim.status === 'CLAIMED' && reportClaim.run) {
      await prisma.dailyJobRun.update({
        where: { id: reportClaim.run.id },
        data: { status: 'FAILED', lease_until: null, last_error: safeError },
      });
    }
    logger.error('Daily notification coordinator failed', { error: safeError });
    throw error;
  }
}
