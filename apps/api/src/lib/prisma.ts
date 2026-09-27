import 'dotenv/config';

import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

function databaseUrlWithPoolSettings() {
  const rawUrl = process.env.DATABASE_URL;
  if (!rawUrl) return undefined;

  const url = new URL(rawUrl);
  if (!url.searchParams.has('connection_limit')) {
    url.searchParams.set(
      'connection_limit',
      process.env.DATABASE_CONNECTION_LIMIT ?? '15',
    );
  }
  if (!url.searchParams.has('pool_timeout')) {
    url.searchParams.set(
      'pool_timeout',
      process.env.DATABASE_POOL_TIMEOUT ?? '15',
    );
  }
  return url.toString();
}

const databaseUrl = databaseUrlWithPoolSettings();

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: ['error'], // Hiding logs as requested
    ...(databaseUrl
      ? { datasources: { db: { url: databaseUrl } } }
      : {}),
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}
