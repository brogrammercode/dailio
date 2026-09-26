import { describe, expect, it } from 'vitest';

import { redactSensitiveRequestUrl } from './requestLog';

describe('request log redaction', () => {
  it('redacts bearer QR tokens while preserving route context', () => {
    const url = '/api/v1/invites/secret-permanent-token?source=scanner';

    expect(redactSensitiveRequestUrl(url)).toBe('/api/v1/invites/[redacted]?source=scanner');
  });

  it('redacts token segments for join and purchase flows', () => {
    expect(redactSensitiveRequestUrl('/api/v1/join-invites/join-secret/requests')).toBe(
      '/api/v1/join-invites/[redacted]/requests',
    );
    expect(
      redactSensitiveRequestUrl('/api/v1/purchase-invites/plan-secret/subscription-drafts'),
    ).toBe('/api/v1/purchase-invites/[redacted]/subscription-drafts');
  });

  it('redacts credential-bearing query parameters', () => {
    expect(
      redactSensitiveRequestUrl('/api/v1/upload?token=secret&source=mobile&signature=private'),
    ).toBe('/api/v1/upload?token=[redacted]&source=mobile&signature=[redacted]');
  });
});
