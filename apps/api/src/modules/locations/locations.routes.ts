import { Router } from 'express';
import { discoverLocations } from './locations.controller';
import { authenticate } from '../../middleware/auth';

const router: Router = Router();

// Publicly discoverable locations (requires authentication but no specific tenant)
router.get('/locations/discover', authenticate, discoverLocations);

export default router;
