import { SignJWT, jwtVerify } from 'jose';

import { env } from '../config/env';

const accessSecret = new TextEncoder().encode(env.JWT_ACCESS_SECRET);
const refreshSecret = new TextEncoder().encode(env.JWT_REFRESH_SECRET);

export interface AccessTokenPayload {
  sub: string; // user_id
  type: 'access';
}

export interface RefreshTokenPayload {
  sub: string;
  type: 'refresh';
  jti: string; // unique token ID for revocation
}

export async function signAccessToken(user_id: string): Promise<string> {
  return new SignJWT({ type: 'access' } satisfies Omit<AccessTokenPayload, 'sub'>)
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user_id)
    .setIssuedAt()
    .setExpirationTime(env.JWT_ACCESS_EXPIRES_IN)
    .sign(accessSecret);
}

export async function signRefreshToken(user_id: string, jti: string): Promise<string> {
  return new SignJWT({ type: 'refresh', jti } satisfies Omit<RefreshTokenPayload, 'sub'>)
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user_id)
    .setIssuedAt()
    .setExpirationTime(env.JWT_REFRESH_EXPIRES_IN)
    .sign(refreshSecret);
}

export async function verifyAccessToken(token: string): Promise<AccessTokenPayload> {
  const { payload } = await jwtVerify(token, accessSecret);
  if (payload.type !== 'access') throw new Error('Invalid token type');
  return payload as unknown as AccessTokenPayload;
}

export async function verifyRefreshToken(token: string): Promise<RefreshTokenPayload> {
  const { payload } = await jwtVerify(token, refreshSecret);
  if (payload.type !== 'refresh') throw new Error('Invalid token type');
  return payload as unknown as RefreshTokenPayload;
}
