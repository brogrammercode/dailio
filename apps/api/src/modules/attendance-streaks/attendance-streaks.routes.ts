import { Router, type Router as RouterType } from 'express';

import { authenticate } from '../../middleware/auth';
import { requireAnyPermission } from '../../middleware/permission';
import { resolveTenantContext } from '../../middleware/tenant';

import { getMemberStreak, getMyStreak } from './attendance-streaks.controller';

const router: RouterType = Router();
const scoped = [authenticate, resolveTenantContext] as const;
const read = requireAnyPermission('ATTENDANCE_READ_SELF', 'ATTENDANCE_READ_ALL');

router.get('/branches/:branch_id/attendance/streak', ...scoped, read, getMyStreak);
router.get('/branches/:branch_id/attendance/streak/:member_id', ...scoped, read, getMemberStreak);

export default router;
