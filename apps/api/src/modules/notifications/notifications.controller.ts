import type { NextFunction, Request, Response } from 'express';
import { z } from 'zod';

import * as notificationsService from './notifications.service';

const querySchema = z.object({
  unread_only: z.coerce.boolean().default(false),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().min(1).optional(),
});

const preferenceSchema = z.object({
  event_type: z.string().min(1).max(120),
  channel: z.enum(['PUSH', 'EMAIL']),
  enabled: z.boolean(),
});

export async function listNotificationsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const query = querySchema.parse(req.query);
    const result = await notificationsService.listNotifications(req.user!.id, query);
    res.json({ data: result.data, meta: { next_cursor: result.next_cursor } });
  } catch (error) {
    next(error);
  }
}

export async function markNotificationReadHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await notificationsService.markNotificationRead(
      req.user!.id,
      req.params.notification_id,
    );
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function markAllNotificationsReadHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const result = await notificationsService.markAllNotificationsRead(req.user!.id);
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function listNotificationPreferencesHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const data = await notificationsService.listNotificationPreferences(req.user!.id);
    res.json({ data });
  } catch (error) {
    next(error);
  }
}

export async function setNotificationPreferenceHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const input = preferenceSchema.parse(req.body);
    const data = await notificationsService.setNotificationPreference({
      userId: req.user!.id,
      eventType: input.event_type,
      channel: input.channel,
      enabled: input.enabled,
    });
    res.json({ data });
  } catch (error) {
    next(error);
  }
}
