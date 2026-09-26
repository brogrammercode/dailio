import { describe, expect, it } from 'vitest';

import {
  ClockInSchema,
  CorrectSessionSchema,
  CreateManualSessionSchema,
  ListSessionsQuerySchema,
  QrPunchSchema,
  UpdatePolicySchema,
} from './attendance.schema';

describe('attendance command contracts', () => {
  it('requires idempotency for manual clock-in and accepts evidence metadata', () => {
    expect(() => ClockInSchema.parse({ body: {} })).toThrow();

    const parsed = ClockInSchema.parse({
      body: {
        idempotency_key: 'clock-in-123456',
        latitude: 28.61,
        longitude: 77.21,
        accuracy: 8,
        selfie_storage_key: 'organizations/org-1/attendance-selfies/photo',
      },
    });

    expect(parsed.body.idempotency_key).toBe('clock-in-123456');
    expect(parsed.body.timezone).toBe('UTC');
  });

  it('requires a QR token in the punch body while keeping the action server-derived', () => {
    expect(() => QrPunchSchema.parse({ body: { token: 'too-short' } })).toThrow();
    expect(
      QrPunchSchema.parse({
        body: { token: 'a'.repeat(32), latitude: 28.61, longitude: 77.21 },
      }).body,
    ).toMatchObject({ token: 'a'.repeat(32), timezone: 'UTC' });
  });

  it('rejects empty or reversed attendance corrections', () => {
    expect(() =>
      CorrectSessionSchema.parse({
        body: { correction_reason: 'No values' },
      }),
    ).toThrow('At least one attendance value must be corrected');

    expect(() =>
      CorrectSessionSchema.parse({
        body: {
          correction_reason: 'Fix reversed timestamps',
          clock_in_at: '2026-09-26T12:00:00.000Z',
          clock_out_at: '2026-09-26T11:00:00.000Z',
        },
      }),
    ).toThrow('Clock-out must be after clock-in');
  });

  it('validates custom local-date ranges and supports year filtering', () => {
    expect(() => ListSessionsQuerySchema.parse({ query: { period: 'custom' } })).toThrow(
      'Custom attendance periods require date_from and date_to',
    );
    expect(
      ListSessionsQuerySchema.parse({
        query: {
          period: 'custom',
          date_from: '2026-09-01',
          date_to: '2026-09-26',
        },
      }).query.limit,
    ).toBe(50);
    expect(ListSessionsQuerySchema.parse({ query: { period: 'this_year' } }).query.period).toBe(
      'this_year',
    );
  });

  it('requires a reason for manual records and keeps offline capture disabled', () => {
    expect(() =>
      CreateManualSessionSchema.parse({
        body: {
          member_id: 'member-1',
          clock_in_at: '2026-09-26T08:00:00.000Z',
          reason: 'No',
        },
      }),
    ).toThrow();
    expect(() =>
      UpdatePolicySchema.parse({
        body: { allow_offline_capture: true },
      }),
    ).toThrow();
  });
});
