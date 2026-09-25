import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import {
  createOrganization,
  getOrganizationById,
  listMyOrganizations,
  updateOrganization,
} from './organizations.controller';

const router: Router = ExpressRouter();

router.use(authenticate);

router.post('/', createOrganization);
router.get('/', listMyOrganizations);
router.get(
  '/:organization_id',
  resolveTenantContext,
  requirePermission('GYM_READ'),
  getOrganizationById,
);
router.patch(
  '/:organization_id',
  resolveTenantContext,
  requirePermission('GYM_UPDATE'),
  updateOrganization,
);

export { router as organizationsRouter };
