/* eslint-disable import/order */
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
  const attendanceMaintenance = getAttendanceMaintenanceStatus();
  res.status(attendanceMaintenance.status === 'degraded' ? 503 : 200).json({
    status: attendanceMaintenance.status,
    timestamp: new Date().toISOString(),
    attendance_maintenance: attendanceMaintenance,
  });
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
import plansRouter from '../modules/plans/plans.routes';
import shiftsRouter from '../modules/shifts/shifts.routes';
import payrollRouter from '../modules/payroll/payroll.routes';
import subscriptionsRouter from '../modules/subscriptions/subscriptions.routes';
import paymentsRouter from '../modules/payments/payments.routes';
import invitesRouter from '../modules/invites/invites.routes';
import notificationsRouter from '../modules/notifications/notifications.routes';
import { getAttendanceMaintenanceStatus } from '../modules/attendance/attendance.maintenance';
router.use('/organizations', plansRouter);
router.use('/organizations', shiftsRouter);
router.use('/organizations', payrollRouter);
router.use(subscriptionsRouter);
router.use(paymentsRouter);
router.use(invitesRouter);
router.use(notificationsRouter);
// router.use('/payments', paymentsRouter);
// router.use('/announcements', announcementsRouter);
// router.use('/notifications', notificationsRouter);
// router.use('/reports', reportingRouter);
// router.use('/audit', auditRouter);

export { router as apiRouter };
