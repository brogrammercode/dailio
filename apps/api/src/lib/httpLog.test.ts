import { describe, expect, it } from 'vitest';

import { formatHttpResponseLog, istTime, safeHttpPath, safeHttpPayload } from './httpLog';

describe('HTTP console logging', () => {
  it('formats timestamps in Indian Standard Time', () => {
    expect(istTime(new Date('2026-09-26T17:32:14.320Z'))).toBe('23:02:14.320 IST');
  });

  it('keeps only the route and redacts credentials and personal data', () => {
    expect(safeHttpPath('http://localhost:3000/api/v1/invites/raw?token=secret')).toBe(
      '/api/v1/invites/[redacted]?token=[redacted]',
    );

    const payload = safeHttpPayload({
      email: 'person@example.com',
      access_token: 'secret',
      latitude: 19.1,
      organization_id: 'org-1',
    });
    expect(payload).not.toContain('person@example.com');
    expect(payload).not.toContain('secret');
    expect(payload).not.toContain('19.1');
    expect(payload).toContain('org-1');
    expect(payload).toContain('[REDACTED]');
  });

  it('logs response status without serializing the response body', () => {
    const line = formatHttpResponseLog({
      time: '23:02:14.320 IST',
      speed: '12ms',
      method: 'GET',
      status: 200,
      path: '/api/v1/health',
    });

    expect(line).toContain('✅');
    expect(line).toContain('[200]');
    expect(line).toContain('[/api/v1/health]');
    expect(line).not.toContain('{');
    expect(line).not.toContain('response');
  });
});
