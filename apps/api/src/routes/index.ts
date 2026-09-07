import { type Router, Router as ExpressRouter } from 'express';

import { authRouter } from '../modules/auth/auth.routes';
import { organizationsRouter } from '../modules/organizations/organizations.routes';

import locationsRouter from '../modules/locations/locations.routes';
import admissionsRouter from '../modules/admissions/admissions.routes';

const router: Router = ExpressRouter();

// Health check
router.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Auth
router.use('/auth', authRouter);

// Organizations
router.use('/organizations', organizationsRouter);

// Locations & Admissions
router.use(locationsRouter);
router.use(admissionsRouter);

// TODO: mount remaining module routers as they are implemented:
// router.use('/locationes', locationesRouter);
// router.use('/members', membersRouter);
// router.use('/attendance', attendanceRouter);
// router.use('/plans', plansRouter);
// router.use('/subscriptions', subscriptionsRouter);
// router.use('/payments', paymentsRouter);
// router.use('/announcements', announcementsRouter);
// router.use('/notifications', notificationsRouter);
// router.use('/reports', reportingRouter);
// router.use('/audit', auditRouter);

export { router as apiRouter };
