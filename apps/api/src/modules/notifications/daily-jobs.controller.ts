import type { NextFunction, Request, Response } from 'express';

import { env } from '../../config/env';
import { ForbiddenError } from '../../lib/errors';

import { runDailyNotificationCoordinator } from './daily-jobs.service';

export async function runDailyCheckHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await runDailyNotificationCoordinator();
    res.status(result.status === 'completed' ? 200 : 202).json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function runDailyCronHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const authorization = req.headers.authorization;
    const providedSecret = authorization?.startsWith('Bearer ')
      ? authorization.slice(7)
      : req.headers['x-cron-secret'];
    if (!env.CRON_SECRET || providedSecret !== env.CRON_SECRET) {
      throw new ForbiddenError('Cron authorization is required');
    }
    const result = await runDailyNotificationCoordinator();
    res.status(result.status === 'completed' ? 200 : 202).json({ data: result });
  } catch (error) {
    next(error);
  }
}
