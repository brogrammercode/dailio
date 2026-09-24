import { Router, type Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requireAnyPermission, requirePermission } from '../../middleware/permission';

import * as SubscriptionsController from './subscriptions.controller';

const router: ExpressRouter = Router();

// Assign a subscription to a member
router.post(
  '/branches/:branch_id/members/:member_id/subscriptions',
  authenticate,
  resolveTenantContext,
  requirePermission('SUBSCRIPTION_CREATE'),
  SubscriptionsController.assignSubscription,
);

// List subscriptions within a branch
router.get(
  '/branches/:branch_id/subscriptions',
  authenticate,
  resolveTenantContext,
  requireAnyPermission('SUBSCRIPTION_READ_SELF', 'SUBSCRIPTION_READ_ALL'),
  SubscriptionsController.listSubscriptions,
);

// Get a specific subscription
router.get(
  '/branches/:branch_id/subscriptions/:subscription_id',
  authenticate,
  resolveTenantContext,
  requireAnyPermission('SUBSCRIPTION_READ_SELF', 'SUBSCRIPTION_READ_ALL'),
  SubscriptionsController.getSubscriptionDetail,
);

// Update (pause, cancel) a subscription
router.patch(
  '/branches/:branch_id/subscriptions/:subscription_id',
  authenticate,
  resolveTenantContext,
  requirePermission('SUBSCRIPTION_UPDATE'),
  SubscriptionsController.updateSubscription,
);

router.post(
  '/branches/:branch_id/subscriptions/:subscription_id/cancel',
  authenticate,
  resolveTenantContext,
  requirePermission('SUBSCRIPTION_CANCEL'),
  SubscriptionsController.cancelSubscription,
);

router.post(
  '/branches/:branch_id/subscriptions/:subscription_id/pause',
  authenticate,
  resolveTenantContext,
  requirePermission('SUBSCRIPTION_UPDATE'),
  SubscriptionsController.pauseSubscription,
);

router.post(
  '/branches/:branch_id/subscriptions/:subscription_id/resume',
  authenticate,
  resolveTenantContext,
  requirePermission('SUBSCRIPTION_UPDATE'),
  SubscriptionsController.resumeSubscription,
);

router.post(
  '/branches/:branch_id/subscriptions/:subscription_id/renew',
  authenticate,
  resolveTenantContext,
  requirePermission('SUBSCRIPTION_UPDATE'),
  SubscriptionsController.renewSubscription,
);

export default router;
