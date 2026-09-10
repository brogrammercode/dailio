import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';

import { listRoles, createRole, updateRole } from './roles.controller';

const router: Router = ExpressRouter();

router.use(authenticate);

router.get('/', listRoles);
router.post('/', createRole);
router.patch('/:role_id', updateRole);

export { router as rolesRouter };
