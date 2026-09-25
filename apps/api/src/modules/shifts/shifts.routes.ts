import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import { listShifts, createShift, updateShift, deleteShift } from './shifts.controller';

const router: Router = Router();

router.get(
  '/:organization_id/shifts',
  authenticate,
  resolveTenantContext,
  requirePermission('SHIFT_READ_ALL'),
  listShifts,
);
router.post(
  '/:organization_id/shifts',
  authenticate,
  resolveTenantContext,
  requirePermission('SHIFT_MANAGE'),
  createShift,
);
router.patch(
  '/:organization_id/shifts/:shift_id',
  authenticate,
  resolveTenantContext,
  requirePermission('SHIFT_MANAGE'),
  updateShift,
);
router.delete(
  '/:organization_id/shifts/:shift_id',
  authenticate,
  resolveTenantContext,
  requirePermission('SHIFT_MANAGE'),
  deleteShift,
);

export default router;
