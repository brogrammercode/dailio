import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import { listMembers, getMember, newAdmission, suspend, deactivate } from './members.controller';

const router: Router = Router();

router.get('/branches/:branch_id/members', authenticate, resolveTenantContext, requirePermission('MEMBER_READ_ALL'), listMembers);
router.post('/branches/:branch_id/members', authenticate, resolveTenantContext, requirePermission('MEMBER_CREATE'), newAdmission);
router.get('/branches/:branch_id/members/:member_id', authenticate, resolveTenantContext, requirePermission('MEMBER_READ_ALL'), getMember);
router.post('/branches/:branch_id/members/:member_id/suspend', authenticate, resolveTenantContext, requirePermission('MEMBER_SUSPEND'), suspend);
router.post('/branches/:branch_id/members/:member_id/deactivate', authenticate, resolveTenantContext, requirePermission('MEMBER_DEACTIVATE'), deactivate);

export default router;
