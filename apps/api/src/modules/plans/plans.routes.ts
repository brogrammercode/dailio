import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import { getPlans, createPlan, updatePlan } from './plans.controller';

const router: Router = Router();

// /organizations/:organization_id/plans
router.get('/:organization_id/plans', authenticate, resolveTenantContext, requirePermission('PLAN_READ'), getPlans);
router.post('/:organization_id/plans', authenticate, resolveTenantContext, requirePermission('PLAN_MANAGE'), createPlan);
router.patch('/:organization_id/plans/:plan_id', authenticate, resolveTenantContext, requirePermission('PLAN_MANAGE'), updatePlan);

export default router;


