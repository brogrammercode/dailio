import { describe, expect, it } from 'vitest';

import { CreateHolidaySchema, UpdateHolidaySchema } from './holidays.schema';

describe('holiday contracts', () => {
  it('accepts a date range and idempotency key', () => {
    expect(
      CreateHolidaySchema.parse({
        name: 'Holi',
        date: '2026-03-03',
        end_date: '2026-03-04',
        idempotency_key: 'holiday-2026-holi',
      }),
    ).toMatchObject({ name: 'Holi', date: '2026-03-03', end_date: '2026-03-04' });
  });

  it('rejects timestamps and empty names', () => {
    expect(() => CreateHolidaySchema.parse({ name: '', date: '2026-01-01' })).toThrow();
    expect(() =>
      CreateHolidaySchema.parse({ name: 'Holiday', date: '2026-01-01T00:00:00Z' }),
    ).toThrow();
  });

  it('accepts non-contiguous dates and recurring weekdays', () => {
    expect(
      CreateHolidaySchema.parse({
        name: 'Weekly closure',
        dates: ['2026-11-08', '2026-11-10', '2026-11-12'],
        recurring_weekdays: [2, 7],
      }),
    ).toMatchObject({
      dates: ['2026-11-08', '2026-11-10', '2026-11-12'],
      recurring_weekdays: [2, 7],
    });
  });

  it('requires a date or recurring weekday', () => {
    expect(() => CreateHolidaySchema.parse({ name: 'Empty' })).toThrow();
  });

  it('allows clearing an existing end date during update', () => {
    expect(UpdateHolidaySchema.parse({ end_date: null })).toEqual({ end_date: null });
  });
});
