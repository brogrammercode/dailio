import { Router, type Router as RouterType } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requireAnyPermission, requirePermission } from '../../middleware/permission';

import {
  approveLeave,
  cancelLeave,
  createLeaveRequest,
  listLeaveRequests,
  rejectLeave,
} from './leave.controller';

const router: RouterType = Router();
const scoped = [authenticate, resolveTenantContext] as const;
router.get(
  '/branches/:branch_id/leave-requests',
  ...scoped,
  requireAnyPermission('LEAVE_READ_SELF', 'LEAVE_READ_ALL', 'LEAVE_MANAGE'),
  listLeaveRequests,
);
router.post(
  '/branches/:branch_id/leave-requests',
  ...scoped,
  requirePermission('LEAVE_CREATE_SELF'),
  createLeaveRequest,
);
router.post(
  '/branches/:branch_id/leave-requests/:request_id/approve',
  ...scoped,
  requirePermission('LEAVE_MANAGE'),
  approveLeave,
);
router.post(
  '/branches/:branch_id/leave-requests/:request_id/reject',
  ...scoped,
  requirePermission('LEAVE_MANAGE'),
  rejectLeave,
);
router.post(
  '/branches/:branch_id/leave-requests/:request_id/cancel',
  ...scoped,
  requirePermission('LEAVE_CREATE_SELF'),
  cancelLeave,
);
export default router;
