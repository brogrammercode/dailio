import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import {
  clockInHandler,
  clockOutHandler,
  activeSessionHandler,
  listSessionsHandler,
  getPolicyHandler,
  updatePolicyHandler,
  correctSessionHandler,
} from './attendance.controller';

const router: Router = Router();

router.get(
  '/branches/:branch_id/attendance/policy',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_READ_ALL'),
  getPolicyHandler,
);
router.patch(
  '/branches/:branch_id/attendance/policy',
  authenticate,
  resolveTenantContext,
  requirePermission('SETTINGS_UPDATE'),
  updatePolicyHandler,
);

router.post(
  '/branches/:branch_id/attendance/clock-in',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_CREATE_SELF'),
  clockInHandler,
);
router.post(
  '/branches/:branch_id/attendance/clock-out',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_CREATE_SELF'),
  clockOutHandler,
);
router.get(
  '/branches/:branch_id/attendance/active-session',
  authenticate,
  resolveTenantContext,
  activeSessionHandler,
);
router.get(
  '/branches/:branch_id/attendance',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_READ_SELF'),
  listSessionsHandler,
);

export default router;

router.patch(
  '/branches/:branch_id/attendance/:session_id/correct',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_UPDATE_ALL'),
  correctSessionHandler,
);
