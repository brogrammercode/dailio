import { createApp } from './app';
import { env } from './config/env';
import { logger } from './config/logger';
import { prisma } from './lib/prisma';
import { redis } from './lib/redis';
import { getFirebaseApp } from './lib/firebase';
import { safeErrorForLog } from './middleware/errorHandler';
import {
  runAttendanceRetentionMaintenance,
  runAttendanceReviewMaintenance,
} from './modules/attendance/attendance.maintenance';

const app = createApp();
getFirebaseApp();

function runAttendanceMaintenance() {
  void runAttendanceRetentionMaintenance().catch((error) => {
    logger.error('Attendance evidence retention pass failed', {
      error: safeErrorForLog(error),
    });
  });
  void runAttendanceReviewMaintenance().catch((error) => {
    logger.error('Attendance open-session review failed', { error: safeErrorForLog(error) });
  });
}

// Run once on startup so a deployment or restart does not defer maintenance
// until the next interval. Both jobs are idempotent and safe across instances.
runAttendanceMaintenance();

const server = app.listen(env.PORT, () => {
  logger.info(`🏋️  Organization Management API running`, {
    port: env.PORT,
    env: env.NODE_ENV,
    docs: `http://localhost:${env.PORT}/api/docs`,
  });
});

const retentionTimer = setInterval(
  () =>
    void runAttendanceRetentionMaintenance().catch((error) => {
      logger.error('Attendance evidence retention pass failed', {
        error: safeErrorForLog(error),
      });
    }),
  24 * 60 * 60 * 1000,
);
retentionTimer.unref();

const attendanceReviewTimer = setInterval(
  () =>
    void runAttendanceReviewMaintenance().catch((error) => {
      logger.error('Attendance open-session review failed', { error: safeErrorForLog(error) });
    }),
  15 * 60 * 1000,
);
attendanceReviewTimer.unref();

async function gracefulShutdown(signal: string) {
  logger.info(`Received ${signal}, shutting down gracefully...`);
  clearInterval(retentionTimer);
  clearInterval(attendanceReviewTimer);

  server.close(async () => {
    try {
      await prisma.$disconnect();
      await redis.quit();
      logger.info('Server closed cleanly');
      process.exit(0);
    } catch (err) {
      logger.error('Error during shutdown', { error: safeErrorForLog(err) });
      process.exit(1);
    }
  });
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection', { error: safeErrorForLog(reason) });
});
process.on('uncaughtException', (err) => {
  logger.error('Uncaught exception', { error: safeErrorForLog(err) });
  process.exit(1);
});
