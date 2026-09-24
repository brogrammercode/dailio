import { describe, expect, it } from 'vitest';

import { calculateSubscriptionEndDate } from './subscriptions.service';

describe('subscription coverage dates', () => {
  it('adds the plan duration without changing the input date', () => {
    const start = new Date('2026-01-31T00:00:00.000Z');
    const end = calculateSubscriptionEndDate(start, 30);
    expect(start.toISOString()).toBe('2026-01-31T00:00:00.000Z');
    expect(end.toISOString()).toBe('2026-03-02T00:00:00.000Z');
  });
});
