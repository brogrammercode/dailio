# Attendance evidence retention

Dailio treats attendance selfies, precise coordinates, device metadata, and IP evidence as sensitive data.

- `ATTENDANCE_EVIDENCE_RETENTION_DAYS` controls retention and defaults to **90 days**.
- A batched retention pass runs once at API startup and then daily in the API process.
- `/api/v1/health` exposes only aggregate maintenance state (`starting`, `ok`, or
  `degraded`), timestamps, failure counters, and batch counts; it never exposes
  raw errors, private evidence, tenant identifiers, or storage credentials. It
  returns HTTP 503 when maintenance is degraded so deployment monitoring can
  alert.
- Expired authenticated selfie assets are deleted from private object storage first. If storage deletion fails, the database reference is retained for retry.
- After successful asset deletion (or for location-only evidence), precise latitude/longitude, device metadata, and IP address are cleared from `attendance_evidence`.
- Attendance sessions, correction history, derived geofence distance, status, timestamps, policy snapshots, and audit records remain available for operational and audit history.
- The cleanup is idempotent and safe to run from multiple API instances; each pass only processes records that still contain sensitive fields.

Before production deployment, the organization must confirm that this default satisfies its consent, contractual, and legal retention obligations. A longer period must be an explicit configuration decision, not a client-controlled value.

Production monitoring should alert on a non-2xx health response, a degraded
maintenance status, or a growing failure count.
