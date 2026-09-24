import { env } from '../config/env';
import { logger } from '../config/logger';

// Mock Redis client since Redis is not currently running locally
class MockRedis {
  async get(key: string) {
    return null;
  }
  async setex(key: string, seconds: number, value: string) {
    return 'OK';
  }
  async quit() {
    return 'OK';
  }
  on(event: string, callback: any) {}

  // Minimal BullMQ compat if needed
  public status = 'ready';
  async eval() {
    return null;
  }
}

export const redis = new MockRedis() as any;
