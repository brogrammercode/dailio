import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';
import { cloudinary } from '../../lib/cloudinary';

import { type EmailAttachment, sendEmail, escapeHtml, isEmailConfigured } from './email.service';
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

/**
 * Fan-out is deliberately bounded. A branch can have hundreds of recipients,
 * while the API commonly runs with a small PostgreSQL pool. Unbounded
 * Promise.all here would make a notification slow down unrelated requests by
 * exhausting every available connection.
 */
async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  worker: (item: T) => Promise<R>,
) {
  const results = new Array<R>(items.length);
  let cursor = 0;
  const run = async () => {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await worker(items[index]);
    }
  };
  await Promise.all(Array.from({ length: Math.min(Math.max(concurrency, 1), items.length) }, run));
  return results;
}

function defaultEmailHtml(event: NotificationEvent, mediaCid?: string) {
  const media = mediaCid
    ? `<div style="margin:20px 0"><img src="cid:${mediaCid}" alt="Related image" style="display:block;width:100%;max-width:560px;height:auto;border-radius:12px" /></div>`
    : '';
  return `<!doctype html><html><body style="font-family:Arial,sans-serif;color:#171717;line-height:1.5"><div style="max-width:600px;margin:0 auto;padding:24px"><div style="font-size:24px;font-weight:700;margin-bottom:24px">Dailio</div><h2>${escapeHtml(event.title)}</h2><p>${escapeHtml(event.body)}</p>${media}<p style="color:#666;font-size:13px">This is an operational notification from Dailio.</p></div></body></html>`;
}

function mediaExtension(storageKey: string) {
  const extension = storageKey.split('.').pop()?.toLowerCase();
  return extension && /^[a-z0-9]{2,5}$/.test(extension) ? extension : 'jpg';
}

async function resolveNotificationMedia(event: NotificationEvent) {
  const storageKey = event.data?.media_storage_key;
  const organizationId = event.organizationId;
  if (!storageKey || !organizationId) return null;

  const expectedPrefix = `organizations/${organizationId}/`;
  if (!storageKey.startsWith(expectedPrefix)) return null;
  if (event.branchId && !storageKey.includes(`/branches/${event.branchId}/`)) return null;

  try {
    const extension = event.data?.media_format?.toLowerCase() ?? mediaExtension(storageKey);
    const url = cloudinary.url(storageKey, {
      resource_type: 'image',
      type: 'authenticated',
      format: extension,
      secure: true,
      sign_url: true,
    });
    const response = await fetch(url, { signal: AbortSignal.timeout(5_000) });
    if (!response.ok) return null;
    const contentLength = Number(response.headers.get('content-length') ?? 0);
    if (contentLength > 5 * 1024 * 1024) return null;
    const bytes = Buffer.from(await response.arrayBuffer());
    if (bytes.length > 5 * 1024 * 1024) return null;
    const contentType = response.headers.get('content-type')?.split(';')[0];
    if (!contentType?.startsWith('image/')) return null;
    return {
      attachment: {
        filename: `dailio-notification.${extension}`,
        content: bytes,
        contentType,
        cid: 'dailio-notification-media',
      } satisfies EmailAttachment,
      cid: 'dailio-notification-media',
    };
  } catch {
    return null;
  }
}

async function emailContent(event: NotificationEvent) {
  const media = await resolveNotificationMedia(event);
  let html = event.emailHtml ?? defaultEmailHtml(event, media?.cid);
  if (event.emailHtml && media?.cid) {
    const image = `<div style="margin:20px 0"><img src="cid:${media.cid}" alt="Related image" style="display:block;width:100%;max-width:560px;height:auto;border-radius:12px" /></div>`;
    html = html.replace('</body>', `${image}</body>`);
  }
  return { html, attachments: media ? [media.attachment] : undefined };
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
    return '/announcements';
  }
  if (event.entityType === 'Feed' || event.type.startsWith('FEED_')) {
    return '/announcements';
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
      const email = await emailContent(event);
      const result = await timeout(
        sendEmail({
          to: user.email,
          subject: event.emailSubject ?? event.title,
          text: event.emailText ?? event.body,
          html: email.html,
          attachments: email.attachments,
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

  let notificationEvent = event;
  if (event.actorUserId) {
    try {
      const actor = await prisma.user.findUnique({
        where: { id: event.actorUserId },
        select: {
          name: true,
          avatar_url: true,
          members: {
            where: {
              organization_id: event.organizationId ?? '',
              ...(event.branchId ? { branch_id: event.branchId } : {}),
            },
            select: { id: true },
            take: 1,
          },
        },
      });
      if (actor) {
        notificationEvent = {
          ...event,
          data: {
            ...(event.data ?? {}),
            actor_name: actor.name,
            ...(actor.avatar_url ? { actor_avatar_url: actor.avatar_url } : {}),
            ...(actor.members?.[0]?.id ? { actor_member_id: actor.members[0].id } : {}),
          },
        };
      }
    } catch {
      // Actor presentation is best-effort and must not block notification delivery.
    }
  }

  // Create every in-app row before external delivery. This guarantees that a
  // slow SMTP/FCM provider cannot delay or prevent the inbox notification for
  // later recipients.
  const notificationRows = await mapWithConcurrency(users, 8, async (user) => {
    const dedupeKey = deliveryDedupeKey(notificationEvent, user.id);
    const notification = await prisma.notification.upsert({
      where: { dedupe_key: dedupeKey },
      create: {
        user_id: user.id,
        organization_id: notificationEvent.organizationId,
        branch_id: notificationEvent.branchId,
        event_type: notificationEvent.type,
        entity_type: notificationEvent.entityType,
        entity_id: notificationEvent.entityId,
        title: notificationEvent.title,
        body: notificationEvent.body,
        channel: 'IN_APP',
        status: 'SENT',
        sent_at: new Date(),
        dedupe_key: dedupeKey,
        data: notificationEvent.data,
      },
      update: {},
    });
    return { notification, user };
  });

  created = notificationRows.length;
  await mapWithConcurrency(notificationRows, 4, ({ notification, user }) =>
    deliverNotification(notificationEvent, notification.id, user),
  );

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

export async function countUnreadNotifications(userId: string) {
  return prisma.notification.count({
    where: { user_id: userId, read_at: null },
  });
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
