import { Queue } from 'bullmq';

import { redis } from '../lib/redis';

const connection = redis;

export const notificationQueue = new Queue('notifications', { connection });
export const reminderQueue = new Queue('reminders', { connection });

export type NotificationJobData = {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

export type ReminderJobData = {
  reminderId: string;
  organization_id: string;
  location_id: string;
};
