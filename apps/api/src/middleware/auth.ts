import { NextFunction, Request, Response } from 'express';

import { logger } from '../config/logger';
import { UnauthorizedError } from '../lib/errors';
import { verifyAccessToken } from '../lib/jwt';
import { prisma } from '../lib/prisma';

export async function authenticate(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedError('Missing or malformed Authorization header');
    }
    const token = authHeader.slice(7);
    const payload = await verifyAccessToken(token);

    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedError('User not found or disabled');
    }

    req.user = user;
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
