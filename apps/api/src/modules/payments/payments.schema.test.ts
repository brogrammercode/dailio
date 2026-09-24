import { describe, expect, it } from 'vitest';

import { CreatePaymentRequestSchema, FeeQuerySchema } from './payments.schema';

describe('payment request contracts', () => {
  it('normalizes currency and defaults evidence', () => {
    const parsed = CreatePaymentRequestSchema.parse({
      subscription_id: 'sub-1',
      amount_minor_unit: 1000,
      currency: 'inr',
      method: 'UPI',
    });
    expect(parsed.currency).toBe('INR');
    expect(parsed.evidence).toEqual([]);
  });

  it('rejects zero or negative payment amounts', () => {
    expect(() =>
      CreatePaymentRequestSchema.parse({
        subscription_id: 'sub-1',
        amount_minor_unit: 0,
        method: 'CASH',
      }),
    ).toThrow();
  });

  it('coerces fee pagination and accepts custom periods', () => {
    const parsed = FeeQuerySchema.parse({
      period: 'custom',
      from: '2026-01-01',
      to: '2026-01-31',
      page: '2',
      limit: '25',
    });
    expect(parsed.page).toBe(2);
    expect(parsed.limit).toBe(25);
  });
});
