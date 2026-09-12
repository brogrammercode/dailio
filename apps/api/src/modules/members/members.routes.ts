import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import {
  listMembers,
  getMember,
  newAdmission,
  suspend,
  deactivate,
  update,
  getOrganizationMembers
} from './members.controller';

const router: Router = Router();

router.get('/organizations/:organization_id/members', authenticate, getOrganizationMembers);

router.get(
  '/branches/:branch_id/members',
  authenticate,
  resolveTenantContext,
  requirePermission('MEMBER_READ_ALL'),
  listMembers,
);
router.post(
  '/branches/:branch_id/members',
  authenticate,
  resolveTenantContext,
  requirePermission('MEMBER_CREATE'),
  newAdmission,
);
router.get(
  '/branches/:branch_id/members/:member_id',
  authenticate,
  resolveTenantContext,
  requirePermission('MEMBER_READ_ALL'),
  getMember,
);
router.post(
  '/branches/:branch_id/members/:member_id/suspend',
  authenticate,
  resolveTenantContext,
  requirePermission('MEMBER_SUSPEND'),
  suspend,
);
router.post(
  '/branches/:branch_id/members/:member_id/deactivate',
  authenticate,
  resolveTenantContext,
  requirePermission('MEMBER_DEACTIVATE'),
  deactivate,
);

router.patch(
  '/branches/:branch_id/members/:member_id',
  authenticate,
  resolveTenantContext,
  requirePermission('MEMBER_UPDATE'),
  update,
);

export default router;
