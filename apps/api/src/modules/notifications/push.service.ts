import { logger } from '../../config/logger';
import { prisma } from '../../lib/prisma';
import { getFirebaseMessaging } from '../../lib/firebase';

export type PushNotificationInput = {
  userId: string;
  token?: string;
  tokens?: string[];
  title: string;
  body: string;
  data: Record<string, string>;
};

export type PushSendResult = {
  messageId: string;
};

function stringifyData(data: Record<string, unknown>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [
      key,
      typeof value === 'string' ? value : JSON.stringify(value),
    ]),
  );
}

export async function sendPush(input: PushNotificationInput): Promise<PushSendResult | null> {
  const messaging = getFirebaseMessaging();
  if (!messaging) return null;

  try {
    const tokens = [...new Set(input.tokens ?? (input.token ? [input.token] : []))];
    if (tokens.length === 0) return null;
    if (tokens.length === 1) {
      const messageId = await messaging.send({
        token: tokens[0],
        notification: { title: input.title, body: input.body },
        data: stringifyData(input.data),
      });
      return { messageId };
    }

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title: input.title, body: input.body },
      data: stringifyData(input.data),
    });
    const invalidTokens = response.responses
      .map((result, index) =>
        result.error &&
        (result.error as { code?: string }).code &&
        [
          'messaging/registration-token-not-registered',
          'messaging/invalid-registration-token',
        ].includes((result.error as { code: string }).code)
          ? tokens[index]
          : null,
      )
      .filter((token): token is string => token != null);
    if (invalidTokens.length > 0) {
      await prisma.userDeviceToken.deleteMany({ where: { token: { in: invalidTokens } } });
      await prisma.user.updateMany({
        where: { id: input.userId, fcm_token: { in: invalidTokens } },
        data: { fcm_token: null },
      });
    }
    if (response.successCount === 0) {
      const firstError = response.responses.find((result) => result.error)?.error;
      throw firstError ?? new Error('FCM_MULTICAST_FAILED');
    }
    return {
      messageId: `multicast:${response.successCount}/${response.responses.length}`,
    };
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      const tokens = [...new Set(input.tokens ?? (input.token ? [input.token] : []))];
      await prisma.userDeviceToken.deleteMany({ where: { token: { in: tokens } } });
      await prisma.user.updateMany({
        where: { id: input.userId, fcm_token: { in: tokens } },
        data: { fcm_token: null },
      });
      logger.info('Removed invalid FCM token', { user_id: input.userId });
    }
    throw error;
  }
}
