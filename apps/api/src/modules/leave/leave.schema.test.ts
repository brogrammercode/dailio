import { describe, expect, it } from 'vitest';

import { CreateLeaveRequestSchema } from './leave.schema';

describe('leave request schema', () => {
  it('accepts date-only requests with an idempotency key', () => {
    expect(
      CreateLeaveRequestSchema.parse({
        start_date: '2026-10-01',
        end_date: '2026-10-02',
        idempotency_key: 'leave-test-001',
      }),
    ).toEqual({
      start_date: '2026-10-01',
      end_date: '2026-10-02',
      idempotency_key: 'leave-test-001',
    });
  });

  it('rejects timestamps and underspecified idempotency keys', () => {
    expect(() =>
      CreateLeaveRequestSchema.parse({
        start_date: '2026-10-01T00:00:00Z',
        end_date: '2026-10-02',
      }),
    ).toThrow();
    expect(() =>
      CreateLeaveRequestSchema.parse({
        start_date: '2026-10-01',
        end_date: '2026-10-02',
        idempotency_key: 'short',
      }),
    ).toThrow();
  });
});
