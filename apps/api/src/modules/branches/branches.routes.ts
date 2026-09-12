import { Router } from 'express';

import { authenticate } from '../../middleware/auth';

import { discoverBranches, createBranch, updateBranch, getBranch, getOrganizationBranches } from './branches.controller';

const router: Router = Router();

router.get('/branches/discover', authenticate, discoverBranches);

// Under organizations
router.get('/organizations/:organization_id/branches', authenticate, getOrganizationBranches);
router.post('/organizations/:organization_id/branches', authenticate, createBranch);
router.get('/organizations/:organization_id/branches/:branch_id', authenticate, getBranch);
router.patch('/organizations/:organization_id/branches/:branch_id', authenticate, updateBranch);

export default router;


