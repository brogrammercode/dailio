import type { NextFunction, Request, Response } from 'express';

import * as streakService from './attendance-streaks.service';

export async function getMyStreak(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      data: await streakService.getMemberStreak(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function getMemberStreak(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      data: await streakService.getMemberStreak(
        req.organization!.id,
        req.branch!.id,
        req.params.member_id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}
