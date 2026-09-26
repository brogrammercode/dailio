import type { Request, Response, NextFunction } from 'express';

import { ForbiddenError } from '../../lib/errors';

import * as shiftsService from './shifts.service';
import { CreateShiftSchema, UpdateShiftSchema } from './shifts.schema';

export async function listShifts(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    if (orgId !== req.organization!.id) throw new ForbiddenError('Organization scope is invalid');
    const requestedBranchId = req.query.branch_id as string | undefined;
    const branchId = req.permissions?.has('ALL') ? requestedBranchId : req.branch!.id;
    const shifts = await shiftsService.listShifts(orgId, branchId);
    res.json(shifts);
  } catch (error) {
    next(error);
  }
}

export async function createShift(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const parsed = CreateShiftSchema.parse({ body: req.body });
    if (orgId !== req.organization!.id) throw new ForbiddenError('Organization scope is invalid');
    if (parsed.body.branch_id !== req.branch!.id && !req.permissions?.has('ALL')) {
      throw new ForbiddenError('Shift branch scope is invalid');
    }
    const shift = await shiftsService.createShift(orgId, parsed.body, req.user!.id);
    res.status(201).json(shift);
  } catch (error) {
    next(error);
  }
}

export async function updateShift(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const shiftId = req.params.shift_id;
    const parsed = UpdateShiftSchema.parse({ body: req.body });
    if (orgId !== req.organization!.id) throw new ForbiddenError('Organization scope is invalid');
    const shift = await shiftsService.updateShift(
      orgId,
      req.branch!.id,
      shiftId,
      parsed.body,
      req.user!.id,
      req.permissions ?? new Set<string>(),
    );
    res.json(shift);
  } catch (error) {
    next(error);
  }
}

export async function deleteShift(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const shiftId = req.params.shift_id;
    if (orgId !== req.organization!.id) throw new ForbiddenError('Organization scope is invalid');
    await shiftsService.deleteShift(
      orgId,
      req.branch!.id,
      shiftId,
      req.user!.id,
      req.permissions ?? new Set<string>(),
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}
