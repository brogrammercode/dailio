import { beforeEach, describe, expect, it, vi } from 'vitest';

const messagingMock = vi.hoisted(() => ({
  send: vi.fn(),
  sendEachForMulticast: vi.fn(),
}));
const prismaMock = vi.hoisted(() => ({
  userDeviceToken: { deleteMany: vi.fn() },
  user: { updateMany: vi.fn() },
}));

vi.mock('../../lib/firebase', () => ({
  getFirebaseMessaging: () => messagingMock,
}));
vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));
vi.mock('../../config/logger', () => ({ logger: { info: vi.fn() } }));

import { sendPush } from './push.service';

describe('FCM push delivery', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    messagingMock.send.mockResolvedValue('message-a');
    messagingMock.sendEachForMulticast.mockResolvedValue({
      successCount: 2,
      failureCount: 0,
      responses: [{ success: true }, { success: true }],
    });
  });

  it('sends to every registered device and removes invalid multicast tokens', async () => {
    messagingMock.sendEachForMulticast.mockResolvedValue({
      successCount: 1,
      failureCount: 1,
      responses: [
        { success: true },
        { error: { code: 'messaging/registration-token-not-registered' } },
      ],
    });

    await expect(
      sendPush({
        userId: 'user-a',
        tokens: ['token-a', 'token-b'],
        title: 'Dailio',
        body: 'Test',
        data: { type: 'TEST' },
      }),
    ).resolves.toEqual({ messageId: 'multicast:1/2' });

    expect(messagingMock.sendEachForMulticast).toHaveBeenCalledOnce();
    expect(prismaMock.userDeviceToken.deleteMany).toHaveBeenCalledWith({
      where: { token: { in: ['token-b'] } },
    });
    expect(prismaMock.user.updateMany).toHaveBeenCalledWith({
      where: { id: 'user-a', fcm_token: { in: ['token-b'] } },
      data: { fcm_token: null },
    });
  });

  it('cleans an invalid single device token without failing cleanup', async () => {
    messagingMock.send.mockRejectedValue({
      code: 'messaging/invalid-registration-token',
    });

    await expect(
      sendPush({
        userId: 'user-a',
        token: 'token-a',
        title: 'Dailio',
        body: 'Test',
        data: { type: 'TEST' },
      }),
    ).rejects.toMatchObject({ code: 'messaging/invalid-registration-token' });

    expect(prismaMock.userDeviceToken.deleteMany).toHaveBeenCalledWith({
      where: { token: { in: ['token-a'] } },
    });
  });
});
