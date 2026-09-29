import { prisma } from '../../lib/prisma';
import { expireAnnouncements, publishDueAnnouncements } from '../announcements/announcements.service';

import {
  findBranchRecipientUserIds,
  notify,
  retryFailedNotificationDeliveries,
} from './notifications.service';

function dayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function localDate(value: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const get = (type: string) => parts.find((part) => part.type === type)?.value ?? '00';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function localDaysUntil(end: Date, now: Date, timezone: string) {
  const endDate = Date.parse(`${localDate(end, timezone)}T00:00:00.000Z`);
  const today = Date.parse(`${localDate(now, timezone)}T00:00:00.000Z`);
  return Math.ceil((endDate - today) / 86_400_000);
}

export async function runSubscriptionExpiryNotifications(now = new Date()) {
  const reminderLimit = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const subscriptions = await prisma.subscription.findMany({
    where: {
      status: { in: ['ACTIVE', 'EXPIRED'] },
      end_date: { lte: reminderLimit },
    },
    select: {
      id: true,
      organization_id: true,
      branch_id: true,
      end_date: true,
      status: true,
      member: { select: { user_id: true } },
      branch: { select: { timezone: true } },
    },
    take: 1000,
    orderBy: { end_date: 'asc' },
  });

  let notified = 0;
  for (const subscription of subscriptions) {
    if (!subscription.member) continue;
    const timezone = subscription.branch.timezone;
    const daysLeft = localDaysUntil(subscription.end_date, now, timezone);
    const expired = daysLeft < 0 || subscription.end_date <= now;
    if (expired && subscription.status === 'ACTIVE') {
      await prisma.subscription.updateMany({
        where: { id: subscription.id, status: 'ACTIVE', end_date: { lte: now } },
        data: { status: 'EXPIRED' },
      });
    }
    await notify({
      type: expired ? 'SUBSCRIPTION_EXPIRED' : 'SUBSCRIPTION_EXPIRING',
      organizationId: subscription.organization_id,
      branchId: subscription.branch_id,
      entityType: 'Subscription',
      entityId: subscription.id,
      recipientUserIds: [subscription.member.user_id],
      title: expired ? 'Subscription expired' : 'Subscription expiring soon',
      body: expired
        ? 'Your subscription has expired. Renew your plan to continue access.'
        : `Your subscription expires in ${daysLeft} day${daysLeft === 1 ? '' : 's'}.`,
      data: {
        organization_id: subscription.organization_id,
        branch_id: subscription.branch_id,
        entity_id: subscription.id,
      },
      dedupeKey: expired
        ? `subscription:${subscription.id}:expired`
        : `subscription:${subscription.id}:expiring:${dayKey(now)}`,
    });
    notified += 1;
  }
  return { scanned: subscriptions.length, notified };
}

export async function runOverdueFeeNotifications(now = new Date()) {
  const entries = await prisma.ledgerEntry.findMany({
    where: {
      amount_minor_unit: { gt: 0 },
      due_date: { lte: now },
      member: { status: 'ACTIVE' },
    },
    select: {
      id: true,
      organization_id: true,
      branch_id: true,
      member_id: true,
      member: { select: { user_id: true } },
      branch: { select: { timezone: true } },
    },
    take: 1000,
    orderBy: { due_date: 'asc' },
  });

  let notified = 0;
  for (const entry of entries) {
    if (!entry.member) continue;
    await notify({
      type: 'FEE_OVERDUE',
      organizationId: entry.organization_id,
      branchId: entry.branch_id,
      entityType: 'LedgerEntry',
      entityId: entry.id,
      recipientUserIds: [entry.member.user_id],
      title: 'Payment due',
      body: 'You have an outstanding fee that needs attention.',
      data: {
        organization_id: entry.organization_id,
        branch_id: entry.branch_id,
        entity_id: entry.id,
      },
      dedupeKey: `ledger-entry:${entry.id}:overdue:${dayKey(now)}`,
    });
    const reviewers = await findBranchRecipientUserIds(
      entry.organization_id,
      entry.branch_id,
      'PAYMENT_READ_ALL',
    );
    await notify({
      type: 'FEE_OVERDUE_REVIEW',
      organizationId: entry.organization_id,
      branchId: entry.branch_id,
      entityType: 'LedgerEntry',
      entityId: entry.id,
      recipientUserIds: reviewers,
      title: 'Overdue fee requires attention',
      body: 'A member has an outstanding fee past its due date.',
      data: {
        organization_id: entry.organization_id,
        branch_id: entry.branch_id,
        entity_id: entry.id,
      },
      dedupeKey: `ledger-entry:${entry.id}:overdue-review:${dayKey(now)}`,
    });
    notified += 1;
  }
  return { scanned: entries.length, notified };
}

export async function runNotificationDeliveryRetries(now = new Date()) {
  return retryFailedNotificationDeliveries(now, 100);
}

export async function runPendingPaymentReviewNotifications(now = new Date()) {
  const staleBefore = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const requests = await prisma.paymentRequest.findMany({
    where: {
      status: { in: ['REQUESTED', 'NEEDS_INFORMATION'] },
      created_at: { lte: staleBefore },
    },
    take: 500,
    select: {
      id: true,
      organization_id: true,
      branch_id: true,
      status: true,
    },
  });
  let notified = 0;
  for (const request of requests) {
    const reviewers = await findBranchRecipientUserIds(
      request.organization_id,
      request.branch_id,
      'PAYMENT_REQUEST_REVIEW',
    );
    await notify({
      type: 'PAYMENT_REVIEW_REMINDER',
      organizationId: request.organization_id,
      branchId: request.branch_id,
      entityType: 'PaymentRequest',
      entityId: request.id,
      recipientUserIds: reviewers,
      title: 'Payment review pending',
      body: 'A payment request has been waiting for review for more than 24 hours.',
      data: {
        organization_id: request.organization_id,
        branch_id: request.branch_id,
        entity_id: request.id,
      },
      dedupeKey: `payment-request:${request.id}:review-reminder:${dayKey(now)}`,
    });
    notified += 1;
  }
  return { scanned: requests.length, notified };
}

export async function runScheduledAnnouncementPublishing(now = new Date()) {
  return publishDueAnnouncements(now);
}

export async function runAnnouncementExpiry(now = new Date()) {
  return expireAnnouncements(now);
}
