import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import {
  listStructures,
  createStructure,
  updateStructure,
  deleteStructure,
} from './payroll.controller';

const router: Router = Router();

router.get(
  '/:organization_id/salary-structures',
  authenticate,
  resolveTenantContext,
  requirePermission('PAYROLL_READ_BRANCH'),
  listStructures,
);
router.post(
  '/:organization_id/salary-structures',
  authenticate,
  resolveTenantContext,
  requirePermission('PAYROLL_GENERATE'),
  createStructure,
);
router.patch(
  '/:organization_id/salary-structures/:id',
  authenticate,
  resolveTenantContext,
  requirePermission('PAYROLL_GENERATE'),
  updateStructure,
);
router.delete(
  '/:organization_id/salary-structures/:id',
  authenticate,
  resolveTenantContext,
  requirePermission('PAYROLL_GENERATE'),
  deleteStructure,
);

export default router;
