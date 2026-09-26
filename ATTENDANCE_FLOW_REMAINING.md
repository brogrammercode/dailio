# Dailio Attendance Flow — Remaining Work and Tracking

> This legacy checklist is retained for history. The authoritative current
> tracker is [ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md](ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md),
> which includes the completed policy, multi-role, team-scope, permanent QR,
> pagination, notification, migration, and release-verification status.

This is the implementation checklist for the core attendance flow. The expanded master plan for per-person/role policies and the permanent gate QR is [ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md](ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md). The master plan is authoritative where this older checklist differs.

## Product outcome

An authenticated person opens Self attendance, sees the active branch and effective policy, submits a clock-in or clock-out, and sees only the server-confirmed result. The person can inspect records by period and open a detail page containing the timeline, shift, status, correction history, and permitted private evidence. A manager can view authorized team/branch records, inspect details, and correct a record with a reason and audit trail.

## Current implementation status

### Completed in this pass

- [x] Member fees hides Buy plan when the member has a non-cancelled, non-expired subscription with a future end date.
- [x] The same Buy plan action is hidden from the shell FAB for members with current coverage.
- [x] Self attendance loads effective policy, active session, and this-month records from the API.
- [x] Self attendance no longer displays seeded/fake dates, branch names, shift labels, verification badges, or activity counts.
- [x] Self attendance records open a live attendance detail page.
- [x] Admin attendance cards show actual shift/evidence values and open the scoped detail page.
- [x] Attendance detail endpoint enforces organization, branch, and self/all access scope.
- [x] Location evidence supplied at clock-in/clock-out is persisted against the attendance session.
- [x] Clock-in and clock-out accept existing idempotency keys and return the prior session on a retry.
- [x] Self members can read the effective attendance policy required by the self-attendance screen.

### Still required before calling attendance complete

The items below are intentionally not represented as complete by the current UI.

## Track A — Policy and branch context

- [ ] A1. Add an authorized attendance-policy management surface for branch settings.
  - [ ] Configure punch, selfie, location, geofence, shift enforcement, grace, minimum-session, maximum-open-session, and offline-capture settings.
- [ ] A2. Resolve branch timezone from the branch record and use it everywhere.
  - [ ] Return timezone in branch/context payload.
  - [ ] Stop sending a fixed client timezone from mobile.
  - [ ] Calculate today/yesterday/week/month boundaries in branch local time, then query UTC.
  - [ ] Handle overnight shifts and daylight-saving transitions.
- [ ] A3. Return explicit `server_time` in attendance responses so the live clock can be synchronized.
- [ ] A4. Display policy version/effective-from and verify the policy used by each session.

## Track B — Clock-in/out domain rules

- [ ] B1. Enforce policy requirements on the server, not only in mobile.
  - [ ] Reject missing required location/selfie evidence.
  - [ ] Validate accuracy threshold and geofence distance server-side.
  - [ ] Enforce shift windows, late grace, early departure, minimum session, and maximum-open-session behavior.
- [ ] B2. Make idempotency race-safe under concurrent duplicate requests and add concurrency tests.
- [ ] B3. Add stale-session/version conflict handling for clock-out.
- [ ] B4. Calculate derived status from policy/shift instead of the current duration-only heuristic.
- [ ] B5. Add explicit auto-close/warning/audit behavior for sessions left open past policy limits.

## Track C — Evidence and privacy

- [ ] C1. Implement private selfie upload before clock submission.
  - [ ] Request a scoped upload signature.
  - [ ] Upload to private tenant/branch/session storage.
  - [ ] Create `SELFIE_IN`/`SELFIE_OUT` evidence with the media asset id.
  - [ ] Serve evidence through authorized, expiring access only.
- [ ] C2. Retain location evidence only for the approved attendance purpose; keep coordinates out of logs/public URLs.
- [ ] C3. Add evidence retention/deletion policy and audit evidence access.
- [ ] C4. Show evidence as recorded, missing, or not required; never infer verification from camera action alone.

## Track D — Self attendance experience

- [x] D1. Today state, policy summary, active session, and clock action are API-backed.
- [x] D2. Monthly records are API-backed and open detail.
- [ ] D3. Add today/yesterday/week/month/custom local-date filters.
- [ ] D4. Add loading, empty, forbidden, offline/stale, and retry states to every section.
- [ ] D5. Distinguish pending submission from server-confirmed state and show server time.
- [ ] D6. Show shift, variance/late minutes, and policy version in self records.
- [ ] D7. Add accessible status text/icons so status is not communicated by color alone.

## Track E — Manager attendance and detail

- [x] E1. Branch-scoped list uses API records and role filtering.
- [x] E2. Detail page shows actual times, status, duration, correction reason, timeline, and evidence metadata.
- [x] E3. Detail access is self-scoped unless the caller has all-record permission.
- [ ] E4. Align list permissions with the canonical self/team/branch permission catalog and implement team scope.
- [ ] E5. Add true team/branch filters and stable pagination.
- [ ] E6. Add ongoing activity with live refresh and a stale timestamp.
- [ ] E7. Add authorized export/reporting with tenant/branch scope and audit logging.
- [ ] E8. Keep correction action discoverable without making card tap bypass detail.

## Track F — Corrections, audit, and notifications

- [ ] F1. Preserve original clock values immutably and store corrected values as a linked correction/version.
- [ ] F2. Record actor, reason, before/after values, and policy context for every correction.
- [ ] F3. Add correction conflict handling for concurrent manager edits.
- [ ] F4. Add missed-clock-out, late-arrival, correction-request, and correction-completion notifications.
- [ ] F5. Add anomaly review for impossible duration, geofence mismatch, duplicate device patterns, and suspicious evidence.

## Track G — Verification and release gate

- [ ] G1. Unit tests for local boundaries, overnight shifts, grace periods, duration, and statuses.
- [ ] G2. API tests for self/all authorization, cross-tenant identifiers, validation, policy enforcement, and forbidden detail access.
- [ ] G3. Integration tests for evidence ownership, idempotency keys, open-session invariant, and append-only corrections.
- [ ] G4. Concurrency tests for duplicate punches and simultaneous corrections.
- [ ] G5. Mobile widget tests for self/all visibility and loading/empty/error/offline states.
- [ ] G6. End-to-end policy → punch/evidence → history → detail → correction flow.
- [ ] G7. Verify migration/deployment behavior with existing attendance rows.
- [ ] G8. Run API type-check/build/lint/tests and Flutter analyze/test before release.

## Recommended next execution order

1. Branch timezone and server-time contract.
2. Server-side policy enforcement and status calculation.
3. Private selfie media flow.
4. Self custom filters and manager team/branch scope.
5. Immutable corrections and concurrency safety.
6. Automated coverage and end-to-end release gate.

## Progress log

| Date | Work | Result |
|---|---|---|
| 2026-09-26 | Attendance flow audit and first completion pass | Live self/admin surfaces, detail endpoint/page, location evidence persistence, policy self-read, and member buy-plan gating completed. Remaining work is tracked above. |
