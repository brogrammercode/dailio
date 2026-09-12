import { Request, Response, NextFunction } from 'express';

import { CreatePlanSchema, UpdatePlanSchema } from './plans.schema';
import * as PlansService from './plans.service';

export async function getPlans(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const plans = await PlansService.getOrganizationPlans(orgId);
    res.json({ data: plans });
  } catch (err) {
    next(err);
  }
}

export async function createPlan(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const data = CreatePlanSchema.parse(req.body);
    const plan = await PlansService.createPlan(orgId, data);
    res.status(201).json({ data: plan });
  } catch (err) {
    next(err);
  }
}

export async function updatePlan(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const planId = req.params.plan_id;
    const data = UpdatePlanSchema.parse(req.body);
    const plan = await PlansService.updatePlan(orgId, planId, data);
    res.json({ data: plan });
  } catch (err) {
    next(err);
  }
}
