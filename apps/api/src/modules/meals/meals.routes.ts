import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { requireAnyPermission, requirePermission } from '../../middleware/permission';
import { resolveTenantContext } from '../../middleware/tenant';

import * as controller from './meals.controller';

const router: Router = Router();
const context = [authenticate, resolveTenantContext];

router.get(
  '/branches/:branch_id/meal-slots',
  ...context,
  requireAnyPermission('MEAL_READ_SELF', 'MEAL_READ_BRANCH', 'MEAL_SERVE', 'MEAL_MANAGE'),
  controller.listSlots,
);
router.get(
  '/branches/:branch_id/meal-members',
  ...context,
  requireAnyPermission('MEAL_SERVE', 'MEAL_READ_BRANCH'),
  controller.searchMembers,
);
router.post(
  '/branches/:branch_id/meal-slots',
  ...context,
  requirePermission('MEAL_MANAGE'),
  controller.saveSlot,
);
router.put(
  '/branches/:branch_id/meal-slots/:slot_id',
  ...context,
  requirePermission('MEAL_MANAGE'),
  controller.saveSlot,
);
router.get(
  '/branches/:branch_id/plans/:plan_id/meal-entitlements',
  ...context,
  requireAnyPermission('PLAN_READ', 'MEAL_READ_SELF', 'MEAL_MANAGE'),
  controller.listEntitlements,
);
router.put(
  '/branches/:branch_id/plans/:plan_id/meal-entitlements',
  ...context,
  requirePermission('MEAL_MANAGE'),
  controller.setEntitlement,
);
router.get(
  '/branches/:branch_id/meal-slots/:slot_id/eligibility',
  ...context,
  requireAnyPermission('MEAL_READ_SELF', 'MEAL_READ_BRANCH', 'MEAL_SERVE'),
  controller.eligibility,
);
router.get(
  '/branches/:branch_id/meal-servings',
  ...context,
  requireAnyPermission('MEAL_READ_SELF', 'MEAL_READ_BRANCH'),
  controller.listServings,
);
router.get(
  '/branches/:branch_id/meal-servings/summary',
  ...context,
  requireAnyPermission('MEAL_READ_SELF', 'MEAL_READ_BRANCH'),
  controller.summary,
);
router.post(
  '/branches/:branch_id/meal-servings',
  ...context,
  requirePermission('MEAL_SERVE'),
  controller.serve,
);
router.post(
  '/branches/:branch_id/meal-servings/:serving_id/void',
  ...context,
  requirePermission('MEAL_VOID'),
  controller.voidServing,
);

export default router;
