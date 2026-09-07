import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';

import { updateMyProfile, getMyContexts } from './users.controller';

const router: Router = ExpressRouter();

router.use(authenticate);
router.patch('/me', updateMyProfile);
router.get('/me/contexts', getMyContexts);

export { router as usersRouter };
