import { describe, expect, it } from 'vitest';

import { calculateOutstandingBalance, deriveFeeStatus, getPeriod } from './payments.service';

describe('fee period calculation', () => {
  it('returns the current UTC month by default', () => {
    const period = getPeriod({ period: 'this_month', page: 1, limit: 50 });
    expect(period.start.getUTCDate()).toBe(1);
    expect(period.end.getUTCMonth()).toBe(period.start.getUTCMonth());
    expect(period.end.getUTCHours()).toBe(23);
  });

  it('supports a validated custom date range', () => {
    const period = getPeriod({
      period: 'custom',
      from: '2026-01-10',
      to: '2026-01-12',
      page: 1,
      limit: 50,
    });
    expect(period.start.toISOString()).toBe('2026-01-10T00:00:00.000Z');
    expect(period.end.toISOString()).toBe('2026-01-12T23:59:59.999Z');
  });

  it('rejects an incomplete or reversed custom range', () => {
    expect(() => getPeriod({ period: 'custom', page: 1, limit: 50 })).toThrow();
    expect(() =>
      getPeriod({ period: 'custom', from: '2026-01-12', to: '2026-01-10', page: 1, limit: 50 }),
    ).toThrow();
  });

  it('calculates partial and over-credited balances without going negative', () => {
    expect(
      calculateOutstandingBalance([
        { amount_minor_unit: 10000 },
        { amount_minor_unit: 1000 },
        { amount_minor_unit: -5000 },
      ]),
    ).toBe(6000);
    expect(calculateOutstandingBalance([{ amount_minor_unit: -100 }])).toBe(0);
  });

  it('derives urgency and payment states from server-side facts', () => {
    const base = { hasSubscription: true, warningDays: 7, hasConfirmedPayment: false };
    expect(
      deriveFeeStatus({
        ...base,
        hasPendingRequest: true,
        remainingDays: 20,
        balanceMinorUnit: 100,
      }),
    ).toBe('REQUESTED');
    expect(
      deriveFeeStatus({
        ...base,
        hasPendingRequest: false,
        remainingDays: -1,
        balanceMinorUnit: 0,
      }),
    ).toBe('EXPIRED');
    expect(
      deriveFeeStatus({ ...base, hasPendingRequest: false, remainingDays: 5, balanceMinorUnit: 0 }),
    ).toBe('EXPIRING_SOON');
    expect(
      deriveFeeStatus({
        ...base,
        hasPendingRequest: false,
        remainingDays: 20,
        balanceMinorUnit: 500,
        hasConfirmedPayment: true,
      }),
    ).toBe('PARTIALLY_PAID');
    expect(
      deriveFeeStatus({
        ...base,
        hasPendingRequest: false,
        remainingDays: 20,
        balanceMinorUnit: 0,
      }),
    ).toBe('PAID');
  });
});
