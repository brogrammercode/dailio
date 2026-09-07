import { PrismaClient } from '@prisma/client';

import { logger } from '../config/logger';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      process.env.NODE_ENV === 'development'
        ? [{ emit: 'event', level: 'query' }, 'warn', 'error']
        : ['warn', 'error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

prisma.$on('query' as never, (e: unknown) => {
  const event = e as { query: string; duration: number };
  logger.debug(`Prisma Query: ${event.query} (${event.duration}ms)`);
});
