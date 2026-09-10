import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';

import { createOrganization, getOrganizationById, listMyOrganizations, updateOrganization } from './organizations.controller';

const router: Router = ExpressRouter();

router.use(authenticate);

router.post('/', createOrganization);
router.get('/', listMyOrganizations);
router.get('/:organization_id', getOrganizationById);
router.patch('/:organization_id', updateOrganization);

export { router as organizationsRouter };
