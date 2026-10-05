import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  user: { findMany: vi.fn(), findUnique: vi.fn() },
  notification: { upsert: vi.fn() },
  notificationDelivery: { findMany: vi.fn(), upsert: vi.fn(), update: vi.fn() },
}));

const sendPushMock = vi.hoisted(() => vi.fn());
const sendEmailMock = vi.hoisted(() => vi.fn());
const emailConfiguredMock = vi.hoisted(() => vi.fn());

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));
vi.mock('./push.service', () => ({ sendPush: sendPushMock }));
vi.mock('./email.service', () => ({
  sendEmail: sendEmailMock,
  escapeHtml: (value: string) => value,
  isEmailConfigured: emailConfiguredMock,
}));

import { notify, retryPendingPushDeliveriesForUser } from './notifications.service';

describe('central notification delivery', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    prismaMock.user.findMany.mockResolvedValue([
      {
        id: 'user-a',
        email: 'a@example.com',
        fcm_token: 'token-a',
        device_tokens: [],
        notification_preferences: [],
      },
    ]);
    prismaMock.notification.upsert.mockResolvedValue({ id: 'notification-a' });
    prismaMock.notificationDelivery.upsert.mockResolvedValue({
      id: 'delivery-a',
      status: 'PENDING',
    });
    prismaMock.notificationDelivery.update.mockResolvedValue({});
    prismaMock.notificationDelivery.findMany.mockResolvedValue([]);
    sendPushMock.mockResolvedValue({ messageId: 'push-message-a' });
    sendEmailMock.mockResolvedValue({ messageId: 'email-message-a' });
    emailConfiguredMock.mockReturnValue(true);
    prismaMock.user.findUnique.mockResolvedValue(null);
  });

  it('creates one in-app record and one delivery per enabled channel', async () => {
    const result = await notify({
      type: 'PAYMENT_RECEIVED',
      organizationId: 'org-a',
      branchId: 'branch-a',
      entityType: 'PaymentAttempt',
      entityId: 'payment-a',
      recipientUserIds: ['user-a', 'user-a'],
      title: 'Payment received',
      body: 'Your payment was received.',
      data: { route: '/home/fees', entity_id: 'payment-a' },
      dedupeKey: 'payment-a:received',
    });

    expect(result).toEqual({ created: 1, skipped: 0 });
    expect(prismaMock.notification.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { dedupe_key: 'payment-a:received:user:user-a' },
      }),
    );
    expect(sendPushMock).toHaveBeenCalledOnce();
    expect(sendEmailMock).toHaveBeenCalledOnce();
    expect(prismaMock.notificationDelivery.update).toHaveBeenCalledTimes(2);
  });

  it('records unavailable channels as skipped instead of failing the business command', async () => {
    prismaMock.user.findMany.mockResolvedValue([
      {
        id: 'user-a',
        email: null,
        fcm_token: null,
        device_tokens: [],
        notification_preferences: [],
      },
    ]);

    await notify({
      type: 'ANNOUNCEMENT_PUBLISHED',
      recipientUserIds: ['user-a'],
      title: 'Announcement',
      body: 'New announcement',
      dedupeKey: 'announcement-a',
    });

    expect(sendPushMock).not.toHaveBeenCalled();
    expect(sendEmailMock).not.toHaveBeenCalled();
    expect(prismaMock.notificationDelivery.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'SKIPPED' }) }),
    );
  });

  it('embeds safe actor display data for the in-app notification', async () => {
    prismaMock.user.findUnique.mockResolvedValue({
      name: 'Harsh Sharma',
      avatar_url: 'https://example.com/avatar.png',
    });

    await notify({
      type: 'ANNOUNCEMENT_COMMENTED',
      actorUserId: 'actor-a',
      recipientUserIds: ['user-a'],
      title: 'New comment',
      body: 'Someone commented on your announcement.',
      dedupeKey: 'announcement-a:comment:actor-a',
    });

    expect(prismaMock.notification.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({
          data: {
            actor_name: 'Harsh Sharma',
            actor_avatar_url: 'https://example.com/avatar.png',
          },
        }),
      }),
    );
    const createData = prismaMock.notification.upsert.mock.calls[0][0].create;
    expect(createData).not.toHaveProperty('actor_id');
  });

  it('honours a user channel preference without suppressing the inbox record', async () => {
    prismaMock.user.findMany.mockResolvedValue([
      {
        id: 'user-a',
        email: 'a@example.com',
        fcm_token: 'token-a',
        device_tokens: [],
        notification_preferences: [
          { event_type: 'PAYMENT_RECEIVED', channel: 'EMAIL', enabled: false },
        ],
      },
    ]);

    const result = await notify({
      type: 'PAYMENT_RECEIVED',
      recipientUserIds: ['user-a'],
      title: 'Payment received',
      body: 'Your payment was received.',
      dedupeKey: 'payment-a:preference-test',
    });

    expect(result.created).toBe(1);
    expect(sendPushMock).toHaveBeenCalledOnce();
    expect(sendEmailMock).not.toHaveBeenCalled();
    expect(prismaMock.notificationDelivery.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: 'SKIPPED',
          last_error_code: 'PREFERENCE_DISABLED',
        }),
      }),
    );
  });

  it('replays recent no-token push deliveries after a device registers', async () => {
    prismaMock.notificationDelivery.findMany.mockResolvedValue([
      {
        id: 'delivery-a',
        status: 'SKIPPED',
        notification: {
          id: 'notification-a',
          event_type: 'MEAL_SERVING_CONFIRMED',
          organization_id: 'org-a',
          branch_id: 'branch-a',
          entity_type: 'MealServing',
          entity_id: 'serving-a',
          title: 'Meal attendance recorded',
          body: 'Breakfast attendance was recorded.',
          data: { route: '/home/attendance' },
          dedupe_key: 'meal-serving:serving-a:confirmed:user:user-a',
        },
        user: {
          id: 'user-a',
          email: null,
          fcm_token: 'token-a',
          status: 'ACTIVE',
          device_tokens: [],
          notification_preferences: [],
        },
      },
    ]);

    const result = await retryPendingPushDeliveriesForUser('user-a');

    expect(result).toEqual({ scanned: 1, retried: 1 });
    expect(prismaMock.notificationDelivery.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'PENDING', last_error_code: null } }),
    );
    expect(sendPushMock).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'user-a', tokens: ['token-a'] }),
    );
  });
});
