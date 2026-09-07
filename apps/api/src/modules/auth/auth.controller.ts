import { NextFunction, Request, Response } from 'express';

import { GoogleSignInSchema, RefreshTokenSchema } from './auth.schema';
import { getMe, refreshTokens, signInWithGoogle } from './auth.service';

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

export async function logout(_req: Request, res: Response) {
  // Client is responsible for discarding tokens.
  // Server-side revocation can be added later via a token blacklist in Redis.
  res.status(200).json({ message: 'Logged out successfully' });
}

function sanitizeUser(user: { id: string; name: string; email: string | null; avatar_url: string | null; status: string }) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    avatar_url: user.avatar_url,
    status: user.status,
  };
}
