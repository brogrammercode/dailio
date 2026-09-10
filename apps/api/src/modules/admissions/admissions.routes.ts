import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import {
  joinBranch,
  getJoinRequests,
  approveRequest,
  rejectRequest,
} from './admissions.controller';

const router: Router = Router();

// Member requests to join
router.post('/branches/:branch_id/join', authenticate, joinBranch);

// Admin fetches requests
router.get(
  '/branches/:branch_id/join-requests',
  authenticate,
  resolveTenantContext,
  requirePermission('JOIN_REQUEST_READ'),
  getJoinRequests,
);

// Admin approves/rejects
router.post(
  '/branches/:branch_id/join-requests/:request_id/approve',
  authenticate,
  resolveTenantContext,
  requirePermission('JOIN_REQUEST_APPROVE'),
  approveRequest,
);
router.post(
  '/branches/:branch_id/join-requests/:request_id/reject',
  authenticate,
  resolveTenantContext,
  requirePermission('JOIN_REQUEST_REJECT'),
  rejectRequest,
);

export default router;
