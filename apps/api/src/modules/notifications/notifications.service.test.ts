import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  notification: {
    count: vi.fn(),
    findFirst: vi.fn(),
    findMany: vi.fn(),
    updateMany: vi.fn(),
  },
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import {
  countUnreadNotifications,
  listNotifications,
  markNotificationRead,
} from './notifications.service';

describe('notification privacy and idempotent read actions', () => {
  beforeEach(() => vi.clearAllMocks());

  it('always scopes inbox queries to the authenticated user', async () => {
    prismaMock.notification.findMany.mockResolvedValue([]);

    await listNotifications('user-a', { limit: 20 });

    expect(prismaMock.notification.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ user_id: 'user-a' }) }),
    );
  });

  it("does not allow marking another user's notification as read", async () => {
    prismaMock.notification.updateMany.mockResolvedValue({ count: 0 });
    prismaMock.notification.findFirst.mockResolvedValue(null);

    await expect(markNotificationRead('user-a', 'notification-b')).rejects.toThrow(
      'Notification not found',
    );

    expect(prismaMock.notification.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'notification-b', user_id: 'user-a', read_at: null },
      }),
    );
  });

  it('counts unread notifications only for the authenticated user', async () => {
    prismaMock.notification.count.mockResolvedValue(5);

    await expect(countUnreadNotifications('user-a')).resolves.toBe(5);
    expect(prismaMock.notification.count).toHaveBeenCalledWith({
      where: { user_id: 'user-a', read_at: null },
    });
  });
});
