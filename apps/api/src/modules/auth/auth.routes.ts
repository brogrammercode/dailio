import { type Router, Router as ExpressRouter } from 'express';

import { authenticate } from '../../middleware/auth';
import { authRateLimiter } from '../../middleware/rateLimiter';

import { googleSignIn, logout, me, refreshToken } from './auth.controller';

const router: Router = ExpressRouter();

router.post('/google', authRateLimiter, googleSignIn);
router.post('/refresh', authRateLimiter, refreshToken);
router.post('/logout', authenticate, logout);
router.get('/me', authenticate, me);

export { router as authRouter };
