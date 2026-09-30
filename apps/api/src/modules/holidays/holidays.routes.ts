import { Router, type Router as RouterType } from 'express';

import { authenticate } from '../../middleware/auth';
import { requireAnyPermission, requirePermission } from '../../middleware/permission';
import { resolveTenantContext } from '../../middleware/tenant';

import { createHoliday, deleteHoliday, listHolidays, updateHoliday } from './holidays.controller';

const router: RouterType = Router();
const scoped = [authenticate, resolveTenantContext] as const;

router.get(
  '/branches/:branch_id/holidays',
  ...scoped,
  requireAnyPermission('HOLIDAY_READ', 'HOLIDAY_MANAGE'),
  listHolidays,
);
router.post(
  '/branches/:branch_id/holidays',
  ...scoped,
  requirePermission('HOLIDAY_MANAGE'),
  createHoliday,
);
router.patch(
  '/branches/:branch_id/holidays/:holiday_id',
  ...scoped,
  requirePermission('HOLIDAY_MANAGE'),
  updateHoliday,
);
router.delete(
  '/branches/:branch_id/holidays/:holiday_id',
  ...scoped,
  requirePermission('HOLIDAY_MANAGE'),
  deleteHoliday,
);

export default router;
