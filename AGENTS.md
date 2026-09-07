# AGENTS.md

## Scope

These instructions apply to the entire repository. A more specific `AGENTS.md` or `AGENTS.override.md` in a subdirectory may add or override rules only for that directory.

## Mandatory Project Context

1. Read `/CONTEXT.md` completely before planning, coding, reviewing, debugging, changing schemas, or answering product questions.
2. Treat `CONTEXT.md` as the authoritative product and engineering specification for:
   - product scope and terminology;
   - multi-tenant ownership and isolation;
   - personas, RBAC, and permissions;
   - onboarding, admission, attendance, subscription, payment, and announcement flows;
   - domain entities, states, invariants, security, testing, and delivery phases.
3. Do not duplicate the entire specification in this file. Use this file for always-on working rules and `CONTEXT.md` for detailed requirements.
4. If implementation and `CONTEXT.md` disagree, identify the conflict before changing behavior. Do not silently choose one.
5. When the user approves a new or changed product decision, update the relevant section of `CONTEXT.md` and append an entry to its Decision Log in the same change.
6. Use the safe defaults in `CONTEXT.md` only while an item remains open. Ask before an assumption would create an irreversible, legally sensitive, financially sensitive, or significantly user-visible result.

## Project Summary

This is a multi-tenant organization management platform with the core hierarchy:

`User → Organization → OrganizationMembership → LocationMembership → Operational Records`

The product supports organization owners, admins/staff, and members. Its core modules are authentication, organizations, locationes, memberships/admissions, roles and permissions, attendance, shifts/leaves/holidays, plans, subscriptions, payments/ledger, fines, reminders, announcements, notifications, reports, media, and audit.

## Non-Negotiable Domain Invariants

- `User` is a global authenticated identity. Never duplicate a user per organization or location.
- `Organization` is the tenant boundary.
- `OrganizationMembership` stores a person's organization-specific profile/relationship.
- `LocationMembership` stores the person's location-specific status, member number, and operational relationship.
- Every tenant-owned record contains `organization_id`. Every location-owned operational record also contains `location_id`.
- Every tenant-scoped query, mutation, cache key, job, event, object-storage path, search, export, and aggregate must enforce organization and location isolation where applicable.
- Never trust a client-provided organization, location, user, member, role, permission, price, balance, attendance status, or lifecycle state without server validation.
- Authentication establishes identity. Server-side authorization establishes access.
- UI visibility is not authorization. Every protected API/service operation must enforce permissions independently.
- Authorize through atomic permissions and resource ownership, not hard-coded role-name checks, except protected owner/system-role invariants.
- The owner role is organization-scoped and protected. A organization must always have at least one active owner.
- Staff/member roles are location-scoped by default. A user may have different roles in different locationes.
- Owners receive active location memberships where location-level operations or attendance are required.
- Financial ledger entries and audit records are append-only. Correct posted data through linked reversals/corrections, never destructive overwrites.
- Store money as integer minor units with an ISO currency code. Never use floating-point values for money.
- Store timestamps in UTC. Store date-only business values as local dates. Calculate attendance and reporting boundaries in the location's IANA timezone.
- Attendance corrections preserve original timestamps/evidence and record reason, actor, and audit history.
- Attendance selfies and precise locations are sensitive private data. Keep them out of logs and public storage.
- Archive records with history. Do not hard-delete organizations, locationes, memberships, plans, subscriptions, financial records, or attendance records through ordinary operations.
- Admission, attendance punch, subscription assignment, payment posting, refunds, webhook processing, and other retry-prone commands must be idempotent.

## Required Working Method

### Before editing

1. Read `CONTEXT.md` and any closer directory instructions.
2. Inspect the repository structure, relevant configuration, nearby code, schemas, migrations, and tests.
3. Check repository status and preserve all existing user changes. Do not modify unrelated files.
4. Discover the actual build, lint, test, migration, and formatting commands from repository files. Do not invent commands.
5. For a complex or cross-module task, make a short dependency-aware plan before implementation.
6. Identify:
   - acting persona;
   - organization and location ownership;
   - required permission and self/all scope;
   - affected state transitions;
   - transaction and concurrency boundaries;
   - idempotency behavior;
   - audit/notification requirements;
   - privacy, timezone, financial, and cross-tenant risks;
   - necessary automated tests.

### While editing

- Follow existing repository patterns when they are coherent and compatible with `CONTEXT.md`.
- Keep changes focused on the requested outcome.
- Implement vertical behavior completely: schema, migration, domain/service rules, API contract, authorization, UI state, audit/notifications, and tests as applicable.
- Keep controllers/handlers thin. Put business rules in domain/service code and data access in scoped repositories.
- Centralize tenant scoping and permission checks so individual endpoints cannot forget them.
- Validate all external input at the boundary and enforce invariants again at the database/domain layer where appropriate.
- Use explicit lifecycle enums and transition methods. Do not allow arbitrary state changes through generic updates.
- Use database transactions for multi-entity invariants and concurrency-safe state transitions.
- Prefer additive, reversible, and backward-compatible changes.
- Do not add a new production dependency when the existing stack can solve the problem cleanly. Explain any necessary dependency.
- Do not expose raw exceptions, database errors, secrets, tokens, private media URLs, or personal data.
- Do not weaken security, tenant isolation, validation, auditing, or tests to make a failing implementation pass.

### After editing

1. Format changed files with the repository's formatter.
2. Run the narrowest relevant tests first, then broader checks when practical.
3. Run applicable type-check, lint, build, migration validation, and generated-contract checks.
4. Review the final diff for unrelated changes, unsafe defaults, missing permissions, missing tenant filters, and personal/secrets leakage.
5. Confirm documentation and `CONTEXT.md` remain accurate.
6. Report the outcome, decisions/assumptions, files or modules changed, migrations/configuration needed, verification run, and any remaining risk.

## Architecture Rules

- If the repository is empty, follow the default technical baseline in `CONTEXT.md`: a modular monolith, Flutter mobile client, TypeScript API, PostgreSQL, private object storage, and push notifications. These are defaults, not permission to replace an established stack.
- Do not introduce microservices, event buses, Redis, complex abstractions, or distributed infrastructure without a concrete current need.
- Keep domain modules separated even inside a modular monolith.
- Avoid circular module dependencies. Integrate modules through explicit services/contracts or durable events where appropriate.
- Use an outbox or equivalent reliable mechanism when a committed business operation must trigger asynchronous work.
- Keep API contracts typed and versioned. Use explicit command endpoints/services for lifecycle transitions.
- Paginate large and fast-changing lists with stable sorting.
- Store private media outside the primary database; store only metadata and protected references in domain records.

## Database and Migration Rules

- Never edit a migration that may already have been applied. Add a new migration.
- Include tenant/location ownership in foreign keys, constraints, indexes, and repository filters where supported.
- Add database constraints for uniqueness and lifecycle invariants instead of relying only on UI checks.
- Use transactions and locking/optimistic concurrency for join approval, attendance clock-out, subscription assignment, ledger posting, ownership transfer, and similar race-prone operations.
- Backfill large tables safely in bounded batches.
- Do not silently drop columns or data. Document recovery/rollback steps for risky changes.
- Index according to real scoped queries, generally starting with `organization_id` and `location_id` where applicable.

## Authorization Rules

- Use the canonical permission catalog and naming from `CONTEXT.md`.
- Compute permissions from active organization/location memberships and active role assignments.
- Never accept `ALL`, system-role protection flags, or effective permissions from normal client payloads.
- Enforce self/all distinctions, such as `ATTENDANCE_READ_SELF` versus `ATTENDANCE_READ_ALL`.
- Verify that every target resource belongs to the authorized organization and location before reading or mutating it.
- Permission changes must invalidate or refresh cached authorization promptly.
- Add explicit tests for unauthorized direct-route/API access and cross-tenant identifiers.

## Attendance Rules

- The server timestamp is authoritative. Retain client capture time only as supporting metadata.
- Enforce the effective, versioned location/role attendance policy.
- Validate required punch confirmation, live selfie, location freshness, accuracy, and geofence rules.
- Allow only one open attendance session per location membership unless the product decision changes.
- Make clock-in and clock-out idempotent.
- Handle overnight shifts and local day boundaries explicitly.
- Offline attendance is disabled by default. Never show a locally queued punch as server-confirmed.
- Corrections add corrected values and audit metadata without destroying original evidence.

## Financial Rules

- Snapshot plan terms into each subscription. Editing a plan must not rewrite existing subscriptions.
- Represent charges, payments, fines, discounts, refunds, voids, and adjustments through immutable ledger entries.
- A displayed/cached balance must be reproducible from ledger entries.
- Support partial payments and explicit allocations.
- Reject overpayment by default unless account-credit behavior is approved.
- Verify payment webhook signatures and process every webhook idempotently.
- Never treat a pending or failed payment attempt as paid.
- Refund, void, reversal, and manual adjustment require specific permission, reason, and audit record.

## UI Rules

- Render routes and actions from effective permissions, membership state, record state, and active context.
- Still expect the API to reject unauthorized direct access.
- Show the active organization/location when operational data is visible.
- Provide loading, empty, error, offline/stale, forbidden, and success states for every data surface.
- Distinguish optimistic/pending state from server-confirmed state, especially for attendance and payments.
- Confirm destructive, security-sensitive, and financial actions.
- Never use color alone to communicate status.
- Keep user-facing strings externalized and preserve localization readiness.

## Testing Requirements

Every changed behavior must have the most relevant combination of:

- unit tests for calculations, policies, permission evaluation, and state transitions;
- integration tests for constraints, transactions, scoping, and immutable records;
- API tests for validation, forbidden access, state conflicts, retries, and idempotency;
- cross-tenant isolation tests using real identifiers from two organizations;
- concurrency tests for duplicate approvals, punches, payments, and ownership changes;
- UI/widget tests for permission-aware visibility and required states;
- end-to-end coverage for critical owner onboarding, member joining, attendance, and fee flows.

Do not consider happy-path-only coverage sufficient.

## Code Review Rules

Flag a change when any of the following is true:

- A tenant-owned query lacks organization/location scope.
- A protected operation relies only on hidden UI or a role-name string.
- A self-service endpoint can target another member by changing an ID.
- A client payload can set effective permissions, financial balance, attendance result, or protected lifecycle state.
- Posted ledger or attendance evidence is destructively overwritten.
- Money uses floating point.
- Local date/time logic ignores the location timezone or overnight shifts.
- A retry can create a duplicate membership, attendance session, subscription, charge, payment, receipt, refund, or notification.
- The final owner can be removed or a system owner role can be weakened.
- Private selfies, precise locations, secrets, tokens, or payment data appear in logs, fixtures, public URLs, or API errors.
- A schema/API change lacks a migration, compatibility handling, validation, audit behavior, or tests where applicable.
- A feature contradicts `CONTEXT.md` without updating the decision log.

## Repository Commands

The repository has not yet established verified commands in this context. Once the project is initialized, replace this paragraph with confirmed commands for:

- development startup;
- formatting;
- linting;
- type checking;
- unit/integration/end-to-end tests;
- database migration and seed;
- production build.

Never guess or leave a command in this section after discovering that it is incorrect.

## Completion Standard

A task is complete only when the requested behavior works end to end, domain invariants remain intact, permissions and tenant scope are enforced, applicable migrations and documentation are included, relevant checks pass, and the final summary clearly states anything that was not verified.
