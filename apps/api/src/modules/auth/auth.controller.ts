import type { User } from '@prisma/client';
import { NextFunction, Request, Response } from 'express';

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
