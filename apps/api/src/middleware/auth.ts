import { NextFunction, Request, Response } from 'express';
import type { User } from '@prisma/client';

import { logger } from '../config/logger';
import { UnauthorizedError } from '../lib/errors';
import { verifyAccessToken } from '../lib/jwt';
import { prisma } from '../lib/prisma';

export async function authenticate(
  req: Request,
  _res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedError('Missing or malformed Authorization header');
    }
    const token = authHeader.slice(7);
    const payload = await verifyAccessToken(token);

    // Request handlers only need the authenticated identity and active state.
    // Avoid transferring profile, token, and emergency-contact columns on every
    // API request; /auth/me remains the explicit profile read endpoint.
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, status: true },
    });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedError('User not found or disabled');
    }

    req.user = user as User;
    next();
  } catch (err) {
    if (err instanceof UnauthorizedError) {
      next(err);
    } else {
      logger.debug('Token verification failed', { err });
      next(new UnauthorizedError('Invalid or expired token'));
    }
  }
}
