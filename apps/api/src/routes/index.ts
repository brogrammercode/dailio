import { type Router, Router as ExpressRouter } from 'express';

import { authRouter } from '../modules/auth/auth.routes';
import { organizationsRouter } from '../modules/organizations/organizations.routes';
import branchesRouter from '../modules/branches/branches.routes';
import admissionsRouter from '../modules/admissions/admissions.routes';
import membersRouter from '../modules/members/members.routes';
import attendanceRouter from '../modules/attendance/attendance.routes';
import { rolesRouter } from '../modules/roles/roles.routes';

const router: Router = ExpressRouter();

// Health check
router.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Auth
router.use('/auth', authRouter);

// Organizations
router.use('/organizations', organizationsRouter);

// Roles
router.use('/roles', rolesRouter);

// Branches & Admissions
router.use(branchesRouter);
router.use(admissionsRouter);

// Members & Attendance
router.use(membersRouter);
router.use(attendanceRouter);

// TODO: mount remaining module routers as they are implemented:
// router.use('/plans', plansRouter);
// router.use('/subscriptions', subscriptionsRouter);
// router.use('/payments', paymentsRouter);
// router.use('/announcements', announcementsRouter);
// router.use('/notifications', notificationsRouter);
// router.use('/reports', reportingRouter);
// router.use('/audit', auditRouter);

export { router as apiRouter };
