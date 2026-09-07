import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import { listMembers, getMember, newAdmission, suspend, deactivate } from './members.controller';

const router: Router = Router();

router.get('/locations/:location_id/members', authenticate, resolveTenantContext, requirePermission('MEMBER_READ_ALL'), listMembers);
router.post('/locations/:location_id/members', authenticate, resolveTenantContext, requirePermission('MEMBER_CREATE'), newAdmission);
router.get('/locations/:location_id/members/:membership_id', authenticate, resolveTenantContext, requirePermission('MEMBER_READ_ALL'), getMember);
router.post('/locations/:location_id/members/:membership_id/suspend', authenticate, resolveTenantContext, requirePermission('MEMBER_SUSPEND'), suspend);
router.post('/locations/:location_id/members/:membership_id/deactivate', authenticate, resolveTenantContext, requirePermission('MEMBER_DEACTIVATE'), deactivate);

export default router;
