import { Router, type Router as RouterType } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';

import { getMemberStreak, getMyStreak } from './attendance-streaks.controller';

const router: RouterType = Router();
const scoped = [authenticate, resolveTenantContext] as const;

// A streak is a small social/member summary, not an attendance-record read.
// Tenant context still requires an authenticated active branch membership.
router.get('/branches/:branch_id/attendance/streak', ...scoped, getMyStreak);
router.get('/branches/:branch_id/attendance/streak/:member_id', ...scoped, getMemberStreak);

export default router;
