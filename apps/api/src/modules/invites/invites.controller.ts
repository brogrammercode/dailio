import type { NextFunction, Request, Response } from 'express';

import { ValidationError } from '../../lib/errors';
import { QrPunchSchema } from '../attendance/attendance.schema';

import {
  CreateDirectSubscriptionDraftSchema,
  CreateSubscriptionDraftSchema,
  JoinInviteRequestSchema,
} from './invites.schema';
import * as service from './invites.service';

function token(req: Request) {
  const value = req.params.token?.trim();
  if (!value) throw new ValidationError('Invite token is required');
  return value;
}

function idempotencyKey(req: Request) {
  const value = req.header('Idempotency-Key')?.trim();
  if (!value) throw new ValidationError('Idempotency-Key header is required');
  return value;
}

export async function createBranchInvite(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await service.createBranchInvite(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
    );
    res.status(201).json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function createPlanInvite(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await service.createPlanInvite(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.plan_id,
    );
    res.status(201).json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function resolveInvite(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      data: await service.resolveInvite(req.user!.id, token(req)),
      server_time: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
}

export async function submitJoinRequest(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await service.submitJoinRequestFromInvite(
      req.user!.id,
      token(req),
      idempotencyKey(req),
      JoinInviteRequestSchema.parse(req.body),
    );
    res.status(201).json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function punchAttendanceFromInvite(req: Request, res: Response, next: NextFunction) {
  try {
    const idempotency = idempotencyKey(req);
    const body = QrPunchSchema.parse({ body: req.body }).body;
    const result = await service.punchAttendanceFromInvite(
      req.user!.id,
      body.token,
      idempotency,
      body,
    );
    res.status(201).json({ data: result, server_time: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
}

export async function createSubscriptionDraft(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await service.createSubscriptionDraftFromInvite(
      req.user!.id,
      token(req),
      idempotencyKey(req),
      CreateSubscriptionDraftSchema.parse(req.body),
    );
    res.status(201).json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function createDirectSubscriptionDraft(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const result = await service.createDirectSubscriptionDraft(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.plan_id,
      idempotencyKey(req),
      CreateDirectSubscriptionDraftSchema.parse(req.body),
    );
    res.status(201).json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function revokeInvite(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await service.revokeInvite(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.invite_id,
    );
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
}
