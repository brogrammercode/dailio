import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  user: { findMany: vi.fn(), findUnique: vi.fn() },
  notification: { upsert: vi.fn() },
  attendanceSession: { findFirst: vi.fn() },
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
  const reminder = {
    type: 'ATTENDANCE_MISSING_CLOCK_OUT',
    organizationId: 'org-a',
    branchId: 'branch-a',
    entityId: 'session-a',
    recipientUserIds: ['user-a'],
    title: 'Clock-out reminder',
    body: 'Open session',
    dedupeKey: 'reminder-a',
  };

  it('suppresses resolved, inactive, or cross-tenant reminder targets before inbox creation', async () => {
    prismaMock.user.findMany.mockResolvedValue([{ id: 'user-a' }]);
    prismaMock.attendanceSession.findFirst.mockResolvedValue(null);
    expect(await notify(reminder)).toEqual({ created: 0, skipped: 1 });
    expect(prismaMock.notification.upsert).not.toHaveBeenCalled();
    expect(prismaMock.attendanceSession.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organization_id: 'org-a',
          branch_id: 'branch-a',
          state: 'OPEN',
          clock_out_at: null,
          member: {
            user_id: 'user-a',
            status: 'ACTIVE',
            organization_id: 'org-a',
            branch_id: 'branch-a',
          },
        }),
      }),
    );
  });

  it('rejects non-finite policy durations instead of issuing false reminders', async () => {
    prismaMock.attendanceSession.findFirst.mockResolvedValue({
      clock_in_at: new Date(0),
      policy_snapshot: { max_open_session_hours: 'invalid' },
    });
    expect(await notify(reminder)).toEqual({ created: 0, skipped: 1 });
    expect(sendPushMock).not.toHaveBeenCalled();
  });

  it('revalidates the session before external delivery after the inbox record is created', async () => {
    prismaMock.attendanceSession.findFirst
      .mockResolvedValueOnce({ clock_in_at: new Date(0), policy_snapshot: null })
      .mockResolvedValue(null);
    await notify(reminder);
    expect(sendPushMock).not.toHaveBeenCalled();
    expect(sendEmailMock).not.toHaveBeenCalled();
    expect(prismaMock.notificationDelivery.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ last_error_code: 'ATTENDANCE_REMINDER_RESOLVED' }),
      }),
    );
  });
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

  it('still delivers a genuinely overdue active session', async () => {
    prismaMock.attendanceSession.findFirst.mockResolvedValue({
      clock_in_at: new Date(0),
      policy_snapshot: { max_open_session_hours: 24 },
    });
    await notify(reminder);
    expect(sendPushMock).toHaveBeenCalledOnce();
  });

  it('does not replay a stale reminder when a device token is registered later', async () => {
    prismaMock.attendanceSession.findFirst.mockResolvedValue(null);
    prismaMock.notificationDelivery.findMany.mockResolvedValue([
      {
        id: 'old-delivery',
        status: 'SKIPPED',
        channel: 'PUSH',
        notification: {
          id: 'old-reminder',
          event_type: reminder.type,
          organization_id: 'org-a',
          branch_id: 'branch-a',
          entity_id: 'session-a',
          title: reminder.title,
          body: reminder.body,
          data: {},
          dedupe_key: 'old-key',
        },
        user: {
          id: 'user-a',
          status: 'ACTIVE',
          fcm_token: 'token-a',
          device_tokens: [],
          notification_preferences: [],
        },
      },
    ]);
    await retryPendingPushDeliveriesForUser('user-a');
    expect(sendPushMock).not.toHaveBeenCalled();
    expect(prismaMock.notificationDelivery.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ last_error_code: 'ATTENDANCE_REMINDER_RESOLVED' }),
      }),
    );
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
