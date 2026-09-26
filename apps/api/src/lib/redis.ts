/* eslint-disable @typescript-eslint/no-explicit-any */

// Mock Redis client since Redis is not currently running locally
class MockRedis {
  async get(_key: string) {
    return null;
  }
  async setex(_key: string, _seconds: number, _value: string) {
    return 'OK';
  }
  async quit() {
    return 'OK';
  }
  on(_event: string, _callback: (...args: unknown[]) => void) {}

  // Minimal BullMQ compat if needed
  public status = 'ready';
  async eval(..._args: unknown[]) {
    return null;
  }
}

export const redis = new MockRedis() as any;
