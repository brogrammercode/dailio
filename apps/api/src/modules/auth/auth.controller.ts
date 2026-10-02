import type { User } from '@prisma/client';
import { NextFunction, Request, Response } from 'express';

import { env } from '../../config/env';

import { GoogleSignInSchema, RefreshTokenSchema } from './auth.schema';
import { getMe, refreshTokens, revokeRefreshToken, signInWithGoogle } from './auth.service';

export async function googleSignIn(req: Request, res: Response, next: NextFunction) {
  try {
    const { idToken } = GoogleSignInSchema.parse(req.body);
    const result = await signInWithGoogle(idToken);
    res.status(200).json({
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      user: sanitizeUser(result.user),
    });
  } catch (err) {
    next(err);
  }
}

export async function refreshToken(req: Request, res: Response, next: NextFunction) {
  try {
    const { refreshToken } = RefreshTokenSchema.parse(req.body);
    const result = await refreshTokens(refreshToken);
    res.status(200).json({
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      user: sanitizeUser(result.user),
    });
  } catch (err) {
    next(err);
  }
}

const browserCookieOptions = {
  httpOnly: true,
  secure: env.NODE_ENV === 'production',
  sameSite: 'lax' as const,
  path: '/api/v1/auth/browser',
  maxAge: 30 * 24 * 60 * 60 * 1000,
};

function readCookie(req: Request, name: string) {
  const header = req.headers.cookie;
  if (!header) return undefined;
  const entry = header.split(';').find((part) => part.trim().startsWith(`${name}=`));
  if (!entry) return undefined;
  try {
    return decodeURIComponent(entry.trim().slice(name.length + 1));
  } catch {
    return undefined;
  }
}

function setBrowserRefreshCookie(res: Response, token: string) {
  res.cookie(env.WEB_AUTH_COOKIE_NAME, token, browserCookieOptions);
}

export async function browserGoogleSignIn(req: Request, res: Response, next: NextFunction) {
  try {
    const { idToken } = GoogleSignInSchema.parse(req.body);
    const result = await signInWithGoogle(idToken);
    setBrowserRefreshCookie(res, result.refreshToken);
    res.status(200).json({
      accessToken: result.accessToken,
      user: sanitizeUser(result.user),
    });
  } catch (err) {
    next(err);
  }
}

export async function browserRefreshToken(req: Request, res: Response, next: NextFunction) {
  try {
    const refresh = readCookie(req, env.WEB_AUTH_COOKIE_NAME);
    if (!refresh) return res.status(204).send();
    const result = await refreshTokens(refresh);
    setBrowserRefreshCookie(res, result.refreshToken);
    return res.status(200).json({
      accessToken: result.accessToken,
      user: sanitizeUser(result.user),
    });
  } catch (err) {
    next(err);
  }
}

export async function browserLogout(req: Request, res: Response) {
  const refresh = readCookie(req, env.WEB_AUTH_COOKIE_NAME);
  if (refresh) await revokeRefreshToken(refresh);
  res.clearCookie(env.WEB_AUTH_COOKIE_NAME, browserCookieOptions);
  res.status(200).json({ message: 'Logged out successfully' });
}

export async function me(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await getMe(req.user!.id);
    res.status(200).json({ user: sanitizeUser(user!) });
  } catch (err) {
    next(err);
  }
}

export async function logout(req: Request, res: Response) {
  // Revoke the refresh token if provided in the request body
  const refreshToken = req.body?.refreshToken as string | undefined;
  if (refreshToken) {
    await revokeRefreshToken(refreshToken).catch(() => null);
  }
  res.status(200).json({ message: 'Logged out successfully' });
}

function sanitizeUser(user: User) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    avatar_url: user.avatar_url,
    status: user.status,
    emergency_contact_name: user.emergency_contact_name ?? null,
    emergency_contact_phone: user.emergency_contact_phone ?? null,
    date_of_birth: user.date_of_birth
      ? (user.date_of_birth as Date).toISOString().split('T')[0]
      : null,
  };
}
