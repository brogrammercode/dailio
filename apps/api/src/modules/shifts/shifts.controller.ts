import type { Request, Response, NextFunction } from 'express';

import * as shiftsService from './shifts.service';
import { CreateShiftSchema, UpdateShiftSchema } from './shifts.schema';

export async function listShifts(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const branchId = req.query.branch_id as string | undefined;
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
    const shift = await shiftsService.createShift(orgId, parsed.body);
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
    const shift = await shiftsService.updateShift(orgId, shiftId, parsed.body);
    res.json(shift);
  } catch (error) {
    next(error);
  }
}

export async function deleteShift(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const shiftId = req.params.shift_id;
    await shiftsService.deleteShift(orgId, shiftId);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}
