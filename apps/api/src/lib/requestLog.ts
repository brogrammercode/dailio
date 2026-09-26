/**
 * QR invite tokens are bearer credentials and must never be copied into
 * access logs. Keep the route shape useful for debugging while replacing the
 * credential-bearing path segment.
 */
export function redactSensitiveRequestUrl(value: string) {
  const redactedPath = value.replace(
    /\/(?:invites|join-invites|purchase-invites)\/[^/?#\s]+/g,
    (match) => `${match.slice(0, match.lastIndexOf('/'))}/[redacted]`,
  );

  return redactedPath.replace(
    /([?&](?:token|access_token|refresh_token|authorization|password|secret|signature|api_key|key|credential|security_token)=)[^&#\s]*/gi,
    '$1[redacted]',
  );
}
