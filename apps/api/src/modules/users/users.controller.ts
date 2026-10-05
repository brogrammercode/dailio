import { NextFunction, Request, Response } from 'express';
import { z } from 'zod';

import { RegisterDeviceTokenSchema, UpdateProfileSchema } from './users.schema';
import {
  getUserContexts,
  registerDeviceToken,
  removeDeviceToken,
  updateProfile,
} from './users.service';

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

export async function deleteMyAccount(req: Request, res: Response, next: NextFunction) {
  try {
    // We import deleteAccount here to avoid circular imports if any, or just import it at top
    const { deleteAccount } = await import('./users.service');
    await deleteAccount(req.user!.id);
    res.status(200).json({ success: true });
  } catch (err) {
    next(err);
  }
}

export async function removeMyDeviceToken(req: Request, res: Response, next: NextFunction) {
  try {
    const token = z.string().min(1).max(4096).parse(req.body?.token);
    await removeDeviceToken(req.user!.id, token);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

export async function registerMyDeviceToken(req: Request, res: Response, next: NextFunction) {
  try {
    const data = RegisterDeviceTokenSchema.parse(req.body);
    await registerDeviceToken(req.user!.id, data);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}
