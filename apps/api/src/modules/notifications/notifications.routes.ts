import { Router } from 'express';

import { authenticate } from '../../middleware/auth';

import {
  listNotificationsHandler,
  countUnreadNotificationsHandler,
  markAllNotificationsReadHandler,
  markNotificationReadHandler,
  listNotificationPreferencesHandler,
  setNotificationPreferenceHandler,
} from './notifications.controller';
import { runDailyCheckHandler, runDailyCronHandler } from './daily-jobs.controller';

const router: Router = Router();

router.get('/notifications', authenticate, listNotificationsHandler);
router.get('/notifications/unread-count', authenticate, countUnreadNotificationsHandler);
router.post('/notifications/read-all', authenticate, markAllNotificationsReadHandler);
router.patch('/notifications/:notification_id/read', authenticate, markNotificationReadHandler);
router.get('/notifications/preferences', authenticate, listNotificationPreferencesHandler);
router.put('/notifications/preferences', authenticate, setNotificationPreferenceHandler);
router.post('/maintenance/daily-check', authenticate, runDailyCheckHandler);
router.get('/maintenance/daily-check/cron', runDailyCronHandler);

export default router;
