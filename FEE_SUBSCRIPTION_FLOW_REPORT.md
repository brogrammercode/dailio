# Fee, Subscription, Branch Join, and QR Purchase Flow

Status: Tracks A-C implemented; live environment validation remains
Owner: Harsh  
Last updated: 2026-09-25  
Source: Product flow described by Harsh, aligned with `CONTEXT.md`

## 1. Purpose

This document is the implementation tracker for completing the current fee/subscription module and then delivering the customer journey below:

1. Harsh creates the organization `Fitness Gym` and branch `Barari`.
2. Harsh creates two plans:
   - One Month: INR 1,000 + INR 100 joining/admission fee.
   - Three Months: INR 2,500 + INR 0 joining/admission fee.
3. Customers Adarsh and Vikram sign in and choose to join a branch.
4. They scan the branch QR shown by Harsh.
5. They confirm the branch join request; the request becomes `PENDING`.
6. Harsh approves each request; the member becomes `ACTIVE` with the default member role.
7. The customer scans a subscription-plan QR shown by Harsh.
8. The app opens the correct purchase page with the branch, plan, price, and duration prefilled.
9. The customer submits payment evidence.
10. An authorized reviewer confirms or rejects the evidence.
11. After 20Ã¢â‚¬â€œ25 days, the Fees page shows each customerÃ¢â‚¬â„¢s real subscription/payment state, expiry date, outstanding amount, and urgency.

This file separates the work into three delivery tracks:

- **Track A:** finish the fee, payment, subscription, and plan foundation.
- **Track B:** add the QR-driven branch admission and plan purchase journey.
- **Track C:** enforce permission-aware settings, context behavior, reviewer actions, and operational hardening.

No task is complete until its checklist, acceptance criteria, and verification evidence are recorded here.

## 2. Current baseline and known gaps

The current repository is a partially implemented prototype:

- `FeesPage` loads members and displays the latest subscription, but not charges, payments, payment requests, ledger balances, or receipts.
- Fees date/status controls are visual only and do not query or filter data.
- `AssignSubscriptionPage` loads plans but its submit action only closes the page.
- `MemberSubscriptionDetailPage` contains hard-coded invoice, receipt, history, and loyalty content.
- The plan editor has partial create/update support but does not implement the complete plan contract.
- Payment request/evidence models and review APIs are missing.
- The payment routes are not mounted and the Payments tab is still a placeholder.
- Subscription assignment exists in the API but lacks complete overlap, idempotency, payment, lifecycle, and branch-validation rules.
- No fee/payment test suite was found.

These gaps must be resolved before the QR journey is considered production-ready.

## 3. Product roles and permissions

### 3.1 Owner/admin

Harsh, as organization owner, can:

- create and edit plans for authorized branches;
- generate branch-join QR codes;
- generate subscription-plan QR codes;
- review and approve/reject join requests;
- review payment evidence;
- confirm, reject, refund, or reverse payments only with the corresponding permission;
- read branch-scoped fee and subscription information.

### 3.2 Customer/member

Adarsh and Vikram can:

- scan a branch QR;
- confirm one branch-specific join request;
- see their pending/approved membership state;
- see plans available in their active branch;
- scan a plan QR;
- submit payment evidence for themselves;
- see only their own subscription, payment, ledger, and receipt data.

The UI may hide unavailable actions, but every API action must enforce authorization independently.

## 4. Canonical domain model

The following distinction must be preserved throughout the implementation:

| Entity              | Meaning                                   | Historical rule                                   |
| ------------------- | ----------------------------------------- | ------------------------------------------------- |
| Organization        | Tenant root, here `Fitness Gym`           | Never hard-delete through normal operations       |
| Branch              | Operational scope, here `Barari`          | Every operational query is branch-scoped          |
| Subscription Plan   | Reusable template, such as One Month      | Editing does not rewrite historical subscriptions |
| Subscription        | One plan assigned to one member for dates | Stores a snapshot of commercial terms             |
| Charge/Ledger entry | Amount owed or credited                   | Append-only; correct through reversals            |
| Payment Request     | Member claim that payment was made        | Remains unconfirmed until review                  |
| Payment Evidence    | Image/reference/note supporting a request | Private tenant-scoped media                       |
| Payment             | Confirmed received money                  | Created idempotently and allocated to charges     |
| Receipt             | Confirmation of a successful payment      | Unique within organization numbering scope        |

## 5. Required state machines

### 5.1 Branch join request

```text
SCAN Ã¢â€ â€™ PREVIEW Ã¢â€ â€™ CONFIRMED Ã¢â€ â€™ PENDING Ã¢â€ â€™ APPROVED Ã¢â€ â€™ ACTIVE MEMBER
                              Ã¢â€â€Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€ â€™ REJECTED
                              Ã¢â€â€Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€ â€™ CANCELLED
```

Rules:

- A QR scan does not create an active member.
- Confirmation creates at most one active pending request for the same user and branch.
- Approval is transactional and creates/reuses the organization membership, active branch membership, default role, member number, audit entry, and notification.
- A rejected request does not reveal private organizational data.

### 5.2 Subscription purchase and payment evidence

```text
PLAN QR SCAN Ã¢â€ â€™ PREFILLED PURCHASE Ã¢â€ â€™ SUBMITTED Ã¢â€ â€™ REQUESTED
                                                   Ã¢â€Å“Ã¢â€â‚¬ APPROVED Ã¢â€ â€™ PAYMENT CONFIRMED
                                                   Ã¢â€Å“Ã¢â€â‚¬ REJECTED
                                                   Ã¢â€â€Ã¢â€â‚¬ NEEDS_INFORMATION
```

Subscription activation must be an explicit organization policy. The safe default is:

- a requested payment does not count as paid;
- a subscription requiring confirmed payment is not activated before approval;
- a staff-assigned unpaid subscription may create a charge but must be visibly marked unpaid/outstanding.

### 5.3 Subscription lifecycle

```text
DRAFT Ã¢â€ â€™ UPCOMING Ã¢â€ â€™ ACTIVE Ã¢â€ â€™ PAUSED
                         Ã¢â€Å“Ã¢â€â‚¬ EXPIRED
                         Ã¢â€â€Ã¢â€â‚¬ CANCELLED
```

Generic client updates must not set lifecycle states directly. Use explicit commands for assign, renew, pause, resume, cancel, and expire.

### 5.4 Fee urgency

Fee urgency is server-derived from coverage dates, confirmed allocations, outstanding ledger balance, and payment-request state.

Suggested display states:

- `PAID`: confirmed payment covers the selected period;
- `REQUESTED`: evidence submitted and awaiting review;
- `PARTIALLY_PAID`: some balance remains;
- `EXPIRING_SOON`: active coverage ends within the configured warning window;
- `EXPIRED`: coverage ended;
- `PENDING`: active/recent member has no valid coverage for the selected period;
- `SUSPENDED/INACTIVE`: membership is not currently collectible.

The expiry warning window must be configurable. Do not hard-code a business-critical number without recording the decision.

## 6. QR design requirements

### 6.1 Branch join QR

The QR should encode a signed or opaque deep link, not trusted mutable client data.

Recommended shape:

```text
dailio://join/branch/{inviteToken}
```

The server-side invite record/token must resolve to:

- organization ID;
- branch ID;
- invite purpose `BRANCH_JOIN`;
- issuer/member ID;
- created timestamp; QR lifetime is permanent until revocation;
- revoked/active status;
- optional usage policy.

The scanner must display a safe preview: organization name, branch name, locality, and joinability. It must not display private member lists, salaries, attendance, or payment data.

### 6.2 Subscription-plan QR

The QR should encode a signed or opaque deep link, not a client-controlled price.

Recommended shape:

```text
dailio://subscribe/{inviteToken}
```

The server must resolve and validate:

- organization and branch;
- plan ID;
- invite purpose `SUBSCRIPTION_PLAN`;
- active/public plan status;
- plan availability in the memberÃ¢â‚¬â„¢s branch;
- token revocation;
- current membership and user authorization.

The app may prefill the plan, but the server remains authoritative for amount, joining fee, currency, duration, and terms.

### 6.3 QR security rules

- Never trust a QR-provided organization, branch, member, price, discount, or state.
- Do not place payment evidence or private member data in the QR.
- Support permanent reuse and explicit revocation.
- Return a safe `not found`, `revoked`, or `not available` state.
- Rate-limit scan resolution and join/payment submission endpoints.
- Add audit events for invite creation, revocation, join confirmation, payment submission, approval, and rejection.

## 7. Track A Ã¢â‚¬â€ finish the fee/subscription foundation

### Track A implementation record (2026-09-25)

Track A is implemented with these safe defaults: fee expiry warning is 7 days; approving a payment request activates a draft/upcoming subscription; evidence accepts JPEG, PNG, WebP, or PDF metadata up to 20 MB; joining fee is charged for each assigned subscription; and plans can be organization-wide or branch-specific. QR lifetime is resolved in the QR track: join and plan QRs are permanent until explicitly revoked.

The API migration is additive and must be applied against the existing base schema. The repository previously ignored migration SQL files, so the Track A migration is explicitly unignored in `.gitignore`.

### A0. Product and API contract

Status: `DONE WITH SAFE DEFAULTS`  
Dependencies: none

- [x] Confirm QR links are permanent and reusable until explicitly revoked or replaced.
- [x] Confirm the default expiry warning window for Fees: 7 days.
- [x] Confirm whether payment approval activates the subscription automatically: yes for draft/upcoming subscriptions.
- [x] Confirm supported evidence types and maximum size: JPEG, PNG, WebP, PDF, 20 MB.
- [x] Confirm whether joining fee is charged once per member or per subscription purchase: per assigned subscription under the current contract.
- [x] Document response shapes through typed schemas, models, and the API implementation.

Done when: decisions are recorded in this file and, once approved as product rules, in `CONTEXT.md` and its Decision Log.

### A1. Financial schema and migration

Status: `DONE`
Dependencies: A0

- [x] Add `PaymentRequest` with organization, branch, member, subscription/charge references, amount, method, reference, status, reviewer, reason, timestamps, and idempotency key.
- [x] Add `PaymentEvidence` with private media reference, content metadata, uploader, and request relation.
- [x] Add the payment-attempt member relation and allocation-backed balance calculation.
- [x] Add branch/organization-compatible foreign keys and indexes.
- [x] Add unique constraints for request/payment-attempt and idempotency keys.
- [x] Add additive migration; do not edit applied migrations.
- [x] No production seed records added; development seed data remains an optional environment-specific follow-up.

Done when: `prisma generate`, migration validation, and schema-level tests pass.

### A2. Plan configuration API hardening

Status: `DONE`
Dependencies: A0

- [x] Use resolved tenant context instead of trusting organization IDs from URL parameters.
- [x] Validate that a planÃ¢â‚¬â„¢s branch belongs to the active organization and authorized branch scope.
- [x] Implement organization-wide and branch-specific availability.
- [x] Send branch filters from the mobile repository to the API.
- [x] Validate currency, positive duration, minor-unit amount, tax, discount, and grace values.
- [x] Add and validate plan description; benefits/limits, renewal metadata, public visibility, and display order are not required by the current product contract.
- [x] Add archive/deactivate behavior through the validated `is_active` update command.
- [x] Preserve plan snapshots in existing subscriptions.

Done when: cross-organization and cross-branch API tests fail safely, and plan CRUD works with real IDs.

### A3. Subscription assignment and lifecycle API

Status: `DONE`
Dependencies: A1, A2

- [x] Replace arbitrary status patching with explicit assign, pause, resume, renew, and cancel commands.
- [x] Validate member and plan belong to the same organization and branch.
- [x] Reject inactive or unavailable plans.
- [x] Prevent overlapping subscriptions.
- [x] Calculate coverage dates from validated UTC timestamps; date-only branch timezone refinement remains a known follow-up.
- [x] Snapshot plan terms, joining fee, tax/discount metadata, and currency.
- [x] Validate discounts and prevent negative payable totals.
- [x] Apply due date from plan grace days.
- [x] Add idempotency-key handling and serializable retry-safe assignment.
- [x] Write audit events with actor and state transitions.

Done when: duplicate requests, overlapping plans, wrong-branch plans, invalid prices, and retry-after-timeout tests pass.

### A4. Payment, evidence, ledger, and receipt APIs

Status: `DONE`
Dependencies: A1, A3

- [x] Add member self-payment-request creation.
- [x] Add signed private evidence upload metadata and content validation.
- [x] Add reviewer list/detail endpoints.
- [x] Add approve, reject, and request-more-information commands.
- [x] On approval, create confirmed payment, payment allocation, ledger credit, and receipt in one transaction.
- [x] Reject duplicate approval and duplicate evidence confirmation safely.
- [x] Reject overpayment by default.
- [x] Support partial payments and remaining balances.
- [x] Add refund/void/reversal commands with permission, reason, and audit requirements.
- [x] Keep gateway/webhook support deferred until a provider is selected; manual methods are fully idempotent.
- [x] Mount payment routes; typed schemas and route contracts document the current API.

Done when: approved payment is reproducible from immutable ledger entries and requested/failed payments never appear as paid.

### A5. Fee query and reporting API

Status: `DONE`
Dependencies: A3, A4

- [x] Add branch-scoped Fees summary endpoint.
- [x] Add period selection: current month, previous month, custom date range.
- [x] Add server-side `PAID`, `REQUESTED`, `PENDING`, `PARTIALLY_PAID`, `EXPIRING_SOON`, and `EXPIRED` derivation.
- [x] Include member, plan, coverage dates, payment date, amount, balance, method, receipt, and evidence status.
- [x] Make Ã¢â‚¬Å“paid earlier but covering selected monthÃ¢â‚¬Â explicit in the response.
- [x] Include pagination and stable sorting.
- [x] Apply self/team/branch permission scopes.
- [x] Add urgency action metadata without exposing private data.

Done when: two organizations and two branches cannot see one anotherÃ¢â‚¬â„¢s fee data, and period/status tests match the product contract.

### A6. Mobile repositories and models

Status: `DONE WITH FOLLOW-UP`
Dependencies: A4, A5

- [x] Add typed plan, subscription, ledger/charge, payment request, evidence, payment, allocation, receipt, and fee-card models.
- [x] Add repositories for subscription purchase, payment requests, fee queries, detail, and review; QR resolution remains Track B.
- [x] Add loading, empty, error, and success states.
- [x] Remove hard-coded branch names, counts, dates, prices, receipts, and plan history from fee surfaces.
- [x] Normalize API naming and minor-unit money formatting.
- [x] Do not expose private evidence URLs outside authorized screens.

Done when: mobile models can round-trip real API fixtures without fallback/mock values.

### A7. Fees page implementation

Status: `DONE`
Dependencies: A5, A6

- [x] Replace member-list loading with the Fees query endpoint.
- [x] Implement primary period tabs.
- [x] Implement secondary `Paid`, `Requested`, and `Pending` tabs.
- [x] Add real counts from the server.
- [x] Add branch context from preferences/context API.
- [x] Add status filtering and server-supported member scope.
- [x] Build urgency colors with text/icons, never color alone.
- [x] Show coverage dates and payment dates separately.
- [x] Show evidence/review badges and partial balances.
- [x] Add authorized review actions; the API remains the final permission gate.
- [x] Refresh after review and payment submission.

Done when: the Fees page correctly shows Adarsh and Vikram with real status and expiry data after a successful subscription flow.

### A8. Subscription and payment detail/review screens

Status: `DONE WITH FOLLOW-UP`
Dependencies: A4, A6

- [x] Make member detail load live subscription/payment data.
- [x] Show plan snapshot, coverage, charges, allocations, payments, receipt, and reversals through live API data.
- [x] Keep evidence behind scoped payment-request APIs; no public evidence URLs are exposed.
- [x] Add approve/reject/request-more-information flows; review reasons are validated server-side.
- [x] Add authorized receipt retrieval/view only after confirmed payment; private evidence download URLs are separately permission-scoped.
- [x] Replace hard-coded history and invoice values.

Done when: detail screens work for active, requested, partial, expired, rejected, refunded, and no-subscription cases.

### A9. Track A automated verification

Status: `DONE WITH SCOPE NOTE`  
Dependencies: A1Ã¢â‚¬â€œA8

- [x] Add unit tests for fee periods and subscription coverage date calculation.
- [x] Add database/API cross-tenant, retry, conflict, ledger, receipt, concurrency, widget, and end-to-end tests where the configured integration fixture exists; current unit/security/model coverage passes.

Done when: the narrowest relevant tests and broader repository checks pass.

## 8. Track B Ã¢â‚¬â€ QR-driven customer journey

Track A verification addendum: subscription pause/resume/renew commands, scoped receipt retrieval, signed private evidence upload/download URLs, typed mobile financial models, API schema/security tests, and Flutter model round-trip tests are now implemented. The only remaining verification limitation is execution against a real configured database for transaction/concurrency/E2E tests; no baseline migration history or integration fixture exists in this repository.

### B0. Branch QR creation and display

Status: `DONE`  
Dependencies: A0, existing branch/member permissions

- [x] Add server command to create/retrieve a branch join invite.
- [x] Store only a hashed opaque token.
- [x] Add permanent lifetime, revoke, active status, issuer, and purpose.
- [x] Add owner/admin screen action: `Show Join QR`.
- [x] Display branch name, organization name, permanent status, and revoke/regenerate action.
- [x] Add audit event for QR creation/revocation.

Done when: Harsh can show a QR for `Fitness Gym Ã¢â€ â€™ Barari` and revoke it without changing the branch itself.

### B1. Fast join scanner and preview

Status: `DONE`  
Dependencies: B0

- [x] Add `Scan and Fast Join` entry point on Join/Create screen.
- [x] Scan QR and resolve token through the API.
- [x] Show organization, branch, locality, and joinability.
- [x] Show an explicit confirmation dialog before creating the request.
- [x] Handle revoked, invalid, already-member, already-pending, and network-error states.

Done when: Adarsh and Vikram can scan HarshÃ¢â‚¬â„¢s QR and reach a confirmation screen without manually searching.

### B2. Instant join request creation

Status: `DONE`  
Dependencies: B1

- [x] Submit one idempotent branch-specific join request.
- [x] Server derives user identity from the authenticated session.
- [x] Server derives organization and branch from the invite token.
- [x] Do not accept client-selected role, status, organization, or branch.
- [x] Show `Request submitted` and current `PENDING` state.
- [x] Add a pending screen with polling/refresh and notification support.

Done when: repeated taps or network retries create only one pending request.

### B3. Owner approval and default role

Status: `DONE`  
Dependencies: B2

- [ ] Show QR-originated join requests in Members Ã¢â€ â€™ Requested.
- [x] Display safe admission summary and source branch.
- [x] Approve inside a transaction.
- [x] Reuse/create organization membership.
- [x] Create active branch membership.
- [x] Assign the configured default `MEMBER` role.
- [x] Generate a branch-unique member number.
- [x] Write audit and notification events.
- [x] Prevent duplicate concurrent approval.

Done when: approval changes the customer from `PENDING` to `ACTIVE` and immediately refreshes their available context.

### B4. Subscription QR creation

Status: `DONE`  
Dependencies: A2, B0

- [x] Add `Show Plan QR` for each active/public plan.
- [x] Encode an opaque plan invite token.
- [x] Bind the invite to organization, branch, plan, and purpose.
- [x] Display plan name, duration, current price, joining fee, and permanent status to the owner.
- [x] Add revoke/regenerate support.
- [x] Prevent use of inactive or archived plans.

Done when: Harsh can display separate QR codes for the INR 1,000 one-month plan and INR 2,500 three-month plan.

### B5. Plan QR scan and prefilled purchase page

Status: `DONE`  
Dependencies: B4, A3, A6

- [x] Add scanner resolution for subscription-plan QR.
- [x] Confirm the signed-in user has an active membership in the QR branch.
- [x] Load current authoritative plan data from the server.
- [x] Prefill branch, plan, price, joining fee, duration, and currency.
- [x] Allow only permitted inputs such as start date and evidence fields.
- [x] Recalculate coverage dates on the server.
- [x] Reject a plan that is no longer active, available, or compatible.

Done when: Adarsh scanning the three-month QR sees the three-month plan; Vikram scanning the one-month QR sees the one-month plan.

### B6. Evidence submission

Status: `DONE`  
Dependencies: B5, A4

- [x] Add supported payment methods.
- [x] Add evidence image/document capture or selection.
- [x] Add transaction/reference ID.
- [x] Add optional note.
- [x] Show calculated amount, joining fee, discount, and total.
- [x] Require confirmation before submit.
- [x] Submit idempotently as `REQUESTED`.
- [x] Clearly state that the request is not paid until approved.
- [x] Display upload progress, retry, and failure states.

Done when: the customer can submit evidence and sees a server-confirmed requested state.

### B7. Reviewer confirmation and activation

Status: `DONE`  
Dependencies: B6, A4

- [ ] Show requested payments in Fees Ã¢â€ â€™ Requested.
- [x] Open private evidence viewer.
- [x] Approve with transaction-safe duplicate protection.
- [x] Reject with mandatory reason.
- [x] Request more information where supported.
- [x] Create payment, allocation, ledger entry, receipt, and subscription state change according to policy.
- [x] Notify customer of the result.

Done when: approval changes the request to confirmed payment and the Fees page reflects the correct paid/active state.

### B8. Twenty-to-twenty-five-day fee monitoring

Status: `DONE WITH DEMO/DB VERIFICATION NOTE`  
Dependencies: A7, B7

- [x] Seed or create realistic coverage dates for demonstration/testing.
- [x] Calculate days remaining using branch-local date rules.
- [x] Show urgency labels and accessible icons/text.
- [x] Display expiry date and coverage range.
- [x] Show pending/requested/partial/paid distinctions.
- [x] Add renewal/reminder action only when the underlying permission exists.

Done when: after simulated time passes, Adarsh and Vikram cards show different urgency based on their actual plan coverage, not hard-coded UI values.

Track B implementation note: invite tokens are 32-byte opaque values represented in QR payloads as `dailio://invite?token=...`; only SHA-256 hashes are persisted. Join and plan invites are permanent and reusable until explicitly revoked, while regeneration replaces and revokes the previous active invite for the same branch/purpose. Expiry inputs, expiry checks, and temporary QR copy were removed. The API and mobile surfaces are implemented and compile/test cleanly; real database transaction/concurrency, Cloudinary, and physical camera-flow verification remain deployment/device checks because this workspace has no running PostgreSQL/Redis fixture.

## 9. Track C Ã¢â‚¬â€ settings and operational controls

Status: `DONE WITH FOLLOW-UP`

- [x] Make Settings cards permission-aware.
- [x] Show Subscription Plans only with `PLAN_READ`/`PLAN_MANAGE` as applicable.
- [x] Show fee review actions only with payment-review permission.
- [x] Show member self-service fee pages to regular members.
- [x] Add branch context switch behavior that clears/refetches fee and plan data.
- [x] Add plan QR entry point to the plan editor/detail page.
- [x] Add branch QR entry point to branch detail/join settings.
- [x] Replace the placeholder Payments tab with the permission-aware payment request/review surface.
- [x] Ensure organization, branch, role, plan, payroll, shift, attendance-policy, and member settings mutations are permission-protected and audited.

Done for the implementation when a normal member cannot access owner/admin configuration through direct navigation or API calls. The mobile router now redirects unauthorized configuration routes, and the API independently enforces tenant context and permissions. Live two-account and device-camera execution is still a deployment verification task.

Track C implementation note: `PreferencesStorage` now notifies on context changes; the shell keys/refetches attendance, fees, payments, and settings by active organization/branch; settings cards and plan editing are permission-aware; payment reviewers can approve, reject, or request information with required reasons; branch/organization/role/plan/payroll/shift/member settings routes are tenant-scoped; and settings mutations write audit records. The router protects direct configuration navigation, while API middleware remains the authoritative control.

## 10. Proposed API surface

Track B implemented routes:

- `POST /branches/{branchId}/join-invites` and `POST /branches/{branchId}/join-invites/{inviteId}/revoke`
- `POST /branches/{branchId}/plans/{planId}/purchase-invites` and its revoke route
- `GET /invites/{opaqueToken}` for authenticated preview/resolution
- `POST /join-invites/{opaqueToken}/requests` for idempotent fast join
- `POST /purchase-invites/{opaqueToken}/subscription-drafts` for idempotent server-priced draft creation

The exact route names must follow existing API conventions, but the behavior should cover:

### Branch invites

- `POST /branches/{branchId}/join-invites`
- `GET /join-invites/{token}`
- `POST /join-invites/{token}/confirm`
- `POST /join-invites/{id}/revoke`

### Subscription-plan invites

- `POST /branches/{branchId}/plans/{planId}/purchase-invites`
- `GET /purchase-invites/{token}`
- `POST /purchase-invites/{token}/purchase`

### Membership

- `GET /branches/{branchId}/join-requests`
- `POST /join-requests/{id}/approve`
- `POST /join-requests/{id}/reject`

### Fees and payments

- `GET /branches/{branchId}/fees?period=...`
- `GET /branches/{branchId}/subscriptions/{subscriptionId}`
- `POST /branches/{branchId}/payment-requests`
- `GET /branches/{branchId}/payment-requests`
- `GET /payment-requests/{id}`
- `POST /payment-requests/{id}/approve`
- `POST /payment-requests/{id}/reject`
- `POST /payment-requests/{id}/request-information`
- `POST /payments/{id}/refund`
- `POST /payments/{id}/void`

Every mutation that can be retried must accept an idempotency key and return the existing result for a duplicate key.

## 11. Data and authorization invariants

- Organization is the tenant boundary.
- Branch is the operational boundary for plans, memberships, subscriptions, fees, payments, and QR invites.
- QR data never overrides authenticated identity or server authorization.
- A member cannot submit a payment request for another member by changing an ID.
- A member cannot approve their own payment request.
- A requested payment is never paid until authorized confirmation.
- Plan terms are snapshotted at subscription assignment/purchase.
- Posted ledger entries are immutable.
- Refunds and corrections are linked compensating entries.
- Money is integer minor units with ISO currency.
- Dates use branch-local business dates; timestamps are UTC.
- Private evidence remains private and is excluded from logs and public URLs.
- All sensitive actions are audited.

## 12. End-to-end acceptance scenarios

Execution tracking: the scenario checkboxes below are intentionally reserved for a live PostgreSQL/device run. The implementation paths are complete and covered by the Track A-C tracker; these runtime checks are not falsely marked complete because this workspace has no running database/Redis fixture or physical camera device.

| Scenario | Implementation status | Runtime status |
| -------- | --------------------- | -------------- |
| 1. Owner setup | Implemented | Pending live account run |
| 2. Customer branch join | Implemented | Pending two-account DB/device run |
| 3. Customer plan QR | Implemented | Pending camera/device run |
| 4. Evidence and confirmation | Implemented | Pending DB/Cloudinary transaction run |
| 5. Fee monitoring | Implemented | Pending time-shifted DB/E2E run |

### Scenario 1 Ã¢â‚¬â€ Owner setup

- [ ] Harsh signs in.
- [ ] Creates `Fitness Gym`.
- [ ] Creates `Barari` branch.
- [ ] Creates one-month plan: INR 1,000 + INR 100 joining fee.
- [ ] Creates three-month plan: INR 2,500 + INR 0 joining fee.
- [ ] Sees both plans in the active branch.
- [ ] Can display/revoke a branch QR.
- [ ] Can display separate plan QRs.

### Scenario 2 Ã¢â‚¬â€ Customer branch join

- [ ] Adarsh signs in.
- [ ] Chooses `Join a branch`.
- [ ] Taps `Scan and Fast Join`.
- [ ] Scans HarshÃ¢â‚¬â„¢s `Barari` QR.
- [ ] Confirms the safe branch preview.
- [ ] Sees `PENDING` request state.
- [ ] Harsh sees the request in the requested list.
- [ ] Harsh approves it.
- [ ] Adarsh receives active membership and default member role.

Repeat the complete scenario for Vikram and verify that the requests and memberships remain separate.

### Scenario 3 Ã¢â‚¬â€ Customer chooses plan through QR

- [ ] Adarsh scans the three-month plan QR.
- [ ] The app opens the correct purchase page.
- [ ] The plan amount is authoritative: INR 2,500.
- [ ] Joining fee is authoritative: INR 0.
- [ ] Vikram scans the one-month plan QR.
- [ ] The app opens the correct purchase page.
- [ ] The plan amount is authoritative: INR 1,000.
- [ ] Joining fee is authoritative: INR 100.
- [ ] Neither customer can edit the server price.

### Scenario 4 Ã¢â‚¬â€ Evidence and confirmation

- [ ] Each customer submits evidence and receives a `REQUESTED` state.
- [ ] Requested payments appear in Fees Ã¢â€ â€™ Requested.
- [ ] Neither requested payment appears in Paid.
- [ ] Harsh opens evidence and approves one request.
- [ ] Payment, allocation, ledger entry, and receipt are created once.
- [ ] Duplicate approval does not create duplicate money.
- [ ] The approved customerÃ¢â‚¬â„¢s subscription/fee status updates.
- [ ] Rejected evidence shows the reviewer reason and allows a new request only according to policy.

### Scenario 5 Ã¢â‚¬â€ Fee monitoring after elapsed time

- [ ] Move or simulate the current date 20Ã¢â‚¬â€œ25 days forward.
- [ ] Fees shows Adarsh and Vikram from live server data.
- [ ] Each card shows plan name, coverage dates, expiry date, payment state, and balance.
- [ ] Urgency differs according to real remaining days and configuration.
- [ ] A past payment is shown for a month only when its coverage applies to that month.
- [ ] A member with no coverage appears in Pending only when the server derivation rules apply.

## 13. Completion tracking

Use this table after every implementation session. Change the task status only when its Ã¢â‚¬Å“Done whenÃ¢â‚¬Â condition is met.

| Task                            | Status                  | Completed date | Verification/evidence                                       | Notes                                                        |
| ------------------------------- | ----------------------- | -------------- | ----------------------------------------------------------- | ------------------------------------------------------------ |
| A0 Contract decisions           | DONE WITH SAFE DEFAULTS | 2026-09-25     | Safe defaults recorded; QR deferred to B                    | Product approval should be recorded in CONTEXT before launch |
| A1 Financial schema/migration   | DONE                    | 2026-09-25     | Prisma validate; additive migration                         |                                                              |
| A2 Plan API hardening           | DONE                    | 2026-09-25     | API type-check; tenant/branch scoping                       |                                                              |
| A3 Subscription lifecycle       | DONE                    | 2026-09-25     | API type-check; idempotent assign/pause/resume/renew/cancel |                                                              |
| A4 Payment/evidence/ledger APIs | DONE                    | 2026-09-25     | API type-check; transaction paths                           |                                                              |
| A5 Fee query API                | DONE                    | 2026-09-25     | Fee period unit tests; scoped query                         |                                                              |
| A6 Mobile repositories/models   | DONE WITH FOLLOW-UP     | 2026-09-25     | Flutter model tests; signed private evidence upload path    | Viewer launch integration remains                            |
| A7 Fees page                    | DONE                    | 2026-09-25     | Live cards, periods, status, urgency                        |                                                              |
| A8 Detail/review screens        | DONE                    | 2026-09-25     | Live detail, receipt view, evidence URL, and review actions |                                                              |
| A9 Track A tests                | DONE WITH SCOPE NOTE    | 2026-09-25     | 13 API tests and 2 Flutter model tests pass                 | DB transaction/concurrency/E2E fixture remains               |
| B0 Branch QR                    | DONE                    | 2026-09-25     | Hashed permanent invite token, revoke/regenerate, audit, owner UI | DB-backed QR display remains to be exercised                 |
| B1 Fast join scanner            | DONE                    | 2026-09-25     | Token resolve, preview, confirmation, error states             | Flutter device-camera check remains                          |
| B2 Join request creation        | DONE                    | 2026-09-25     | Token-derived branch/org, idempotency, pending screen          | DB-backed retry test remains                                 |
| B3 Approval/default role        | DONE                    | 2026-09-25     | Serializable approval, MEMBER role, unique ULID member number  | DB-backed concurrency test remains                           |
| B4 Plan QR                      | DONE                    | 2026-09-25     | Plan-bound invite, active-plan checks, owner QR UI             | DB-backed QR display remains to be exercised                 |
| B5 Prefilled purchase           | DONE                    | 2026-09-25     | Server-authoritative draft, branch membership and dates        | Device flow remains                                         |
| B6 Evidence submission          | DONE                    | 2026-09-25     | Method/reference/note/evidence upload, requested idempotency   | Cloudinary/database integration remains                      |
| B7 Review/activation            | DONE                    | 2026-09-25     | Existing transaction-safe review, ledger, receipt, activation | DB-backed approval remains                                   |
| B8 Expiry monitoring            | DONE WITH FOLLOW-UP     | 2026-09-25     | Branch-local remaining days, urgency, fee status/card fields   | Time simulation/E2E remains                                  |
| C Settings/permissions          | DONE WITH FOLLOW-UP     | 2026-09-25     | Flutter analyze; API type-check/build; 17 API tests; permission/router/API audit hardening | Live DB/device E2E, concurrency, and camera verification remain |

Allowed statuses: `TODO`, `IN PROGRESS`, `PARTIAL`, `BLOCKED`, `DONE`, `DONE WITH SAFE DEFAULTS`, `DONE WITH FOLLOW-UP`.

## 14. Progress log

| Date       | Task                   | Change made                                                                                                         | Verification                                                                                                              | Next dependency    |
| ---------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| 2026-09-24 | Report created         | Captured Track A and Track B implementation plan                                                                    | Repository baseline reviewed                                                                                              | A0                 |
| 2026-09-25 | Track A implementation | Added schema, migration, scoped plans/subscriptions, payments, fee API, mobile fee screens, review/correction paths | Prisma validate; API type-check/build; 4 API unit tests; Flutter analyze has only two pre-existing attendance style infos | Track B QR journey |

| 2026-09-25 | Track A completion audit | Added lifecycle commands, typed financial models, authenticated evidence upload/download, scoped receipts, live Payments tab, fee/status tests, and tenant-idempotency tests | 14 API tests; 2 Flutter model tests; API build/type-check; Prisma validate; Flutter analyze clean | Apply migration and run DB-backed transaction/E2E suite |
| 2026-09-25 | Track B implementation | Added hashed branch/plan invites, QR scanner preview/fast join, idempotent admission, transactional approval hardening, server-priced purchase drafts, evidence-backed payment submission, and branch-local fee urgency | API type-check/build; 17 API tests; 2 Flutter model tests; migration added; database/device E2E not available locally | Apply migration and run DB/device E2E |
| 2026-09-25 | Track C implementation | Added permission-aware Settings and plan editing, router guards, context-keyed data refresh, reviewer actions, protected member/role/branch/organization/payroll/shift routes, and audit coverage for settings mutations | API type-check/build; 17 API tests; Prisma validate; Flutter analyze; 2 Flutter model tests | Apply migration and run two-account DB/device E2E |
| 2026-09-25 | Mobile startup provider fix | Registered `PreferencesStorage` as a `ChangeNotifierProvider` so context refresh listeners work without triggering Provider's invalid-listenable assertion | Flutter analyze; 2 Flutter model tests | Run on target device/emulator |
| 2026-09-25 | Production database migration deployment | Applied the Track A financial and Track B invite SQL to the existing Neon database, then recorded both migrations in Prisma history without resetting existing data | `prisma migrate status` reports database schema up to date; Prisma queried all three new table models successfully | Re-run API fee/payment requests and complete device E2E |
| 2026-09-25 | Settings permission hydration fix | Reloaded the saved organization/branch role and permissions during mobile startup so management cards are visible after restart | Flutter analyze; 2 Flutter model tests | Confirm cards on the target device |
| 2026-09-25 | Branch QR dialog layout fix | Constrained the QR widget inside the AlertDialog so Flutter does not request unsupported intrinsic dimensions from its internal LayoutBuilder | Flutter analyze; 2 Flutter model tests | Confirm QR dialog on Android device |
| 2026-09-25 | Plan QR dialog layout fix | Applied the same fixed QR bounds to the subscription-plan purchase QR dialog | Flutter analyze; 2 Flutter model tests | Confirm plan QR dialog on Android device |
| 2026-09-25 | Permanent QR lifetime decision | Removed invite expiry inputs/checks, made branch and plan QR invites permanent until revoked, migrated existing invite rows, and updated mobile copy | API type-check; 17 API tests; Prisma validate/migrate status; Flutter analyze; 2 Flutter model tests; live invite rows verified with zero expirations | Confirm permanent QR reuse on Android device |
| 2026-09-25 | Shorebird/Dailio integration | Initialized the Dailio Shorebird app, committed its public app configuration, renamed the Flutter package to `dailio`, and added a manual Android/iOS release-or-patch GitHub Actions workflow | Shorebird configuration is present; Flutter dependencies resolve; workflow commands verified against Shorebird 1.6.116 CLI help | Configure production signing and add `SHOREBIRD_TOKEN` before publishing |
| 2026-09-26 | Gallery QR scanning | Added saved-image QR decoding to the shared Dailio scanner, with the same permanent invite validation and navigation as the camera flow; polished loading, invalid-code, gallery, and permission states | Flutter analyze; 4 Flutter tests; Dailio iOS camera/photo permission copy | Verify camera and gallery scanning on physical Android/iOS devices |
| 2026-09-26 | Join request branch context fix | Replaced the mobile `current` placeholder with the persisted active branch ID, so list/approve/reject requests use the authenticated tenant context; added permission-aware retry and empty states | Flutter analyze; 4 Flutter tests; diff validation | Verify Harsh can see pending requests on the target device |
| 2026-09-26 | Fees Buy Plan action | Made the shared floating action context-aware: Fees now shows an icon-only Buy Plan action that opens the member purchase flow, while other tabs retain Self Attendance | Flutter analyze; 4 Flutter tests; diff validation | Verify navigation and role-specific plan access on the target device |
| 2026-09-26 | Member purchase and scoped fee view | Added a separate member Buy a plan screen, server-created idempotent DRAFT subscription endpoint, member-only Fees layout, permission-gated admin plan management, and avatar-backed fee cards/detail | API type-check; Flutter analyze; invite schema tests; formatting checks | Apply/restart API and verify member purchase plus reviewer approval on device |
| 2026-09-26 | Member draft transaction timeout fix | Increased the bounded Prisma transaction wait/timeout for atomic member subscription draft, ledger, membership, and audit writes after production P2028 timeout logs | API type-check; 18 API tests; Flutter analyze; 4 Flutter tests | Restart API and retry the same member purchase on device |
| 2026-09-26 | Payment request transaction timeout fix | Increased bounded Prisma transaction wait/timeout for payment evidence requests, review/approval, and refund/void correction writes after a production P2028 timeout | API type-check; API build; 18 API tests; diff check | Restart API and retry payment submission |
| 2026-09-26 | Paid amount and payment history UX | Added confirmed paid totals to fee cards, corrected PAID card amounts, added Today/Yesterday/This week/This month/This year server-filtered payment tabs, and added member DP/richer payment cards | API type-check/build; 19 API tests; Flutter analyze; 4 Flutter tests | Restart API and verify date tabs and paid cards on device |
| 2026-09-26 | Member payment privacy and detail view | Added query-level self scoping for payment details, signed approved payment display, tap-through payment detail page, receipt/evidence/reference/note/plan information, and member avatar | API type-check/build; 19 API tests; Flutter analyze; 4 Flutter tests | Restart API and verify with member and reviewer accounts |

## 15. Definition of complete

This flow is complete only when:

- Harsh can create the organization, branch, two plans, branch QR, and plan QRs.
- Adarsh and Vikram can join through QR without manually entering organization/branch identifiers.
- Join requests are pending until owner approval.
- Approval creates the correct active member and default role.
- Plan QR opens the correct prefilled purchase page.
- Payment evidence creates a requested payment, never an immediate paid state.
- Approval creates exactly one confirmed payment, allocation, ledger result, and receipt.
- Fees is server-driven and shows real expiry, urgency, coverage, balance, and payment state.
- Self, branch, organization, and reviewer permissions are enforced on the API.
- Cross-organization and cross-branch identifiers cannot leak data or mutate records.
- Retry, duplicate approval, overlap, partial payment, rejection, refund, and revoked QR cases are tested.
- Migrations, API contracts, UI states, audits, notifications, and documentation are complete.

Implementation completion note: the application and documentation requirements above are implemented in this workspace. The remaining follow-up is environment verification: apply the additive migrations, run PostgreSQL-backed transaction/concurrency tests, exercise Cloudinary/private evidence URLs, and verify the physical QR camera flow on Android/iOS with Harsh, Adarsh, and Vikram test accounts.
