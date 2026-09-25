import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import { listRoles, createRole, updateRole } from './roles.controller';

const router: Router = ExpressRouter();

router.use(authenticate);

router.get('/', resolveTenantContext, requirePermission('ROLE_READ'), listRoles);
router.post('/', resolveTenantContext, requirePermission('ROLE_CREATE'), createRole);
router.patch('/:role_id', resolveTenantContext, requirePermission('ROLE_UPDATE'), updateRole);

export { router as rolesRouter };
