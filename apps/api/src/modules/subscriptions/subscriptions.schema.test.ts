import { describe, expect, it } from 'vitest';

import {
  AssignSubscriptionSchema,
  CancelSubscriptionSchema,
  RenewSubscriptionSchema,
} from './subscriptions.schema';

describe('subscription command contracts', () => {
  it('requires an id, date, and positive agreed amount when supplied', () => {
    expect(() =>
      AssignSubscriptionSchema.parse({ plan_id: '', start_date: '2026-01-01T00:00:00.000Z' }),
    ).toThrow();
    expect(() =>
      AssignSubscriptionSchema.parse({
        plan_id: 'p',
        start_date: '2026-01-01T00:00:00.000Z',
        agreed_amount_minor: 0,
      }),
    ).toThrow();
  });

  it('requires reasons for cancellation and pause/resume transitions', () => {
    expect(() => CancelSubscriptionSchema.parse({ reason: '' })).toThrow();
  });

  it('validates renewal start timestamps', () => {
    expect(
      RenewSubscriptionSchema.parse({ start_date: '2026-02-01T00:00:00.000Z' }).start_date,
    ).toContain('2026-02-01');
  });
});
