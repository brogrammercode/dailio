import { Router } from 'express';

import { authenticate } from '../../middleware/auth';

import { discoverLocations } from './locations.controller';

const router: Router = Router();

// Publicly discoverable locations (requires authentication but no specific tenant)
router.get('/locations/discover', authenticate, discoverLocations);

export default router;
