import { describe, expect, it } from 'vitest';
import { extractTokenFromQrValue } from './qr';

describe('web QR payloads', () => {
  it('reads the HTTPS fragment payload used by new printed codes', () => {
    expect(extractTokenFromQrValue('https://web.example.com/invite#token=opaque-token-1234567890')).toBe('opaque-token-1234567890');
  });

  it('keeps legacy mobile deep links compatible', () => {
    expect(extractTokenFromQrValue('dailio://invite?token=opaque-token-1234567890')).toBe('opaque-token-1234567890');
  });

  it('rejects unrelated URLs', () => {
    expect(extractTokenFromQrValue('https://example.com/?token=opaque-token-1234567890')).toBeNull();
  });
});
