import { Router } from 'express';

import { authenticate } from '../../middleware/auth';

import { discoverBranches } from './branches.controller';

const router: Router = Router();

// Publicly discoverable branches (requires authentication but no specific tenant)
router.get('/branches/discover', authenticate, discoverBranches);

export default router;
