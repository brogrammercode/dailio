import { Redis } from 'ioredis';

import { env } from '../config/env';
import { logger } from '../config/logger';

export const redis = new Redis(env.REDIS_URL, {
  maxRetriesPerRequest: null, // required for BullMQ
  enableReadyCheck: false,
  lazyConnect: true,
});

redis.on('connect', () => logger.info('Redis connected'));
redis.on('error', (err) => logger.error('Redis error', { err }));
