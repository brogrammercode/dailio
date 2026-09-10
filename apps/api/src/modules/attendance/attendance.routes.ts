import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import { clockInHandler, clockOutHandler, activeSessionHandler, listSessionsHandler } from './attendance.controller';

const router: Router = Router();

router.post('/branches/:branch_id/attendance/clock-in', authenticate, resolveTenantContext, requirePermission('ATTENDANCE_CREATE_SELF'), clockInHandler);
router.post('/branches/:branch_id/attendance/clock-out', authenticate, resolveTenantContext, requirePermission('ATTENDANCE_CREATE_SELF'), clockOutHandler);
router.get('/branches/:branch_id/attendance/active-session', authenticate, resolveTenantContext, activeSessionHandler);
router.get('/branches/:branch_id/attendance', authenticate, resolveTenantContext, requirePermission('ATTENDANCE_READ_SELF'), listSessionsHandler);

export default router;
