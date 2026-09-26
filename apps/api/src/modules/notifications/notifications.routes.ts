import { Router } from 'express';

import { authenticate } from '../../middleware/auth';

import {
  listNotificationsHandler,
  markAllNotificationsReadHandler,
  markNotificationReadHandler,
} from './notifications.controller';

const router: Router = Router();

router.get('/notifications', authenticate, listNotificationsHandler);
router.post('/notifications/read-all', authenticate, markAllNotificationsReadHandler);
router.patch(
  '/notifications/:notification_id/read',
  authenticate,
  markNotificationReadHandler,
);

export default router;
