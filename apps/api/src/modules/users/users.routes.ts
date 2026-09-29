import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';

import {
  updateMyProfile,
  getMyContexts,
  deleteMyAccount,
  removeMyDeviceToken,
} from './users.controller';

const router: Router = ExpressRouter();

router.use(authenticate);
router.patch('/me', updateMyProfile);
router.get('/me/contexts', getMyContexts);
router.delete('/me', deleteMyAccount);
router.delete('/me/device-token', removeMyDeviceToken);

export { router as usersRouter };
