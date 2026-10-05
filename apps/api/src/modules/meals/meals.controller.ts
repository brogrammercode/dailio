import type { NextFunction, Request, Response } from 'express';

import { ForbiddenError, ValidationError } from '../../lib/errors';

import {
  MealEntitlementInputSchema,
  MealServeInputSchema,
  MealServingQuerySchema,
  MealSlotInputSchema,
  MealVoidInputSchema,
} from './meals.schema';
import * as service from './meals.service';

function idempotencyKey(req: Request) {
  const value = req.header('Idempotency-Key')?.trim();
  if (!value) throw new ValidationError('Idempotency-Key header is required');
  return value;
}

export async function listSlots(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ data: await service.listMealSlots(req.organization!.id, req.branch!.id) });
  } catch (error) {
    next(error);
  }
}

export async function searchMembers(req: Request, res: Response, next: NextFunction) {
  try {
    const query = typeof req.query.query === 'string' ? req.query.query.trim().slice(0, 80) : '';
    res.json({
      data: await service.searchMealMembers(req.organization!.id, req.branch!.id, query),
    });
  } catch (error) {
    next(error);
  }
}

export async function saveSlot(req: Request, res: Response, next: NextFunction) {
  try {
    const input = MealSlotInputSchema.parse(req.body);
    const slot = await service.upsertMealSlot(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.slot_id ?? null,
      input,
    );
    res.status(req.params.slot_id ? 200 : 201).json({ data: slot });
  } catch (error) {
    next(error);
  }
}

export async function listEntitlements(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      data: await service.listEntitlements(
        req.organization!.id,
        req.branch!.id,
        req.params.plan_id,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function setEntitlement(req: Request, res: Response, next: NextFunction) {
  try {
    const input = MealEntitlementInputSchema.parse(req.body);
    res.json({
      data: await service.setEntitlement(
        req.user!.id,
        req.organization!.id,
        req.branch!.id,
        req.params.plan_id,
        input,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function eligibility(req: Request, res: Response, next: NextFunction) {
  try {
    const permissions = req.permissions ?? new Set<string>();
    const memberId = req.query.member_id?.toString() || req.member!.id;
    if (
      memberId !== req.member!.id &&
      !permissions.has('ALL') &&
      !permissions.has('MEAL_READ_BRANCH') &&
      !permissions.has('MEAL_SERVE')
    )
      throw new ForbiddenError('Meal eligibility scope is not permitted');
    res.json({
      data: await service.getMealEligibility(
        req.organization!.id,
        req.branch!.id,
        memberId,
        req.params.slot_id,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function listServings(req: Request, res: Response, next: NextFunction) {
  try {
    const query = MealServingQuerySchema.parse(req.query);
    res.json(
      await service.listMealServings(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.permissions ?? new Set<string>(),
        query,
      ),
    );
  } catch (error) {
    next(error);
  }
}

export async function summary(req: Request, res: Response, next: NextFunction) {
  try {
    const query = MealServingQuerySchema.parse(req.query);
    res.json({
      data: await service.getMealSummary(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.permissions ?? new Set<string>(),
        query,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function serve(req: Request, res: Response, next: NextFunction) {
  try {
    const input = MealServeInputSchema.parse(req.body);
    res.status(201).json({
      data: await service.serveMeal(
        req.user!.id,
        req.organization!.id,
        req.branch!.id,
        idempotencyKey(req),
        input,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function voidServing(req: Request, res: Response, next: NextFunction) {
  try {
    const input = MealVoidInputSchema.parse(req.body);
    res.json({
      data: await service.voidMeal(
        req.user!.id,
        req.organization!.id,
        req.branch!.id,
        req.params.serving_id,
        input.reason,
      ),
    });
  } catch (error) {
    next(error);
  }
}
