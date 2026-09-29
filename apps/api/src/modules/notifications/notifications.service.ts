import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';

import { sendEmail, escapeHtml, isEmailConfigured } from './email.service';
import { sendPush } from './push.service';

export type NotificationEvent = {
  type: string;
  organizationId?: string;
  branchId?: string;
  actorUserId?: string;
  entityType?: string;
  entityId?: string;
  recipientUserIds: string[];
  title: string;
  body: string;
  emailSubject?: string;
  emailText?: string;
  emailHtml?: string;
  data?: Record<string, string>;
  dedupeKey: string;
  channels?: Array<'PUSH' | 'EMAIL'>;
};

type BranchRecipientRole = {
  system_key: string | null;
  permissions: string[];
};

/**
 * Resolve recipients from active branch memberships, never from client input.
 * The same resolver is used by business modules that need permission-scoped
 * notifications such as payment review and admission review.
 */
export async function findBranchRecipientUserIds(
  organizationId: string,
  branchId: string,
  permission: string,
) {
  const members = await prisma.member.findMany({
    where: { organization_id: organizationId, branch_id: branchId, status: 'ACTIVE' },
    select: {
      user_id: true,
      role: { select: { system_key: true, permissions: true } },
      role_assignments: {
        where: {
          organization_id: organizationId,
          branch_id: branchId,
          effective_from: { lte: new Date() },
          OR: [{ effective_to: null }, { effective_to: { gt: new Date() } }],
        },
        select: { role: { select: { system_key: true, permissions: true } } },
      },
    },
  });

  return members
    .filter((member) => {
      const roles: BranchRecipientRole[] = [
        member.role,
        ...member.role_assignments.map((assignment) => assignment.role),
      ].filter((role): role is BranchRecipientRole => role != null);
      return roles.some(
        (role) => role.system_key === 'OWNER' || role.permissions.includes(permission),
      );
    })
    .map((member) => member.user_id);
}

const deliveryTimeoutMs = 10_000;

function timeout<T>(promise: Promise<T>, ms: number) {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) => {
      const timer = setTimeout(() => reject(new Error('DELIVERY_TIMEOUT')), ms);
      timer.unref?.();
    }),
  ]);
}

function deliveryDedupeKey(event: NotificationEvent, userId: string) {
  return `${event.dedupeKey}:user:${userId}`;
}

function defaultEmailHtml(event: NotificationEvent) {
  return `<!doctype html><html><body style="font-family:Arial,sans-serif;color:#171717;line-height:1.5"><div style="max-width:600px;margin:0 auto;padding:24px"><div style="font-size:24px;font-weight:700;margin-bottom:24px">Dailio</div><h2>${escapeHtml(event.title)}</h2><p>${escapeHtml(event.body)}</p><p style="color:#666;font-size:13px">This is an operational notification from Dailio.</p></div></body></html>`;
}

function defaultRoute(event: NotificationEvent) {
  if (!event.entityId) return undefined;
  if (event.type.startsWith('ATTENDANCE_') || event.entityType === 'AttendanceSession') {
    return `/home/attendance/${event.entityId}`;
  }
  if (event.type.startsWith('SUBSCRIPTION_') || event.entityType === 'Subscription') {
    return `/home/fees/${event.entityId}`;
  }
  if (event.type.startsWith('PAYMENT_') || event.type === 'RECEIPT_GENERATED') {
    return '/home/fees';
  }
  if (event.entityType === 'Announcement' || event.type.startsWith('ANNOUNCEMENT_')) {
    return '/home/notifications';
  }
  if (event.entityType === 'LeaveRequest' || event.type.startsWith('LEAVE_')) {
    return '/home/attendance';
  }
  if (event.entityType === 'Member') return `/home/branch/members/${event.entityId}`;
  if (event.entityType === 'Role') return '/home/branch/roles';
  if (event.entityType === 'Shift') return '/home/branch/shift-management';
  return undefined;
}

async function markDelivery(
  deliveryId: string,
  status: 'SENT' | 'FAILED' | 'SKIPPED',
  details: { providerMessageId?: string; errorCode?: string } = {},
) {
  const now = new Date();
  await prisma.notificationDelivery.update({
    where: { id: deliveryId },
    data: {
      status,
      attempt_count: { increment: 1 },
      last_attempt_at: now,
      delivered_at: status === 'SENT' ? now : null,
      provider_message_id: details.providerMessageId,
      last_error_code: details.errorCode,
    },
  });
}

type NotificationUser = {
  id: string;
  email: string | null;
  fcm_token: string | null;
  device_tokens: Array<{ token: string }>;
  notification_preferences: Array<{
    event_type: string;
    channel: 'PUSH' | 'EMAIL';
    enabled: boolean;
  }>;
};

async function deliverNotification(
  event: NotificationEvent,
  notificationId: string,
  user: NotificationUser,
) {
  const channels = event.channels ?? ['PUSH', 'EMAIL'];
  const data = {
    ...(event.data ?? {}),
    ...(event.data?.route || !defaultRoute(event) ? {} : { route: defaultRoute(event) }),
    type: event.type,
  };

  for (const channel of channels) {
    const delivery = await prisma.notificationDelivery.upsert({
      where: {
        notification_id_channel_user_id: {
          notification_id: notificationId,
          channel,
          user_id: user.id,
        },
      },
      create: {
        notification_id: notificationId,
        user_id: user.id,
        channel,
        status: 'PENDING',
      },
      update: {},
    });

    if (delivery.status === 'SENT' || delivery.status === 'SKIPPED') continue;

    const preference = user.notification_preferences.find(
      (item) => item.event_type === event.type && item.channel === channel,
    );
    if (preference?.enabled === false) {
      await markDelivery(delivery.id, 'SKIPPED', { errorCode: 'PREFERENCE_DISABLED' });
      continue;
    }

    if (channel === 'PUSH') {
      const tokens = [
        ...new Set(
          [user.fcm_token, ...user.device_tokens.map((device) => device.token)].filter(Boolean),
        ),
      ] as string[];
      if (tokens.length === 0) {
        await markDelivery(delivery.id, 'SKIPPED', { errorCode: 'NO_FCM_TOKEN' });
        continue;
      }
      try {
        const result = await timeout(
          sendPush({
            userId: user.id,
            tokens,
            title: event.title,
            body: event.body,
            data,
          }),
          deliveryTimeoutMs,
        );
        if (!result) {
          await markDelivery(delivery.id, 'SKIPPED', { errorCode: 'FCM_NOT_CONFIGURED' });
        } else {
          await markDelivery(delivery.id, 'SENT', { providerMessageId: result.messageId });
        }
      } catch (error) {
        await markDelivery(delivery.id, 'FAILED', {
          errorCode: (error as { code?: string }).code ?? (error as Error).message,
        });
      }
      continue;
    }

    if (!user.email) {
      await markDelivery(delivery.id, 'SKIPPED', { errorCode: 'NO_EMAIL' });
      continue;
    }
    if (!isEmailConfigured()) {
      await markDelivery(delivery.id, 'SKIPPED', { errorCode: 'EMAIL_NOT_CONFIGURED' });
      continue;
    }
    try {
      const result = await timeout(
        sendEmail({
          to: user.email,
          subject: event.emailSubject ?? event.title,
          text: event.emailText ?? event.body,
          html: event.emailHtml ?? defaultEmailHtml(event),
        }),
        deliveryTimeoutMs,
      );
      if (!result) {
        await markDelivery(delivery.id, 'SKIPPED', { errorCode: 'EMAIL_NOT_CONFIGURED' });
      } else {
        await markDelivery(delivery.id, 'SENT', { providerMessageId: result.messageId });
      }
    } catch (error) {
      await markDelivery(delivery.id, 'FAILED', {
        errorCode: (error as { code?: string }).code ?? (error as Error).message,
      });
    }
  }
}

export async function retryFailedNotificationDeliveries(now = new Date(), limit = 100) {
  const retryBefore = new Date(now.getTime() - 15 * 60_000);
  const deliveries = await prisma.notificationDelivery.findMany({
    where: {
      status: 'FAILED',
      attempt_count: { lt: 3 },
      OR: [{ last_attempt_at: null }, { last_attempt_at: { lt: retryBefore } }],
    },
    take: limit,
    orderBy: { last_attempt_at: 'asc' },
    include: {
      notification: {
        select: {
          id: true,
          event_type: true,
          organization_id: true,
          branch_id: true,
          entity_type: true,
          entity_id: true,
          title: true,
          body: true,
          data: true,
          dedupe_key: true,
        },
      },
      user: {
        select: {
          id: true,
          email: true,
          fcm_token: true,
          status: true,
          device_tokens: { select: { token: true } },
          notification_preferences: {
            select: { event_type: true, channel: true, enabled: true },
          },
        },
      },
    },
  });

  let retried = 0;
  for (const delivery of deliveries) {
    if (delivery.user.status !== 'ACTIVE') continue;
    await deliverNotification(
      {
        type: delivery.notification.event_type ?? 'NOTIFICATION',
        organizationId: delivery.notification.organization_id ?? undefined,
        branchId: delivery.notification.branch_id ?? undefined,
        entityType: delivery.notification.entity_type ?? undefined,
        entityId: delivery.notification.entity_id ?? undefined,
        recipientUserIds: [delivery.user.id],
        title: delivery.notification.title,
        body: delivery.notification.body,
        data:
          delivery.notification.data && typeof delivery.notification.data === 'object'
            ? (delivery.notification.data as Record<string, string>)
            : undefined,
        dedupeKey: delivery.notification.dedupe_key ?? delivery.notification.id,
        channels: [delivery.channel as 'PUSH' | 'EMAIL'],
      },
      delivery.notification.id,
      delivery.user,
    );
    retried += 1;
  }
  return { scanned: deliveries.length, retried };
}

export async function notify(event: NotificationEvent) {
  const uniqueRecipientIds = [...new Set(event.recipientUserIds)];
  if (uniqueRecipientIds.length === 0) return { created: 0, skipped: 0 };

  const users = await prisma.user.findMany({
    where: { id: { in: uniqueRecipientIds }, status: 'ACTIVE' },
    select: {
      id: true,
      email: true,
      fcm_token: true,
      device_tokens: { select: { token: true } },
      notification_preferences: {
        select: { event_type: true, channel: true, enabled: true },
      },
    },
  });
  let created = 0;
  let skipped = 0;

  for (const user of users) {
    const dedupeKey = deliveryDedupeKey(event, user.id);
    const notification = await prisma.notification.upsert({
      where: { dedupe_key: dedupeKey },
      create: {
        user_id: user.id,
        organization_id: event.organizationId,
        branch_id: event.branchId,
        event_type: event.type,
        entity_type: event.entityType,
        entity_id: event.entityId,
        title: event.title,
        body: event.body,
        channel: 'IN_APP',
        status: 'SENT',
        sent_at: new Date(),
        dedupe_key: dedupeKey,
        data: event.data,
      },
      update: {},
    });

    created += 1;
    await deliverNotification(event, notification.id, user);
  }

  skipped = uniqueRecipientIds.length - users.length;
  return { created, skipped };
}

export async function listNotifications(
  userId: string,
  options: { unreadOnly?: boolean; limit: number; cursor?: string },
) {
  const cursorNotification = options.cursor
    ? await prisma.notification.findFirst({
        where: { id: options.cursor, user_id: userId },
        select: { id: true, created_at: true },
      })
    : null;
  const notifications = await prisma.notification.findMany({
    where: {
      user_id: userId,
      ...(options.unreadOnly ? { read_at: null } : {}),
      ...(cursorNotification
        ? {
            OR: [
              { created_at: { lt: cursorNotification.created_at } },
              { created_at: cursorNotification.created_at, id: { lt: cursorNotification.id } },
            ],
          }
        : {}),
    },
    orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
    take: options.limit + 1,
  });
  const hasMore = notifications.length > options.limit;
  const data = hasMore ? notifications.slice(0, options.limit) : notifications;
  return {
    data,
    next_cursor: hasMore && data.length > 0 ? data[data.length - 1].id : null,
  };
}

export async function markNotificationRead(userId: string, notificationId: string) {
  const readAt = new Date();
  const notification = await prisma.notification.updateMany({
    where: { id: notificationId, user_id: userId, read_at: null },
    data: { read_at: readAt },
  });
  if (notification.count > 0) return { id: notificationId, read_at: readAt.toISOString() };

  const exists = await prisma.notification.findFirst({
    where: { id: notificationId, user_id: userId },
    select: { id: true, read_at: true },
  });
  if (!exists) throw new NotFoundError('Notification');
  return { id: notificationId, read_at: exists.read_at?.toISOString() ?? readAt.toISOString() };
}

export async function markAllNotificationsRead(userId: string) {
  const result = await prisma.notification.updateMany({
    where: { user_id: userId, read_at: null },
    data: { read_at: new Date() },
  });
  return { updated: result.count };
}

export async function listNotificationPreferences(userId: string) {
  return prisma.notificationPreference.findMany({
    where: { user_id: userId },
    orderBy: [{ event_type: 'asc' }, { channel: 'asc' }],
  });
}

export async function setNotificationPreference(input: {
  userId: string;
  eventType: string;
  channel: 'PUSH' | 'EMAIL';
  enabled: boolean;
}) {
  return prisma.notificationPreference.upsert({
    where: {
      user_id_event_type_channel: {
        user_id: input.userId,
        event_type: input.eventType,
        channel: input.channel,
      },
    },
    create: {
      user_id: input.userId,
      event_type: input.eventType,
      channel: input.channel,
      enabled: input.enabled,
    },
    update: { enabled: input.enabled },
  });
}
