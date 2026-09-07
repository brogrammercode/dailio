import { OAuth2Client } from 'google-auth-library';
import { ulid } from 'ulid';

import { env } from '../../config/env';
import { ConflictError, UnauthorizedError } from '../../lib/errors';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from '../../lib/jwt';
import { prisma } from '../../lib/prisma';

const googleClient = new OAuth2Client(env.GOOGLE_CLIENT_ID);

export async function signInWithGoogle(idToken: string) {
  // Verify the Google ID token
  const audiences = [env.GOOGLE_CLIENT_ID];
  if (env.GOOGLE_SERVER_CLIENT_ID) audiences.push(env.GOOGLE_SERVER_CLIENT_ID);

  const ticket = await googleClient.verifyIdToken({
    idToken,
    audience: audiences,
  });
  const payload = ticket.getPayload();
  if (!payload || !payload.sub) {
    throw new UnauthorizedError('Invalid Google token');
  }

  const { sub: provider_sub, email, name, picture } = payload;

  // Upsert user — idempotent
  let authIdentity = await prisma.authIdentity.findUnique({
    where: { provider_provider_sub: { provider: 'google', provider_sub } },
    include: { user: true },
  });

  let user = authIdentity?.user;

  if (!authIdentity) {
    // Check email collision with a different provider
    if (email) {
      const existingUser = await prisma.user.findUnique({ where: { email } });
      if (existingUser) {
        // Link Google identity to existing account
        authIdentity = await prisma.authIdentity.create({
          data: {
            id: ulid(),
            provider: 'google',
            provider_sub,
            email,
            user_id: existingUser.id,
          },
          include: { user: true },
        });
        user = authIdentity.user;
      } else {
        // Create new user + identity atomically
        const newUserId = ulid();
        await prisma.$transaction(async (tx) => {
          user = await tx.user.create({
            data: {
              id: newUserId,
              name: name ?? email ?? 'User',
              email,
              avatar_url: picture,
            },
          });
          await tx.authIdentity.create({
            data: {
              id: ulid(),
              provider: 'google',
              provider_sub,
              email,
              user_id: newUserId,
            },
          });
        });
      }
    } else {
      throw new ConflictError('Google account has no email');
    }
  }

  if (!user) throw new UnauthorizedError('User creation failed');
  if (user.status !== 'ACTIVE') throw new UnauthorizedError('Account is disabled');

  const accessToken = await signAccessToken(user.id);
  const jti = ulid();
  const refreshToken = await signRefreshToken(user.id, jti);

  return { accessToken, refreshToken, user };
}

export async function refreshTokens(refreshToken: string) {
  const payload = await verifyRefreshToken(refreshToken).catch(() => {
    throw new UnauthorizedError('Invalid or expired refresh token');
  });

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user || user.status !== 'ACTIVE') throw new UnauthorizedError('User not found or disabled');

  const accessToken = await signAccessToken(user.id);
  const jti = ulid();
  const newRefreshToken = await signRefreshToken(user.id, jti);

  return { accessToken, refreshToken: newRefreshToken, user };
}

export async function getMe(user_id: string) {
  return prisma.user.findUnique({ where: { id: user_id } });
}
