import { describe, expect, it } from 'vitest';

import { CreateInviteSchema, CreateSubscriptionDraftSchema } from './invites.schema';
import { createOpaqueInviteToken, hashInviteToken } from './invites.service';

describe('invite contracts and token handling', () => {
  it('defaults invite expiry and rejects unsafe durations', () => {
    expect(CreateInviteSchema.parse({}).expires_in_hours).toBe(24);
    expect(() => CreateInviteSchema.parse({ expires_in_hours: 0 })).toThrow();
    expect(() => CreateInviteSchema.parse({ expires_in_hours: 721 })).toThrow();
  });

  it('uses an opaque token and stores a deterministic one-way hash', () => {
    const token = createOpaqueInviteToken();
    expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(hashInviteToken(token)).toHaveLength(64);
    expect(hashInviteToken(token)).toBe(hashInviteToken(token));
    expect(hashInviteToken(token)).not.toBe(token);
  });

  it('requires an ISO timestamp for a subscription draft', () => {
    expect(() => CreateSubscriptionDraftSchema.parse({ start_date: 'today' })).toThrow();
    expect(CreateSubscriptionDraftSchema.parse({ start_date: '2026-09-25T00:00:00.000Z' })).toEqual(
      { start_date: '2026-09-25T00:00:00.000Z' },
    );
  });
});
