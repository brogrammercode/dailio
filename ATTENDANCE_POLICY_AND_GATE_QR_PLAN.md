# Dailio Attendance Policy + Permanent Gate QR Completion Plan

Status: **In progress — production flow implemented; release verification remains**

Owner: Product/Engineering  
Last reviewed: 2026-09-26

This is the master execution document for the next attendance milestone. Every task is independently checkable. A track is complete only when its API, authorization, UI, audit behavior, and tests are complete.

## 1. Direct answer: what exists today

The requested people/role policy and permanent gate-QR attendance vertical slice is implemented and database-backed.

What exists now:

- Versioned branch-default, role-targeted, and member-targeted policies with effective ranges and deterministic resolution.
- Server-side enforcement for evidence, geofence, shift days/windows, grace, minimum/maximum session duration, and idempotent state transitions.
- Private selfie upload/association, sanitized evidence responses, signed authorized viewing, and derived geofence distance summaries.
- Immutable correction history with actor, reason, before/after values, version, and audit log.
- Permanent branch QR handling for join, pending, active-member server-derived clock-in/clock-out, revocation, and rate limiting.
- Mobile self-attendance, gate confirmation, branch-local history filters, policy/version history, server time/shift context, and server-built detail timelines.
- Authorized manager manual-record creation when the resolved policy allows it, with an explicit reason, `ADMIN` source, `MANUAL` status, idempotency, and audit history.
- Offline attendance capture remains explicitly disabled and cannot be enabled through the policy API until tamper-evident server synchronization is implemented.

What remains incomplete:

- Physical Android/iOS UI and permission verification for camera, gallery, selfie, and location flows.
- Production retention scheduling/alerting confirmation and independent security/privacy review.

## 2. Product behavior to deliver

### 2.1 Policy scope and precedence

Attendance applies to every active branch member: customer/member, employee, staff, manager, or owner membership where attendance is enabled.

Policy precedence is deterministic:

`direct member policy → effective role policy → branch default policy`

If a person has multiple roles, the system must resolve the role policy using an explicit priority/effective assignment, not role-name ordering. The resolved policy, source scope, version, and effective timestamp are shown to the person and snapshotted onto the attendance session.

### 2.2 Policy assignment flow

1. Owner/admin opens Settings → Attendance policies.
2. They create or edit a versioned policy definition.
3. They assign it as the branch default, to a role, or directly to one or more members.
4. The server validates that every target belongs to the selected organization/branch and that the actor has the policy-management permission.
5. The member configuration page can open the member’s effective policy and create a direct override when authorized.
6. The member’s self-attendance page loads the resolved policy for the active branch and clearly explains why each requirement applies.
7. Changing a policy creates a new effective version. Existing sessions retain their original policy snapshot.

### 2.3 Manual self attendance flow

1. Load branch timezone, server time, effective member policy, effective shift, and current session.
2. Show the exact next action: Clock In or Clock Out.
3. Show requirements before the action: live selfie, live location, geofence, confirmation, shift window, grace, and any reason/warning.
4. Collect required evidence.
5. Submit one idempotent command.
6. The server validates membership, permission, policy version, evidence freshness, geofence, shift rules, open-session invariant, and server transition state.
7. Show a pending state until the server responds.
8. On success, show the confirmed timeline: action requested, evidence captured, server confirmation, status/variance, and next action.
9. On failure, show the reason and allow a safe retry without creating a duplicate session.

### 2.4 Permanent gate QR flow

The existing permanent branch join QR is also the physical gate QR. The owner prints it and posts it at the entrance. It remains reusable until explicitly revoked or replaced.

1. A signed-in person scans the gate QR.
2. The server resolves the opaque token and branch.
3. Non-member: show the existing branch preview and fast-join confirmation/request flow.
4. Pending member: show the pending request state.
5. Active member: server determines the next action from current state. No open session means Clock In; an open session means Clock Out. The client cannot choose an action by changing a request body.
6. The app loads the resolved member policy and shift and shows the action, required evidence, geofence requirement, and any warning.
7. After confirmation, the app captures required live evidence and sends an idempotent QR-punch command.
8. The server validates the permanent branch invite, active membership, branch scope, policy, evidence, geofence, and state transition.
9. The server records `QR_GATE` as the attendance source and creates/closes the session.
10. The app shows the confirmed result and timeline. Repeated scans are safe and show the next server-determined action.

### 2.5 Authorized manual record flow

1. An authorized manager enables `Allow manager manual records` on the applicable branch, role, or member policy.
2. The manager opens Attendance and selects an active member, attendance times, and a mandatory reason.
3. The client submits one idempotent manual-record command; it cannot set the tenant, branch, actor, or effective policy.
4. The server validates `ATTENDANCE_CREATE_ALL`, active membership, policy version, manual-entry allowance, timestamp ordering, and the one-open-session invariant.
5. The server creates an `ADMIN`/`MANUAL` record and immutable audit event. No selfie or location is inferred for a manual record.
6. If offline capture is requested, the policy command is rejected because offline synchronization safeguards are not implemented.

Gallery QR selection can still help resolve a branch for discovery, but a gate punch must use the configured anti-spoof controls. If the organization requires a physical gate presence, QR-punch must require a live camera scan plus geofence/evidence; a saved QR image alone must never bypass those controls.

## 3. Target technical design

### 3.1 Database and migration

Use additive migrations only.

- Extend policy scope so a version can target exactly one of:
  - branch default (`member_id = null`, `role_id = null`);
  - role (`role_id` set, `member_id = null`);
  - direct member (`member_id` set, `role_id = null`).
- Add the member relation/index to `AttendancePolicy` and a database check constraint preventing ambiguous dual targets.
- Add effective-from/effective-to support or an explicit active assignment record so future-dated policy changes are safe.
- Add a partial uniqueness rule for one active policy assignment per scope/branch.
- Add `QR_GATE` to the attendance source enum, or an equivalent immutable source field if the existing enum must remain compatible.
- Snapshot on each session: policy id/version/scope, branch timezone, shift snapshot, source, and resolved evidence requirements.
- Preserve existing branch policy rows as branch defaults during migration.
- Do not store raw QR tokens. Existing hash/revocation behavior remains mandatory.

### 3.2 Backend API contract

Add or evolve these contracts:

- `GET /branches/:branch_id/attendance/policies` — authorized policy definitions/assignments with affected-member counts.
- `PATCH /branches/:branch_id/attendance/policy` — create the next version or update a branch, role, or member assignment through one validated command.
- `GET /branches/:branch_id/attendance/policy` — self effective policy by default; authorized `member_id` lookup for staff/team scope.
- `GET /invites/:token` — include `attendance_action`, `active_membership`, effective policy summary, and active-session state for a branch QR.
- `POST /attendance/qr-punch` or `/branches/:branch_id/attendance/qr-punch` — resolve token server-side and perform the next transition atomically.
- `POST /branches/:branch_id/attendance/manual` — authorized, policy-enabled manager record with mandatory reason and idempotency.
- `POST /branches/:branch_id/attendance/evidence/upload-signature` — private selfie signature using the existing media pattern.
- `GET /branches/:branch_id/attendance/:session_id` — detail with authorized evidence/timeline/source.

All commands require an `Idempotency-Key`. The server derives organization, branch, member, role, policy, and action from authenticated state and the verified invite; none may be trusted from the client payload.

### 3.3 Authorization

Use atomic permissions, not role display names:

- `ATTENDANCE_POLICY_READ`
- `ATTENDANCE_POLICY_MANAGE`
- `ATTENDANCE_POLICY_ASSIGN`
- `ATTENDANCE_READ_SELF`
- `ATTENDANCE_READ_TEAM`
- `ATTENDANCE_READ_ALL`
- `ATTENDANCE_CREATE_SELF`
- `ATTENDANCE_CREATE_ALL` where explicitly needed
- `ATTENDANCE_EVIDENCE_READ_SELF`
- `ATTENDANCE_EVIDENCE_READ_ALL`

The server must enforce self/team/branch scope, active membership, branch ownership, and cross-tenant isolation on every policy, evidence, invite, and session query.

## 4. Tracked execution plan

### Track A — Policy domain and migration

- [x] A1. Add member-targeted policy scope to Prisma/schema.
  - [x] Add `member_id` relation/index.
  - [x] Add exact-one-scope database constraint.
  - [x] Add active/effective assignment uniqueness.
  - [x] Add `QR_GATE` attendance source.
- [x] A2. Create additive migration and backfill existing branch policies as default scope.
  - [x] Validate existing rows before migration.
  - [x] Add rollback/recovery notes.
  - [x] Run migration against the configured database.
- [x] A3. Implement deterministic resolver: member override → role → branch default.
  - [x] Validate effective dates/timezone.
  - [x] Resolve multiple roles by explicit assignment priority through effective-dated branch role assignments; legacy `role_id` remains a fallback projection.
  - [x] Return source scope, policy id, version, and effective timestamp.
- [x] A4. Snapshot resolved policy and branch timezone on every session.
- [x] A5. Add unit/contract tests for precedence, effective-date constraints, and invalid ranges.

### Track B — Policy backend and authorization

- [x] B1. Add policy list/create/version/assign services.
- [x] B2. Validate role/member targets belong to the requested organization and branch.
- [x] B3. Add policy-management permissions to the canonical catalog and protected owner/admin defaults.
- [x] B4. Add self effective-policy endpoint without allowing a member to target another member.
- [x] B5. Add authorized manager target lookup with team/branch scope. Reporting relationships are branch-scoped, cycle-checked, and team traversal is server-enforced.
- [x] B6. Add audit events for policy creation/versioning.
- [x] B7. Add API tests for forbidden cross-tenant/foreign-role/member assignments.

### Track C — Policy management UI

- [x] C1. Replace the branch-only Attendance Policy screen with policy definitions and assignments.
  - [x] Branch default editor.
  - [x] Role policy editor.
  - [x] Member override editor.
  - [x] Effective-date/version history.
  - [x] Preview of who will be affected using active branch membership counts.
- [x] C2. Replace Configure Member’s static “Policy Overrides” toggles with a real effective-policy entry point.
  - [x] Show that assignment is managed by policy scope.
  - [x] Add direct override navigation.
  - [x] Show save/error states.
  - [x] Remove unsupported fake controls.
- [x] C3. Add permission-aware empty, forbidden, loading, retry, and conflict states.
- [x] C4. Add confirmation for changes that affect future punches.
- [x] C5. Add widget tests for branch/role/member assignment visibility.
- [x] C6. Expose the manual-record allowance in policy management and keep unsupported offline capture unavailable.

### Track D — Policy enforcement engine

- [x] D1. Enforce required punch/evidence/confirmation server-side.
- [x] D2. Implement live selfie capture and private asset association.
- [x] D3. Validate GPS accuracy, branch geofence distance, and branch timezone.
- [x] D4. Implement shift window, late grace, early leave, and minimum session rules.
- [x] D5. Calculate authoritative derived status and late/early minutes.
- [x] D6. Return structured validation results so the UI can explain exactly what failed.
- [x] D7. Make open-session and idempotency transitions concurrency-safe.
- [x] D8. Add stale policy-version conflict handling and safe refresh/retry behavior.
- [x] D9. Add API/unit/concurrency tests for each enforcement rule. Rule-specific contract/service coverage now includes stale policy, selfie/location requirements, geofence distance and accuracy, shift assignment/window, overnight boundaries, minimum/maximum duration, late/early status, replay, and QR behavior; the guarded PostgreSQL harness covers concurrent command transitions.
- [x] D10. Implement policy-controlled manager manual records with explicit permission, reason, `ADMIN`/`MANUAL` state, idempotency, audit, and one-open-session protection.
- [x] D11. Fail closed on `allow_offline_capture`; no client can enable an unsupported offline-confirmation path.

### Track E — Self attendance and timeline

- [x] E1. Show resolved policy source/version/effective date.
- [x] E2. Show the exact next action and all requirements before capture.
- [x] E3. Show synchronized server time and scheduled shift/window.
- [x] E4. Show geofence distance/accuracy result without exposing unnecessary precise coordinates.
- [x] E5. Show pending → confirmed/error punch state.
- [x] E6. Build a real timeline from server events/evidence, not client-generated labels.
  - [x] Session opened/requested.
  - [x] Selfie captured/accepted or rejected.
  - [x] Location captured/accepted or rejected.
  - [x] QR gate resolved when applicable.
  - [x] Server confirmation.
  - [x] Correction/status event.
- [x] E7. Add week/month/year/custom local-date records and server-bounded results.
- [x] E8. Add accessible text/icons in addition to color.
- [x] E9. Add widget/E2E tests for manual clock-in/out and failure states. (Mobile widget coverage now exercises confirmed clock-in, confirmed clock-out, and retryable failure.)

### Track F — Permanent branch gate QR backend

- [x] F1. Extend invite resolution for active members with server-derived `CLOCK_IN`/`CLOCK_OUT` next action.
- [x] F2. Preserve existing non-member fast-join and pending states.
- [x] F3. Add atomic QR-punch command.
  - [x] Verify raw token hash, purpose, active branch, and revocation.
  - [x] Resolve authenticated member in that branch.
  - [x] Resolve effective policy and shift.
  - [x] Derive action from open-session state.
  - [x] Enforce evidence/geofence/policy.
  - [x] Create/close session with `QR_GATE` source.
  - [x] Persist idempotency result and audit event.
- [x] F4. Add rate limiting and abuse controls for invite resolution and QR punches.
- [x] F5. Ensure revoking/replacing the printed QR immediately prevents future punches.
- [x] F6. Add tenant-isolation, replay, revoked-token, inactive-member, duplicate-scan, and concurrent-scan tests. (Unit coverage covers lifecycle and scope cases; the guarded invite-backed concurrency harness passed against `dailio_test`.)

### Track G — Gate QR mobile flow

- [x] G1. Update scanner resolution so active members see “Clock in” or “Clock out at Branch,” not “already a member.”
- [x] G2. Show policy/shift/evidence preview before confirmation.
- [x] G3. Capture required live evidence using the same policy engine as manual punch.
- [x] G4. Send one idempotent QR-punch command and render pending/confirmed/error states.
- [x] G5. Navigate to the confirmed attendance detail/timeline.
- [x] G6. Preserve gallery selection for branch discovery while preventing it from bypassing gate anti-spoof requirements. Gallery-resolved active-member flows require a live camera scan before punch submission; server evidence/geofence requirements remain authoritative.
- [x] G7. Handle camera/location/selfie permissions, revoked QR, offline state, duplicate scan, and branch mismatch professionally. Offline QR resolution/punch is stopped before submission; permission/revocation/state failures are surfaced without optimistic confirmation.
- [x] G8. Add scanner, flow, and widget tests for non-member/pending/member/open-session branches. (Scanner flow-state tests cover joinable/pending/active clock-in/active clock-out; gate widget coverage covers the active gate state and gallery refusal.)

### Track H — Detail, privacy, corrections, and operations

- [x] H1. Add authorized selfie viewer and private location summary.
- [x] H2. Hide precise coordinates, private media URLs, device metadata, and raw token values from unauthorized users/logs.
- [x] H3. Make corrections append-only with original values/evidence preserved.
- [x] H4. Add correction conflict handling and actor/reason/audit history.
- [x] H5. Add ongoing activity, stale refresh indicator, filters, cursor pagination, and authorized export. (The mobile reporting list refreshes every minute and loads additional pages as the user scrolls.)
- [x] H6. Add missing-clock-out, evidence failure/geofence, and incomplete-session notifications with dedupe keys and a scheduled review pass.
- [x] H7. Document and operationalize retention/deletion behavior for selfies and precise locations. See `ATTENDANCE_EVIDENCE_RETENTION.md`.

### Track I — Release gate

- [x] I1. API type-check/build/tests and repository-wide `src` lint pass; guarded release scripts also pass targeted lint.
- [x] I2. Flutter analyze/tests pass.
- [x] I3. Migration deploy/backfill verified against the configured `dailio_test` database.
- [x] I4. End-to-end: assign branch/role/member policy → member sees resolved policy → manual punch → gate QR punch → detail timeline → correction. (Verified by the guarded PostgreSQL server-flow harness; physical-device UI sign-off remains in the runbook.)
- [x] I5. Cross-tenant and cross-branch identifiers are rejected. (Verified by the guarded PostgreSQL harness against `dailio_test` for clock-out and QR-punch commands.)
- [x] I6. Duplicate/concurrent manual and QR punches cannot create duplicate sessions. (Verified by the guarded PostgreSQL concurrency harness against `dailio_test`.)
- [x] I7. Internal engineering security/privacy review completed and recorded in `ATTENDANCE_SECURITY_REVIEW.md`; independent deployment/privacy review remains a release sign-off gate.
- [ ] I8. Update `STATUS_REPORT.md` and mark this plan 100% only after all required checks are green.

Release execution instructions and sign-off evidence are tracked in
`ATTENDANCE_RELEASE_VERIFICATION.md`. These gates remain unchecked until the
staging/device/concurrency run is actually performed.

## 5. Acceptance checklist for “100% complete”

- A member with only a branch default, a role policy, or a direct override sees the correct resolved policy and reason.
- A policy change affects future punches only; an existing session retains its snapshot.
- Server rejects missing/invalid evidence and geofence violations even if the client is modified.
- Manual and gate QR punches produce the same authoritative session behavior.
- A non-member scanning the gate QR is offered fast join; a pending member sees pending; an active member sees the correct next punch.
- Clock-in QR cannot be changed into clock-out by client payload tampering.
- A repeated/concurrent scan is idempotent and never double-punches.
- A manual record is accepted only with explicit permission, policy allowance, valid timestamps, reason, idempotency, and audit; unsupported offline capture is rejected.
- Detail timeline contains server-confirmed events and authorized evidence only.
- Revoking/replacing the permanent QR immediately blocks future resolution/punches.
- All authorization, tenant-isolation, privacy, timezone, concurrency, widget, and E2E checks pass.

## 6. Current progress log

| Date       | Update                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Status                                                                                                                                                |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-26 | Confirmed branch-only policy implementation and static member override controls.                                                                                                                                                                                                                                                                                                                                                                                                                               | Gap confirmed                                                                                                                                         |
| 2026-09-26 | Implemented policy scope migration, member/role/default resolver, management UI, server evidence/geofence/status enforcement, private selfie upload association, active-member gate QR resolution/punching, mobile gate confirmation, and direct Self Attendance scanner entry.                                                                                                                                                                                                                                | Core vertical slice complete; final hardening and release-gate tasks remain                                                                           |
| 2026-09-26 | Added effective policy ranges with a database uniqueness guard, one-open-session-per-member index, serializable attendance transitions, and dedicated QR resolution/punch rate limits. API and Flutter verification passed; broader E2E/security/retention work remains.                                                                                                                                                                                                                                       | Hardening complete for current vertical slice                                                                                                         |
| 2026-09-26 | Added immutable correction history, sanitized server-built timelines, structured validation details, branch-local custom/year history filters, scheduled policy effective dates, policy history UI, shift/server-time context, and attendance unit/contract tests.                                                                                                                                                                                                                                             | Domain/UI hardening complete; E2E, team scope, retention, notifications, and anti-spoof work remain                                                   |
| 2026-09-26 | Added server-derived geofence distance summaries to evidence, kept coordinates/device metadata private, enforced scheduled shift windows, and expanded verification to 29 API tests.                                                                                                                                                                                                                                                                                                                           | Core enforcement and privacy surface hardened; release gates remain                                                                                   |
| 2026-09-26 | Enforced `Idempotency-Key` headers for manual punches and added reviewed policy-version checks so stale evidence submissions fail safely with structured conflict details.                                                                                                                                                                                                                                                                                                                                     | Command contract and stale-state hardening complete                                                                                                   |
| 2026-09-26 | Added audit records for server-confirmed manual and permanent-gate clock-in/clock-out transitions, plus explicit pending/confirmed/error status feedback in Self Attendance and shift context in the gate preview.                                                                                                                                                                                                                                                                                             | Punch traceability and user-visible confirmation hardening complete                                                                                   |
| 2026-09-26 | Added authorized branch-scoped attendance CSV export, minimized member data in attendance responses, and deployed a batched 90-day default evidence-retention pass with private asset deletion and precise-data purge.                                                                                                                                                                                                                                                                                         | Operational export/privacy hardening complete                                                                                                         |
| 2026-09-26 | Added policy-management retry/empty/error handling, prevented saving an unselected role/member target, and verified the ninth additive migration against `dailio_test`.                                                                                                                                                                                                                                                                                                                                        | Management UX and schema deployment verified                                                                                                          |
| 2026-09-26 | Aligned attendance export/correction routes with seeded admin permissions and deployed a backfill migration for existing admin roles.                                                                                                                                                                                                                                                                                                                                                                          | Authorization consistency verified                                                                                                                    |
| 2026-09-26 | Added branch-scoped reporting hierarchy with cycle checks, team/branch attendance scope, authorized target-policy lookup, manager assignment UI, and offline gate/QR safeguards.                                                                                                                                                                                                                                                                                                                               | Team scope and gate failure handling implemented; full E2E verification remains                                                                       |
| 2026-09-26 | Added effective-dated multi-role assignments with explicit priority, backfilled legacy primary roles, updated policy resolution and authorization permission unions, and added role selection to member configuration.                                                                                                                                                                                                                                                                                         | Deterministic multi-role resolution implemented                                                                                                       |
| 2026-09-26 | Added stable cursor pagination to authorized attendance reporting, mobile infinite-scroll loading, live open-session duration, last-sync status, server-authoritative branch timezone snapshots, and deduplicated late/incomplete/missing-clock-out/evidence-failure notifications.                                                                                                                                                                                                                            | Operational reporting and alerting implemented; release verification remains                                                                          |
| 2026-09-26 | Added a user-scoped notification inbox with cursor pagination, individual/read-all actions, and mobile navigation so operational attendance alerts remain visible when push delivery is missed.                                                                                                                                                                                                                                                                                                                | Notification delivery and inbox complete; release verification remains                                                                                |
| 2026-09-26 | Added effective-secondary-role report filtering, direct tenant/branch authorization tests, and QR replay protection that returns an existing member-scoped idempotent result before appending another audit event.                                                                                                                                                                                                                                                                                             | Authorization and replay hardening improved; staging concurrency sign-off remains                                                                     |
| 2026-09-26 | Added a dedicated ESLint TypeScript project so attendance/notification tests are lintable; target lint is clean.                                                                                                                                                                                                                                                                                                                                                                                               | Test-tooling verification improved                                                                                                                    |
| 2026-09-26 | Expanded the automated suite to 51 passing API tests across 15 files, covering effective secondary-role reporting filters, notification user isolation, session tenant/branch query scope, QR idempotent replay, revoked/expired/inactive/member-state invite handling, and server punch rejection for stale policy, missing evidence, geofence, shift, and gate-source cases.                                                                                                                                 | Automated service/contract coverage expanded; physical-device and real-database concurrency sign-off remains                                          |
| 2026-09-26 | Completed policy-management forbidden/error messaging and stale-version refresh behavior; Flutter analyzer and tests remain green.                                                                                                                                                                                                                                                                                                                                                                             | Policy management UX hardening complete; widget/E2E coverage remains                                                                                  |
| 2026-09-26 | Scoped manual clock-in/clock-out idempotency replay lookups and collision recovery to organization, branch, and member, preventing a reused key from disclosing another member's session.                                                                                                                                                                                                                                                                                                                      | Idempotency privacy boundary hardened; staging concurrency sign-off remains                                                                           |
| 2026-09-26 | Final automated verification passed: 41 API tests, API type-check/build, attendance/notification-targeted lint, Flutter analyze/tests, migration status, and diff checks. No Android/iOS device is connected; physical QR/camera/location E2E and real-database concurrency sign-off remain in the release runbook.                                                                                                                                                                                            | Implementation hardening complete; release gate intentionally remains open                                                                            |
| 2026-09-26 | Checked off the automated API/mobile release-runbook gates using the final verification output; all staging, device, concurrency, and human sign-off boxes remain intentionally open.                                                                                                                                                                                                                                                                                                                          | Evidence tracking synchronized                                                                                                                        |
| 2026-09-26 | Corrected gate requirement previews to use action-specific server policy fields and added widget coverage for policy assignment scopes, gallery-QR refusal, and manual self-punch confirmation. Tenant/branch scope was also carried into clock-out, correction, and QR open-session lookups.                                                                                                                                                                                                                  | UI and query-scope hardening complete; device, staging, and concurrency gates remain                                                                  |
| 2026-09-26 | Added confirmed manual clock-out and retryable-failure widget coverage, scanner flow-state tests for joinable/pending/active branches, and server rejection for revoked or expired invite credentials.                                                                                                                                                                                                                                                                                                         | Mobile branch-flow coverage and invite lifecycle validation complete; real concurrent scan testing remains                                            |
| 2026-09-26 | Ran the guarded invite-backed PostgreSQL concurrency harness against `dailio_test`: duplicate manual clock-in, different-key open-session rejection, concurrent permanent-QR replay, and simultaneous clock-out all preserved the one-session invariant; generated records were cleaned up.                                                                                                                                                                                                                    | QR/concurrency release gate I6 verified; physical-device, cross-tenant, full E2E, and independent review gates remain                                 |
| 2026-09-26 | Extended and reran the staging harness with a sibling branch and a second organization; cross-branch clock-out, cross-tenant clock-out, and cross-tenant QR punch identifiers were all rejected, and generated records were cleaned up.                                                                                                                                                                                                                                                                        | Isolation release gate I5 verified; full E2E, device, retention, and independent review gates remain                                                  |
| 2026-09-26 | Ran the guarded server-flow harness against `dailio_test`: branch, role, and direct-member policy precedence; member policy resolution; manual clock-in; permanent QR-derived clock-out; authorized timeline; and append-only correction all passed, with cleanup completed.                                                                                                                                                                                                                                   | Server vertical-flow release gate I4 verified; physical-device UI and independent review gates remain                                                 |
| 2026-09-26 | Added timezone-aware overnight shift enforcement and corrected variance to anchor lateness to clock-in while early departure uses clock-out, scoped active-session and QR replay reads explicitly by organization and branch, added branch-scoped selfie storage and bearer-token log redaction, verified 67 API tests across 19 files, and launched the debug app successfully on a provisioned Android emulator. Both guarded PostgreSQL flow and concurrency/isolation harnesses passed again with cleanup. | Enforcement, privacy hardening, and local engineering verification are clean; physical device, retention-storage, and independent review gates remain |
| 2026-09-26 | Hardened mobile attendance routing: QR resolution now fails closed for inactive/ambiguous states and requires an explicit server-provided clock action; policy management remains usable when optional role/member lists are forbidden; cancelled evidence requirements no longer remain stuck in a misleading pending state. Targeted mobile attendance, QR, policy, and fee tests (11) and Flutter analysis pass. | Mobile state/permission UX hardened; physical-device, retention-storage, and independent review gates remain |
| 2026-09-26 | Reran the complete API/mobile suites and guarded PostgreSQL flow/concurrency checks; added concurrent-correction verification to the flow harness, proving one correction winner, one conflict, and exactly one versioned correction row. | R-01 staging gate verified; private-storage retention, physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Ran the guarded retention check against configured Cloudinary and `dailio_test`: an expired private selfie was deleted from storage before sensitive coordinates/device/IP fields and the media reference were purged; deletion-failure recovery remains covered by unit tests. | R-02 staging gate verified; production scheduling/monitoring, physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Made retention cleanup safe across concurrent API instances with idempotent asset-row deletion, added startup maintenance execution, and reverified the configured-storage retention check plus the full API suite. | Operational retention hardening complete; production monitoring, physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Built and launched the API from `dist`, confirmed startup maintenance initialization, received HTTP 200 from `/api/v1/health`, and completed graceful shutdown. | Runtime startup smoke verified; physical-device, production monitoring, independent-review, and product sign-off gates remain |
| 2026-09-26 | Hardened CI reproducibility by supplying the required test OAuth configuration and linting guarded attendance scripts in the API workflow; workflow YAML formatting passes. | Automated verification is reproducible in CI; physical-device, production monitoring, independent-review, and product sign-off gates remain |
| 2026-09-26 | Added safe attendance-maintenance telemetry to the health endpoint, deduplicated overlapping job triggers, and verified the built API reports successful retention/open-session review with zero consecutive failures; the API suite is now 70 tests across 20 files. | Production monitoring surface implemented; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Sanitized attendance failure notifications and mobile attendance error surfaces: approved server validation messages remain actionable while unknown provider/database and transport errors become generic retry guidance. Added regression coverage; API suite is now 71 tests across 20 files and mobile suite is 12 tests. | Privacy/error-surface hardening complete; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Sanitized generic API error logging so unknown exceptions retain only safe type/code metadata instead of raw messages or stacks; added middleware regression coverage. API suite is now 73 tests across 21 files. | Server privacy/logging hardening complete; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Extended safe exception logging to startup maintenance, shutdown, and uncaught-exception handlers, eliminating remaining raw error-object logging from the attendance runtime path. | Runtime privacy/logging hardening complete; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Sanitized the unhandled-promise-rejection logger path as well, so unexpected rejection values are reduced to safe type/code metadata before logging; API suite remains 73 tests across 21 files. | Runtime privacy/logging hardening complete; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Closed the archived-branch lifecycle gap in shared tenant resolution and attendance active-session/punch queries; added regression tests for branch lifecycle and active-member scope. API suite is now 76 tests across 23 files. | Attendance lifecycle authorization hardening complete; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Made the health endpoint expose the real attendance-maintenance state and return HTTP 503 when maintenance is degraded; updated retention and release monitoring instructions accordingly. | Operational failure signaling hardened; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Verified the concurrency harness again in isolation after documenting sequential harness execution; duplicate manual/QR punches, simultaneous clock-out, and cross-tenant/branch rejection passed with cleanup. | Database concurrency/isolation evidence remains green; physical-device, independent-review, and product sign-off gates remain |
| 2026-09-26 | Rebuilt and installed the debug APK on the `dailio_api37` emulator, verified the Dailio login UI and expected unauthenticated API response, and confirmed camera plus fine/coarse location runtime permissions can be granted; no fatal app exception occurred. | Emulator evidence strengthened; physical camera/location, independent-review, and product sign-off gates remain |
| 2026-09-26 | Added export audit coverage, aligned server/mobile geofence location requirements for both punch actions, bound selfie evidence to short-lived actor/tenant/branch upload tokens, enforced disabled-punch policies for manual and QR actions, preserved QR clock-out for existing sessions after policy changes, rejected incomplete geofence configurations before policy rollover, added PostgreSQL constraints requiring a positive geofence radius, and deployed all 15 additive migrations to `dailio_test`. The guarded acceptance matrix still passes; API verification is 83 tests across 24 files and Flutter verification is 13 tests with clean analysis. | Database, lifecycle, and server policy invariants synchronized; physical camera/location, independent-review, production monitoring, and product sign-off gates remain |
| 2026-09-26 | Removed the manager attendance card's fabricated local shift-event log; it now renders the server-provided, authorized session timeline and labels each event from its actual event type. Flutter analyzer and all 13 mobile tests pass after the change. | Reporting UI now reflects server-confirmed attendance events; physical camera/location, independent-review, production monitoring, and product sign-off gates remain |
| 2026-09-26 | Added server-time headers to attendance history and QR punch responses, sanitized selfie-upload failures in self attendance, fixed effective-permission resolution for branch-scoped role assignments when the legacy primary role is null, and added explicit branch-default coverage to the acceptance harness. Full verification now passes with 88 API tests across 26 files, 13 Flutter tests, clean API type-check/source/script lint, the guarded acceptance flow, and the guarded concurrency/isolation flow against `dailio_test`. | Runtime clock/error privacy and authorization edge cases hardened; physical camera/location, independent-review, production monitoring, and product sign-off gates remain |
| 2026-09-26 | Added shared IANA timezone validation to organization/branch/location settings and regression coverage, preventing malformed timezone values from reaching attendance boundary and shift calculations. The complete API suite remains green at 88 tests across 26 files. | Attendance configuration safety hardened; physical camera/location, independent-review, production monitoring, and product sign-off gates remain |
| 2026-09-26 | Rebuilt the current debug APK, installed it on the provisioned `dailio_api37` emulator, launched `com.example.mobile/.MainActivity`, confirmed Firebase initialization and no fatal Android exception, and granted camera plus fine/coarse location permissions. | Fresh emulator startup/permission evidence recorded; physical camera behavior, iOS verification, independent review, production monitoring, and product sign-off remain |
| 2026-09-26 | Added policy-controlled manager manual attendance records with a mobile manager form, server-side `ATTENDANCE_CREATE_ALL`/policy/reason/timestamp/idempotency/audit enforcement, and explicit rejection of unsupported offline capture. Full verification now passes with 92 API tests across 27 files, 16 Flutter tests, clean API type-check/build/lint, clean Flutter analysis, migration status up to date, and the guarded acceptance matrix including manual records. | Manual-record and offline-policy gaps closed; physical camera behavior, iOS verification, independent review, production monitoring, and product sign-off remain |
| 2026-09-26 | Added a shared IANA branch-timezone converter for attendance display, manager manual-entry pickers, and correction submissions. Branch timezone is now retained with the active context, branch-local wall times are converted to UTC before mutation, and timezone regression tests pass. Fresh guarded concurrency, vertical-flow, and private-storage retention checks also pass. | Branch-local time handling and current staging evidence strengthened; physical camera behavior, iOS verification, independent review, production monitoring, and product sign-off remain |
| 2026-09-26 | Added service-layer permission enforcement for policy listing/update and attendance correction, preventing direct service callers from bypassing route RBAC. Targeted API tests, type-check, source/script lint, guarded acceptance, and guarded vertical-flow verification pass. | Defense-in-depth authorization completed; physical camera behavior, iOS verification, independent review, production monitoring, and product sign-off remain |
