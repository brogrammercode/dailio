import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { qrPunchRateLimiter, qrResolutionRateLimiter } from '../../middleware/rateLimiter';
import { requireAnyPermission, requirePermission } from '../../middleware/permission';
import { resolveTenantContext } from '../../middleware/tenant';

import * as controller from './invites.controller';

const router: Router = Router();
const context = [authenticate, resolveTenantContext];

router.post(
  '/branches/:branch_id/join-invites',
  ...context,
  requirePermission('BRANCH_SETTINGS_UPDATE'),
  controller.createBranchInvite,
);
router.post(
  '/branches/:branch_id/join-invites/:invite_id/revoke',
  ...context,
  requirePermission('BRANCH_SETTINGS_UPDATE'),
  controller.revokeInvite,
);
router.post(
  '/branches/:branch_id/plans/:plan_id/purchase-invites',
  ...context,
  requirePermission('PLAN_MANAGE'),
  controller.createPlanInvite,
);
router.post(
  '/branches/:branch_id/plans/:plan_id/purchase-invites/:invite_id/revoke',
  ...context,
  requirePermission('PLAN_MANAGE'),
  controller.revokeInvite,
);

router.get('/invites/:token', authenticate, qrResolutionRateLimiter, controller.resolveInvite);
router.post('/join-invites/:token/requests', authenticate, controller.submitJoinRequest);
router.post(
  '/attendance/qr-punch',
  authenticate,
  qrPunchRateLimiter,
  controller.punchAttendanceFromInvite,
);
router.post(
  '/purchase-invites/:token/subscription-drafts',
  authenticate,
  controller.createSubscriptionDraft,
);
router.post(
  '/branches/:branch_id/plans/:plan_id/subscription-drafts',
  ...context,
  requireAnyPermission('SUBSCRIPTION_READ_SELF', 'PAYMENT_CREATE'),
  controller.createDirectSubscriptionDraft,
);

export default router;
