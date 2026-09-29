import type { NextFunction, Request, Response } from 'express';

import { CreateLeaveRequestSchema, LeaveActionSchema } from './leave.schema';
import * as leaveService from './leave.service';

export async function listLeaveRequests(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      data: await leaveService.listLeaveRequests(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function createLeaveRequest(req: Request, res: Response, next: NextFunction) {
  try {
    const input = CreateLeaveRequestSchema.parse(req.body);
    res.status(201).json({
      data: await leaveService.createLeaveRequest(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        input,
        req.user!.id,
        req.header('Idempotency-Key') ?? undefined,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function approveLeave(req: Request, res: Response, next: NextFunction) {
  try {
    const input = LeaveActionSchema.parse(req.body);
    res.json({
      data: await leaveService.decideLeaveRequest(
        req.organization!.id,
        req.branch!.id,
        req.params.request_id,
        'APPROVED',
        input,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function rejectLeave(req: Request, res: Response, next: NextFunction) {
  try {
    const input = LeaveActionSchema.parse(req.body);
    res.json({
      data: await leaveService.decideLeaveRequest(
        req.organization!.id,
        req.branch!.id,
        req.params.request_id,
        'REJECTED',
        input,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function cancelLeave(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      data: await leaveService.cancelLeaveRequest(
        req.organization!.id,
        req.branch!.id,
        req.params.request_id,
        req.member!.id,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}
