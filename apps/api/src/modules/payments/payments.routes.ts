import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';
import { requireAnyPermission, requirePermission } from '../../middleware/permission';
import { resolveTenantContext } from '../../middleware/tenant';

import * as controller from './payments.controller';

const router: Router = ExpressRouter();
const context = [authenticate, resolveTenantContext];

router.get(
  '/branches/:branch_id/fees',
  ...context,
  requireAnyPermission(
    'PAYMENT_READ_SELF',
    'PAYMENT_READ_ALL',
    'SUBSCRIPTION_READ_SELF',
    'SUBSCRIPTION_READ_ALL',
  ),
  controller.listFees,
);
router.post(
  '/branches/:branch_id/payment-requests',
  ...context,
  requirePermission('PAYMENT_CREATE'),
  controller.createPaymentRequest,
);
router.patch(
  '/branches/:branch_id/payment-requests/:request_id',
  ...context,
  requirePermission('PAYMENT_CREATE'),
  controller.updatePaymentRequest,
);
router.post(
  '/branches/:branch_id/payment-evidence/upload-signature',
  ...context,
  requirePermission('PAYMENT_CREATE'),
  controller.createEvidenceUploadSignature,
);
router.get(
  '/branches/:branch_id/payment-requests',
  ...context,
  requireAnyPermission('PAYMENT_READ_SELF', 'PAYMENT_READ_ALL', 'PAYMENT_REQUEST_REVIEW'),
  controller.listPaymentRequests,
);
router.get(
  '/branches/:branch_id/payment-requests/:request_id',
  ...context,
  requireAnyPermission('PAYMENT_READ_SELF', 'PAYMENT_READ_ALL', 'PAYMENT_REQUEST_REVIEW'),
  controller.getPaymentRequest,
);
router.get(
  '/branches/:branch_id/payment-requests/:request_id/evidence/:evidence_id/download',
  ...context,
  requireAnyPermission(
    'PAYMENT_READ_SELF',
    'PAYMENT_READ_ALL',
    'PAYMENT_EVIDENCE_READ',
    'PAYMENT_REQUEST_REVIEW',
  ),
  controller.getEvidenceDownloadUrl,
);
router.post(
  '/branches/:branch_id/payment-requests/:request_id/:action',
  ...context,
  requirePermission('PAYMENT_REQUEST_REVIEW'),
  controller.reviewPaymentRequest,
);
router.post(
  '/branches/:branch_id/payment-attempts/:payment_attempt_id/:action',
  ...context,
  requireAnyPermission('PAYMENT_REFUND', 'PAYMENT_VOID'),
  controller.correctPayment,
);
router.post(
  '/branches/:branch_id/subscriptions/:subscription_id/settlement-waivers',
  ...context,
  requirePermission('PAYMENT_WAIVE'),
  controller.createSettlementWaiver,
);
router.get(
  '/branches/:branch_id/subscriptions/:subscription_id/settlement-waivers',
  ...context,
  requireAnyPermission('PAYMENT_READ_SELF', 'PAYMENT_READ_ALL', 'PAYMENT_WAIVE'),
  controller.listSettlementWaivers,
);
router.post(
  '/branches/:branch_id/subscriptions/:subscription_id/settlement-waivers/:waiver_id/reverse',
  ...context,
  requirePermission('PAYMENT_WAIVE'),
  controller.reverseSettlementWaiver,
);
router.get(
  '/branches/:branch_id/payment-attempts/:payment_attempt_id/receipt',
  ...context,
  requireAnyPermission('PAYMENT_READ_SELF', 'PAYMENT_READ_ALL', 'PAYMENT_REQUEST_REVIEW'),
  controller.getReceipt,
);

export default router;
