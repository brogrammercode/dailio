import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';

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
