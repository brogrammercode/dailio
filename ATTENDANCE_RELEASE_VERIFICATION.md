# Dailio Attendance Release Verification

This runbook is the final release gate for the attendance milestone. It must
be executed against a disposable/staging organization and branch, never a
production tenant.

## Automated checks

Run from `apps/api`:

```powershell
npm run type-check
npm test -- --run
npm run build
npx prisma migrate status
npm run lint
npx eslint scripts --max-warnings 0
$env:RUN_ATTENDANCE_ACCEPTANCE_CHECK='true'; npx tsx scripts/attendance-acceptance-check.ts
```

Run from `apps/mobile`:

```powershell
dart format --output=none lib
flutter analyze
flutter test
```

The repository-wide API source lint command is expected to pass. The guarded
release scripts under `apps/api/scripts` are linted separately because the
production build excludes them.

## Staging data

Create two organizations and two branches with:

- one owner, one admin, one manager, two managed members, and one inactive member;
- branch-default, role, secondary-role, and direct-member policies;
- one permanent branch QR, one revoked QR, and one QR from the other tenant;
- one assigned shift with a geofence and one member without a shift.

Keep the identifiers private to the staging run. Do not log QR raw tokens,
selfies, exact coordinates, device metadata, or access tokens.

## Required scenarios

| ID   | Scenario                                             | Expected result                                                                               |
| ---- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| P-01 | Member with only branch default loads self policy    | Branch policy, source, version, effective date, timezone, and requirements are shown.         |
| P-02 | Member with active role policy loads self policy     | Role policy wins over branch default.                                                         |
| P-03 | Member with two roles loads self policy              | Lower priority value wins deterministically; changing priority changes only future punches.   |
| P-04 | Direct member policy is assigned                     | Direct policy wins over every role/default policy.                                            |
| P-05 | Future policy version is scheduled                   | Current punches keep the current policy until the effective timestamp.                        |
| A-01 | Valid manual clock-in and clock-out                  | One server-confirmed session, server timeline, audit entries, and correct duration.           |
| A-02 | Missing required selfie/location or invalid accuracy | Server rejects the command; no session is created/closed; a safe retry is possible.           |
| A-03 | Outside geofence or shift window                     | Server rejects with structured reason; precise coordinates never appear in response/logs.     |
| A-04 | Client submits a stale policy version                | `409` stale-policy response; UI refreshes policy before retry.                                |
| A-05 | Authorized manager creates a manual record             | Manual policy allowance, `ATTENDANCE_CREATE_ALL`, reason, timestamp ordering, idempotency, `ADMIN`/`MANUAL` state, audit, and one-open-session rules are enforced; offline enablement is rejected. |
| Q-01 | Active member scans live permanent gate QR           | Server derives clock-in/clock-out; client cannot select the action.                           |
| Q-02 | Same QR image is selected from gallery               | Branch discovery may resolve, but attendance punch is refused until a live camera scan.       |
| Q-03 | Non-member/pending/inactive member scans QR          | Joinable, pending, or forbidden state is shown; no attendance session is created.             |
| Q-04 | Revoked or other-tenant QR is scanned                | Resolution/punch is rejected without leaking branch/tenant data.                              |
| Q-05 | Same idempotency key is retried                      | Same server result is returned; no duplicate session/evidence/audit transition.               |
| S-01 | Manager opens team attendance                        | Own subtree only; unrelated branch members are absent.                                        |
| S-02 | Member opens attendance/payment detail by another ID | `403`/not-found behavior; no private evidence or financial data leaks.                        |
| S-03 | Owner/admin exports attendance                       | Export is branch-scoped, permission checked, and audit logged.                                |
| O-01 | Session exceeds maximum open duration                | Deduplicated missing-clock-out notification is created/pushed; session remains auditable.     |
| O-02 | Late/incomplete/evidence failure occurs              | Appropriate deduplicated alert appears in the notification inbox.                             |
| R-01 | Correct a session twice concurrently                 | One correction version wins; the other receives a conflict; original evidence remains intact. |
| R-02 | Run retention job on expired evidence                | Private asset is deleted first; sensitive fields are purged; attendance summary remains.      |

## Concurrency checks

Send two identical manual clock-in requests and two identical QR punch
requests at the same time with the same and different idempotency keys. Verify
the database contains at most one open session per member and that retries
return the original result or a structured conflict. Repeat for simultaneous
clock-out and correction requests.

The repository also includes a guarded staging harness for the database portion
of this check. It creates uniquely prefixed disposable records, verifies the
one-open-session and idempotent close invariants, then cleans those records up:

```powershell
$env:RUN_ATTENDANCE_CONCURRENCY_CHECK = 'true'
npx tsx scripts/attendance-concurrency-check.ts
$status = $LASTEXITCODE
Remove-Item Env:RUN_ATTENDANCE_CONCURRENCY_CHECK
if ($status -ne 0) { exit $status }
```

Run it only against a disposable staging database. The script refuses to run
unless the explicit opt-in environment variable is set.

The complete server-side vertical flow has a separate guarded check:

```powershell
$env:RUN_ATTENDANCE_FLOW_CHECK = 'true'
npx tsx scripts/attendance-flow-check.ts
$status = $LASTEXITCODE
Remove-Item Env:RUN_ATTENDANCE_FLOW_CHECK
if ($status -ne 0) { exit $status }
```

It verifies direct-member policy resolution, manual clock-in, server-derived
permanent-QR clock-out, authorized timeline data, and append-only correction,
then removes its generated records.

The retention path has a separate guarded check. It creates one disposable
expired selfie in the configured private Cloudinary account, runs the retention
job, verifies the object is deleted before the sensitive database fields and
asset reference are purged, and removes any remaining staging records:

```powershell
$env:RUN_ATTENDANCE_RETENTION_CHECK = 'true'
npx tsx scripts/attendance-retention-check.ts
$status = $LASTEXITCODE
Remove-Item Env:RUN_ATTENDANCE_RETENTION_CHECK
if ($status -ne 0) { exit $status }
```

Run it only against a disposable staging database and storage account. The
script refuses to run without the explicit opt-in environment variable.

Run the guarded PostgreSQL harnesses sequentially rather than concurrently.
Each harness uses serializable transactions; parallel harnesses can create
unrelated staging write conflicts even when their generated records are unique.

The internal implementation security review is recorded in
[ATTENDANCE_SECURITY_REVIEW.md](ATTENDANCE_SECURITY_REVIEW.md). It does not
replace the independent reviewer sign-off below.

## Sign-off

- [x] Automated API checks pass (92 tests across 27 files; type-check, build, migration status, repository-wide source lint, and release-script lint also pass).
- [x] Automated mobile checks pass (16 attendance, QR, policy, fee, and branch-timezone tests; Flutter analysis clean).
- [x] Android emulator startup smoke pass on `dailio_api37`: debug APK built,
      installed, launched to the Dailio login UI, initialized Firebase and
      geolocation, and returned the expected unauthenticated API response
      without a fatal startup exception. Fresh-install camera/location runtime
      permissions were verified in the merged APK and granted on the emulator;
      physical camera/location behavior remains unverified.
- [x] Built API runtime smoke pass: `dist` started successfully, startup
      maintenance initialized, `/api/v1/health` returned HTTP 200, and graceful
      shutdown completed.
- [x] API health exposes safe attendance-maintenance status; live smoke showed
      retention and open-session review succeeded with zero consecutive failures.
- [x] Guarded PostgreSQL concurrency harness passes against `dailio_test` and cleans up generated staging records.
- [x] Guarded cross-branch/cross-tenant command checks reject foreign session and QR identifiers.
- [x] Guarded acceptance matrix passes against `dailio_test`: policy scopes and effective dates, manual evidence/geofence enforcement, server-derived QR action and replay, pending/inactive/revoked/cross-tenant QR handling, manager/self isolation, audited export, and deduplicated/sanitized notifications.
- [x] Guarded server-flow harness passes policy precedence → manual punch → permanent QR punch → timeline → correction.
- [ ] P-01 through P-05 pass.
- [ ] A-01 through A-04 pass.
- [ ] Q-01 through Q-05 pass on physical Android/iOS devices.
- [ ] S-01 through S-03 pass with two tenants and two branches.
- [ ] O-01 through O-02 pass with notification delivery configured and disabled.
- [x] R-01 concurrent correction conflict preserves one correction winner and append-only history (guarded PostgreSQL flow check).
- [x] R-02 retention run passes against configured private storage with recovery evidence (guarded Cloudinary/PostgreSQL check plus deletion-failure unit coverage).
- [ ] Security/privacy reviewer confirms logs, responses, storage, and permissions.
- [ ] Product owner signs off before marking the master plan 100%.

Operational note: the API runs attendance retention once at startup and then
daily, while the open-session review runs once at startup and every 15 minutes.
Production deployment must still monitor non-2xx responses from `/api/v1/health`,
failed maintenance passes, and confirm the configured schedule with the operator.
