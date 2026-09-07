import { NextFunction, Request, Response } from 'express';

import { UpdateProfileSchema } from './users.schema';
import { updateProfile, getUserContexts } from './users.service';

export async function updateMyProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const data = UpdateProfileSchema.parse(req.body);
    const user = await updateProfile(req.user!.id, data);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
}

export async function getMyContexts(req: Request, res: Response, next: NextFunction) {
  try {
    const contexts = await getUserContexts(req.user!.id);
    res.status(200).json({ contexts });
  } catch (err) {
    next(err);
  }
}
