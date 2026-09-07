import { createApp } from './app';
import { env } from './config/env';
import { logger } from './config/logger';
import { prisma } from './lib/prisma';
import { redis } from './lib/redis';
import { getFirebaseApp } from './lib/firebase';

const app = createApp();
getFirebaseApp();

const server = app.listen(env.PORT, () => {
  logger.info(`🏋️  Organization Management API running`, {
    port: env.PORT,
    env: env.NODE_ENV,
    docs: `http://localhost:${env.PORT}/api/docs`,
  });
});

async function gracefulShutdown(signal: string) {
  logger.info(`Received ${signal}, shutting down gracefully...`);

  server.close(async () => {
    try {
      await prisma.$disconnect();
      await redis.quit();
      logger.info('Server closed cleanly');
      process.exit(0);
    } catch (err) {
      logger.error('Error during shutdown', { err });
      process.exit(1);
    }
  });
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection', { reason });
});
process.on('uncaughtException', (err) => {
  logger.error('Uncaught exception', { err });
  process.exit(1);
});
