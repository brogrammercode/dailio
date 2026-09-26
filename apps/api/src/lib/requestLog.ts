/**
 * QR invite tokens are bearer credentials and must never be copied into
 * access logs. Keep the route shape useful for debugging while replacing the
 * credential-bearing path segment.
 */
export function redactSensitiveRequestUrl(value: string) {
  return value.replace(
    /\/(?:invites|join-invites|purchase-invites)\/[^/?#\s]+/g,
    (match) => `${match.slice(0, match.lastIndexOf('/'))}/[redacted]`,
  );
}
