import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import {
  discoverBranches,
  createBranch,
  updateBranch,
  getBranch,
  getOrganizationBranches,
} from './branches.controller';

const router: Router = Router();

router.get('/branches/discover', authenticate, discoverBranches);

// Under organizations
router.get(
  '/organizations/:organization_id/branches',
  authenticate,
  resolveTenantContext,
  requirePermission('BRANCH_READ'),
  getOrganizationBranches,
);
router.post(
  '/organizations/:organization_id/branches',
  authenticate,
  resolveTenantContext,
  requirePermission('BRANCH_CREATE'),
  createBranch,
);
router.get(
  '/organizations/:organization_id/branches/:branch_id',
  authenticate,
  resolveTenantContext,
  requirePermission('BRANCH_READ'),
  getBranch,
);
router.patch(
  '/organizations/:organization_id/branches/:branch_id',
  authenticate,
  resolveTenantContext,
  requirePermission('BRANCH_UPDATE'),
  updateBranch,
);

export default router;
