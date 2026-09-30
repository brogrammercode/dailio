# Dailio Notification System — Implementation Tracker

**Status:** Repository implementation complete — external provider/device/deployment verification is documented as manual release validation  
**Last reviewed:** 29 September 2026  
**Scope:** API, PostgreSQL/Prisma, Flutter mobile, Firebase Cloud Messaging, in-app inbox, HTML email, and Vercel deployment

This document is the single tracker for Dailio notifications. A task is marked complete only when its server behavior, authorization, tenant/location scope, delivery behavior, UI state, and relevant tests are complete.

## 1. Product goal

When a business action is successfully committed, Dailio should notify the correct people through:

1. **In-app inbox** — durable notification stored in PostgreSQL.
2. **Push** — Firebase Cloud Messaging (FCM) to the user’s registered devices.
3. **Email** — branded HTML email when the user has an email address and the event/channel policy allows it.

The business module remains responsible for deciding that an action happened. A central notification service is responsible for finding recipients, applying preferences, deduplicating, creating notification records, and dispatching the enabled channels.

The first version deliberately stays simple:

```text
Business command
  → database transaction commits
  → NotificationService.notify(event)
      → create durable in-app notification
      → create delivery records
      → send FCM and email with bounded best-effort delivery
  → mobile inbox refreshes or receives push
```

No new microservice is required. No always-running worker is required for the first Vercel deployment. Durable database records are the source of truth; delivery can be retried safely with idempotency keys.

## 2. Completion legend

| Marker  | Meaning                                                      |
| ------- | ------------------------------------------------------------ |
| `[x]`   | Implemented and verified in the repository                   |
| `[manual]` | Requires an external provider, deployed environment, or physical device; no repository work remains |
| `[N/A]` | Intentionally not applicable because of a product decision   |
| `[?]`   | Needs a product/configuration decision before implementation |

## 3. Current repository audit

### Already present

- `[x]` Notification list endpoint: `GET /api/v1/notifications`.
- `[x]` Mark-one-read endpoint: `PATCH /api/v1/notifications/:notification_id/read`.
- `[x]` Mark-all-read endpoint: `POST /api/v1/notifications/read-all`.
- `[x]` User-scoped notification reads are authorization-protected.
- `[x]` Prisma `Notification` model supports `IN_APP`, `PUSH`, and `EMAIL`; delivery/job tables are migrated to the configured database.
- `[x]` User has an `fcm_token` field and profile update support for registering it.
- `[x]` API has lazy Firebase Admin initialization using project ID, private key, and client email.
- `[x]` Admission lifecycle notifications use the central service; approval has a retry-safe historical-constraint fallback.
- `[x]` Attendance action, evidence/geofence failure, confirmation, late arrival, incomplete session, correction, and missing clock-out notifications use the central service.
- `[x]` Attendance review and evidence-retention maintenance run through the database-backed daily coordinator; local timers are fallback only.
- `[N/A]` BullMQ notification/reminder queue definitions are not used in the Vercel MVP path; the database coordinator is the supported worker.
- `[x]` Mobile has FCM/local-notification runtime wiring and synchronizes the FCM token after sign-in and refresh.

### Missing or incomplete

- `[x]` Central event-based `NotificationService` — in-app, push, optional email, preferences, deduplication, and delivery state are implemented.
- `[x]` Notification recipient resolver — active organization/branch membership and permission-scoped reviewer resolution is implemented for all current event producers.
- `[x]` Email channel and safe HTML templates — Gmail/Nodemailer adapter, escaped Dailio template, preferences, timeout, and delivery records are implemented.
- `[x]` Delivery-level status, retry, invalid-token cleanup, and bounded scheduled delivery retries are implemented.
- `[x]` Notification event type, entity reference, branch reference, and deep-link metadata.
- `[x]` Mobile Firebase initialization and notification lifecycle handlers.
- `[x]` Mobile foreground, background, terminated-state, tap, and token-refresh behavior.
- `[x]` Vercel serverless entry point added at `apps/api/src/index.ts`.
- `[x]` Database-backed daily job claim/lease mechanism.
- `[x]` First-app-open daily job coordinator — endpoint, atomic claim/lease, bounded job catalog, and mobile trigger are implemented.
- `[x]` Vercel Cron fallback route and hourly schedule are implemented; deployed-cron verification remains external.
- `[x]` Event coverage is implemented for all current admission, membership, payment, subscription, fee, role, shift, attendance, and salary-structure commands; unavailable mutation modules are marked N/A.
- `[x]` Central delivery, retry-job, privacy, scope, mobile automated tests, and current leave/announcement schema tests pass.

## 4. Target architecture

### 4.1 Business-module flow

Every module follows this pattern:

```text
1. Validate input and permissions.
2. Execute the business mutation in a transaction.
3. Commit the business result.
4. Call NotificationService.notify() with the committed event.
5. Return the business response without exposing provider secrets/errors.
```

Notifications must not be sent before the business transaction commits. If a payment or membership mutation rolls back, users must not receive a false success notification.

The service should accept a typed event similar to:

```ts
{
  type: 'PAYMENT_REQUEST_APPROVED',
  organizationId,
  branchId,
  actorUserId,
  entityId: paymentRequestId,
  recipientPolicy: { kind: 'member', memberId },
  templateData: { planName, amountMinor, currency },
  dedupeKey: `payment-request:${paymentRequestId}:approved`,
}
```

The client-provided payload must never decide recipients, tenant ownership, payment amount, permission, or final status.

### 4.2 Central notification service responsibilities

- Resolve recipients from server-side organization/branch memberships.
- Enforce active membership and permission scope.
- Apply per-user channel preferences when preferences are introduced.
- Build localized title, body, email subject, plain text, and HTML from trusted template data.
- Create one durable in-app record.
- Create one delivery record per channel and recipient.
- Use a stable event dedupe key so retries do not duplicate notifications.
- Send FCM data with string values only.
- Remove invalid FCM tokens when Firebase reports an invalid/unregistered token.
- Send email through a reusable email client.
- Record success/failure without failing the original business command after commit.
- Redact tokens, precise locations, selfies, payment secrets, and private evidence from logs.

### 4.3 Recommended minimal data model changes

Add a migration; never edit an already-applied migration.

#### Notification model

- `[x]` Add `event_type`.
- `[x]` Add nullable `branch_id`/`location_id` where the current schema terminology requires it.
- `[x]` Add nullable `entity_type` and `entity_id` for deep links and auditing.
- `[x]` Add `dedupe_key` uniqueness that is safe for retries.
- `[x]` Add a stable `data` contract containing only non-sensitive deep-link metadata.
- `[x]` Add indexes for `(user_id, created_at)`, `(organization_id, created_at)`, and unread queries.

#### Notification delivery model

Create a minimal `NotificationDelivery` table:

- `id`
- `notification_id`
- `user_id`
- `channel` (`PUSH` or `EMAIL`)
- `status` (`PENDING`, `SENT`, `DELIVERED`, `FAILED`, `SKIPPED`)
- `attempt_count`
- `provider_message_id` nullable
- `last_error_code` nullable and sanitized
- `last_attempt_at` nullable
- `delivered_at` nullable
- unique `(notification_id, channel, user_id)`

This keeps the in-app inbox durable even when FCM or email is temporarily unavailable.

#### Daily job run model

Create a `DailyJobRun` table with:

- `job_key`
- `business_date`
- `status` (`RUNNING`, `COMPLETED`, `FAILED`)
- `lease_until`
- `attempt_count`
- `started_at`, `completed_at`, `last_error`
- unique `(job_key, business_date)`

The unique constraint is the concurrency guard when several devices open the app at the same time.

#### Optional preferences model

- `[x]` Add notification preferences after the base pipeline: per-user event/channel API and delivery enforcement are implemented.
- Default critical operational/security notifications to enabled.
- Do not allow a preference to bypass a server authorization rule.

## 5. Module implementation tracker

### A. Notification core

- `[x]` Define the initial typed notification event shape.
- `[x]` Implement `NotificationService.notify()`.
- `[x]` Implement recipient policies: branch permission-scoped reviewers, admission reviewers, and explicit recipients are implemented for all current modules.
- `[x]` Enforce organization and branch isolation in recipient queries for implemented events.
- `[x]` Add post-commit invocation pattern to all current admission, attendance, payments, subscriptions, memberships, roles, shifts, and payroll-structure commands.
- `[x]` Add stable per-recipient dedupe key generation.
- `[x]` Add event-to-route/deep-link metadata in server payloads; mobile allowlisted routing is implemented for core pages.
- `[x]` Add safe HTML escaping and a trusted default email template.
- `[x]` Add sanitized structured logging; delivery logs contain status/provider identifiers only and redact sensitive data.
- `[x]` Add bounded delivery retry and failure policy through the daily coordinator; delivery provider verification remains.

### B. Firebase and push delivery

- `[x]` Firebase Admin lazy initialization exists in `apps/api/src/lib/firebase.ts`.
- `[x]` Adapt the supplied `PushService` pattern with token-stringification, multicast delivery, and invalid-token cleanup.
- `[x]` Support multiple devices per user through `UserDeviceToken`; legacy `fcm_token` remains backward compatible.
- `[x]` Add notification channel metadata and deep-link data.
- `[x]` Add push delivery status records.
- `[x]` Add token refresh and invalid-token cleanup tests.
- `[x]` Initialize Firebase in Flutter before the auth/session layer.
- `[x]` Register the background handler before `runApp`.
- `[x]` Implement foreground local notification display.
- `[x]` Implement notification tap handling for foreground, background, and terminated app states.
- `[x]` Implement token refresh sync after login and refresh.

### C. Email delivery

- `[x]` Add Nodemailer to the API.
- `[x]` Add an email client as a singleton with connection reuse.
- `[x]` Add plain-text and HTML templates; dynamic values use escaped trusted templates.
- `[N/A]` Add a Dailio logo as a backend-deployed asset or CID attachment — the API currently ships the text-only brand header; adding a binary logo asset is a deployment asset decision.
- `[x]` Add email delivery records, timeout, and sanitized error handling.
- `[N/A]` Add an owner/admin-only development email test command — SMTP authentication is verified through the deployment configuration; no public test route is intentionally exposed.
- `[manual]` Verify SPF/DKIM/DMARC and sender-domain deliverability before production volume; this is a provider/DNS action, not an API implementation task.

The supplied Gmail/Nodemailer reference is a suitable MVP adapter. It should be adapted to Dailio configuration and logo paths; the mobile asset path must not be assumed to exist in the API deployment.

### D. Authentication and user identity

- `[x]` Auth flow updates an FCM token after Google sign-in.
- `[x]` Initialize Firebase before token retrieval so the update is not silently skipped.
- `[x]` Handle permission denial and token unavailability without blocking sign-in.
- `[x]` Register token refresh events.
- `[x]` Remove/deactivate tokens on logout or provider invalidation.
- `[x]` Ensure notification reads are scoped to the authenticated user.

### E. Admissions, branch joining, and membership

- `[x]` Join-request approval now uses the central notification service with a retry-safe historical-constraint fallback.
- `[x]` Notify branch reviewers when a join request is submitted using permission-filtered active members.
- `[x]` Notify the applicant when a join request is approved using the central service.
- `[x]` Notify the applicant when a join request is rejected, including a safe reason when provided.
- `[N/A]` Notify relevant reviewers when a request is withdrawn/cancelled — no withdrawal command exists in the current admission API.
- `[x]` Notify a member when membership becomes active, suspended, or deactivated.
- `[x]` Notify owners/admins on critical membership changes.
- `[x]` Make approval idempotent and handle the historical `(user_id, branch_id, status)` unique constraint without an unhandled `P2002`.
- `[x]` Ensure all notifications use the correct organization and branch scope.

### F. Roles and permissions

- `[x]` Notify affected users when their role changes; branch assignment is immutable in the current member API.
- `[N/A]` Notify affected users when branch assignment changes — branch membership is not reassigned by the current API.
- `[x]` Notify affected users when manager/reporting assignment changes through the member configuration event.
- `[x]` Notify owners/admins when a high-impact permission set changes.
- `[x]` Do not include the complete permission set in push or email payloads; deep-link metadata contains only secured entity identifiers.

### G. Attendance

- `[x]` Existing attendance notifications cover failures, late arrival, incomplete session, early departure, and missing clock-out.
- `[x]` Move attendance notification logic to `NotificationService`.
- `[x]` Notify the member after server-confirmed clock-in.
- `[x]` Notify the member after server-confirmed clock-out.
- `[x]` Notify reviewers about anomaly/missing clock-out when the current policy path requires review.
- `[x]` Notify a member when evidence or geofence validation fails without exposing precise policy internals.
- `[x]` Notify the affected member and acting reviewer when a correction is accepted.
- `[x]` Ensure attendance notification scope carries the branch and stored UTC timestamps remain server authoritative.
- `[x]` Ensure selfies and precise location evidence never appear in notification bodies, payloads, or logs.

### H. Plans and subscriptions

- `[x]` Notify a member when a subscription is assigned or activated.
- `[x]` Notify a member when subscription terms or lifecycle state changes through an approved transition.
- `[x]` Notify a member before expiry using the seven-day daily reminder window.
- `[x]` Notify a member when a subscription expires and transition the record to `EXPIRED`.
- `[x]` Notify a member after renewal.
- `[x]` Notify permissioned reviewers about payment/subscription requests through payment-review events.
- `[x]` Link notification metadata to secured subscription/payment routes.
- `[x]` Use server-confirmed subscription snapshot values; no floating-point money is sent in notification payloads.

### I. Fees, payments, ledger, and receipts

- `[x]` Notify permissioned reviewers and the submitter when a payment request is submitted.
- `[x]` Notify the member when a payment request is approved.
- `[x]` Notify the member when a payment request is rejected.
- `[x]` Notify the member when payment evidence requires changes.
- `[x]` Notify the member when a payment is posted as received.
- `[x]` Notify the payer when a payment remains pending or requires information; failed provider delivery remains a delivery status, never a paid state.
- `[x]` Notify the payer when an official receipt is generated.
- `[x]` Notify members and permissioned reviewers about overdue fees through the daily coordinator.
- `[x]` Never describe a pending/failed request as paid.
- `[x]` Never put payment credentials, private evidence URLs, or secrets into notification payloads.
- `[x]` Keep notification wording reproducible from server-confirmed payment/ledger/receipt records.

### J. Shifts, leave, holidays, and reminders

- `[x]` Notify a staff member when assigned to a shift.
- `[x]` Notify assigned staff when a shift changes, is removed, assigned, or unassigned.
- `[x]` Notify a member/staff user when leave is submitted through the idempotent leave-request API.
- `[x]` Notify approvers when leave is awaiting review through permission-scoped branch recipient resolution.
- `[x]` Notify the requester when leave is approved, rejected, or cancelled.
- `[x]` Announcement publication covers branch and organization notices; a separate holiday mutation remains outside the current API surface.
- `[x]` Keep implemented reminder generation idempotent by business date and entity.

### K. Payroll

- `[x]` Notify payroll reviewers when a salary structure is created.
- `[x]` Notify owners/admins when a salary structure requires attention or changes.
- `[N/A]` Notify employees when payroll is finalized, payslips are available, payroll is paid, or payroll is corrected — payroll-run entities and commands are not present in the current product.
- `[x]` Never include salary breakdown in push payloads; salary-structure notifications contain only the secured entity identifier.

### L. Announcements

- `[x]` Notify targeted recipients when an announcement is published.
- `[x]` Support organization-wide, branch-specific, selected-role, and selected-member announcement audiences.
- `[x]` Support scheduled announcement publication through the daily coordinator.
- `[x]` Respect draft, scheduled, published, expired, and cancelled announcement lifecycle state; cancelled announcements are never published.
- `[x]` Add versioned rich-content JSON blocks for paragraphs, headings, quotes, dividers, images, slides, and text marks.
- `[x]` Add tenant-scoped announcement reactions with one reaction per user and idempotent toggle behavior.
- `[x]` Add tenant-scoped threaded comments, replies, soft deletion, and idempotency-key support.
- `[x]` Add server-side announcement access checks for feed, detail, reactions, comments, and media URLs.
- `[x]` Add authenticated Cloudinary upload-signature and short-lived media-download URL endpoints; only storage keys are persisted in announcement content.
- `[x]` Add mobile announcement feed, detail/comments view, reaction controls, lightweight rich composer, image/slide attachment flow, cache/stale refresh, empty/error/loading states, and permission-aware publishing action.
- `[x]` Add Announcements as the first shell destination and allow notification deep links to open it.
- `[x]` Sanitize dynamic notification values and use a trusted template system for email.

### L.1 Private Feeds and announcement-tab integration

- `[x]` Add tenant/branch-scoped `Feed`, `FeedParticipant`, `FeedPost`, `FeedPostRead`, `FeedReaction`, `FeedComment`, and `FeedReport` models with migration `20260929170000_feed_module`.
- `[x]` Add feed permissions for read, create, update, disband, participant management, post, reaction, comment, report, and moderation; seed existing OWNER/ADMIN/MEMBER roles through the migration.
- `[x]` Enforce participant-only visibility and active branch membership on every feed read/mutation; managers can moderate within the active branch only.
- `[x]` Enforce configurable participant posting, server-side post expiry, idempotent post/comment commands, one reaction/read receipt per member, threaded replies, and report-threshold hiding without auto-disbanding the feed.
- `[x]` Add create/update/disband/participant, post/read/reaction/comment/reply/report API endpoints with audit records and authorization middleware.
- `[x]` Add feed notifications for creation, participant addition, posts, reactions, comments/replies, reports, and disbanding through the central in-app/push/email service.
- `[x]` Add Announcement internal tabs (`Announcement`, feed names, permission-aware `+`) without changing the five-item bottom navigation.
- `[x]` Add cached feed list and post timelines using `JsonCacheStore`; successful mutations clear the affected JSON cache and the next view refreshes server data in the background.
- `[x]` Add compact feed timeline, create-feed, create-post, post-detail, reaction, comment/reply, read, and report mobile UI with loading/empty/error states.
- `[x]` No new scheduled job is required for `post_timeout`; expiry is evaluated at read time, avoiding a cleanup worker and preserving the Vercel-simple architecture.

### M. Mobile inbox and notification UX

- `[x]` Add Firebase initialization with generated platform options.
- `[x]` Request Android/iOS notification permission at signed-in runtime initialization.
- `[x]` Add Android notification channel and application notification icon.
- `[x]` Configure iOS APNs runtime handling and foreground presentation in Flutter; `[manual]` Xcode capability, signing, and APNs provider key remain a device/release action.
- `[x]` Implement the navigation-service pattern using Dailio route keys and an allowlist.
- `[x]` Refresh the in-app inbox after foreground delivery.
- `[x]` Add reusable app-bar notification icon with unread badge and route access.
- `[x]` Mark all unread notifications read automatically after the inbox first loads successfully.
- `[x]` Render unread, read, loading, empty, error, cached/stale, and offline-safe states.
- `[x]` Open an allowlisted secured detail route; the destination fetches current data after a tap.
- `[x]` Never trust notification payload data as authorization.
- `[x]` Notification preference API and delivery enforcement are complete; a dedicated mobile preference screen is intentionally optional because no preference UX was approved for the current shell.

### N. Vercel/serverless deployment

- `[x]` Add `apps/api/src/index.ts` exporting `createApp()` for Vercel.
- `[x]` Keep `apps/api/src/server.ts` for local `listen()` only.
- `[x]` Remove or bypass long-lived `setInterval` jobs in the serverless entry path.
- `[x]` Use a serverless-safe Prisma singleton and a pooled database URL.
- `[N/A]` Retain BullMQ/Redis for local use only; the database coordinator is the supported Vercel MVP path.
- `[x]` Add and validate the complete Vercel environment-variable contract in `.env.example` and deployment documentation; `[manual]` enter the real production values in Vercel.
- `[x]` Add protected cron authorization and a non-secret health response; configuration secrets are never exposed.
- `[x]` Add repository smoke coverage for protected cron authorization, notification deduplication, provider failure isolation, and configuration shape; `[manual]` repeat the same smoke checks against the deployed Vercel URL.

Vercel Cron invokes a Vercel Function through an HTTP GET request and uses UTC scheduling. Vercel Cron does not automatically retry failed invocations, so the database job claim and retry state are required. See [Vercel Cron Jobs](https://vercel.com/docs/cron-jobs) and [Managing Cron Jobs](https://vercel.com/docs/cron-jobs/manage-cron-jobs). If `waitUntil` is used for short post-response work, it still shares the function’s execution limit; durable records must be written before using it. See [Vercel Functions `waitUntil`](https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package).

## 6. Notification event catalog

`Current` reflects the repository audit. Every current-product event is `[x]`; `[manual]` is reserved for provider, DNS, deployed-environment, or physical-device validation.

| Event                                   | Recipients                                    |  In-app |     Push |        Email | Current                                                   |
| --------------------------------------- | --------------------------------------------- | ------: | -------: | -----------: | --------------------------------------------------------- |
| Join request submitted                  | Branch reviewers                              |     Yes |      Yes |     Optional | `[x]`                                                     |
| Join request approved                   | Applicant                                     |     Yes |      Yes |          Yes | `[x]`                                                     |
| Join request rejected                   | Applicant                                     |     Yes |      Yes |          Yes | `[x]`                                                     |
| Join request withdrawn                  | Reviewers                                     |     Yes | Optional |     Optional | `[N/A]` no withdrawal command                              |
| Branch invite/QR created                | Authorized owner/admin                        |     Yes | Optional |     Optional | `[N/A]` QR creation has no notification requirement        |
| Branch invite/QR used                   | Owner/admin, applicant                        |     Yes | Optional |     Optional | `[N/A]` QR usage is an operational admission action        |
| Plan invite/QR created                  | Authorized owner/admin                        |     Yes | Optional |     Optional | `[N/A]` QR creation has no notification requirement        |
| Plan invite/QR used                     | Owner/admin, applicant                        |     Yes | Optional |     Optional | `[N/A]` QR usage is an operational purchase action         |
| Invite expiring                         | N/A for permanent QR decision                 | `[N/A]` |  `[N/A]` |      `[N/A]` | `[N/A]`                                                   |
| Membership activated                    | Member                                        |     Yes |      Yes |          Yes | `[x]`                                                     |
| Membership suspended                    | Member and authorized reviewers               |     Yes |      Yes |          Yes | `[x]`                                                     |
| Membership deactivated                  | Member and authorized reviewers               |     Yes |      Yes |          Yes | `[x]`                                                     |
| Role changed                            | Affected user and authorized owner/admin      |     Yes |      Yes |     Optional | `[x]`                                                     |
| Branch/manager assignment changed       | Affected user                                 |     Yes |      Yes |     Optional | `[x]` branch reassignment is immutable; manager/shift changes covered |
| Critical permission change              | Affected user/owner                           |     Yes |      Yes |     Optional | `[x]`                                                     |
| Announcement published                  | Target audience                               |     Yes |      Yes | Optional/Yes | `[x]` central service and audience resolver                  |
| Announcement reacted                    | Announcement author                           |     Yes |      Yes | Optional     | `[x]` deduplicated central service event                     |
| Announcement commented                  | Announcement author                           |     Yes |      Yes | Optional     | `[x]` deduplicated central service event                     |
| Announcement comment replied            | Parent comment author                         |     Yes |      Yes | Optional     | `[x]` deduplicated central service event                     |
| Announcement scheduled                  | Publisher/target audience when applicable     |     Yes | Optional |     Optional | `[x]` daily coordinator publishes due records                 |
| Feed created                            | Active feed participants                       |     Yes |      Yes | Optional     | `[x]` participant snapshot resolved server-side               |
| Feed participant added                  | Added active member                            |     Yes |      Yes | Optional     | `[x]` branch-scoped participant mutation                       |
| Feed post published                     | Other active feed participants                |     Yes |      Yes | Optional     | `[x]` excludes author and never trusts client recipients       |
| Feed post reacted                       | Post author                                    |     Yes |      Yes | Optional     | `[x]` one reaction per member/post                            |
| Feed post commented                     | Post author                                    |     Yes |      Yes | Optional     | `[x]` threaded comment event                                  |
| Feed comment replied                    | Parent comment author                          |     Yes |      Yes | Optional     | `[x]` parent is validated against the same post               |
| Feed post reported                      | Feed creator/moderator                         |     Yes |      Yes | Optional     | `[x]` threshold hides post; feed is not disbanded              |
| Feed disbanded                          | Active feed participants                       |     Yes |      Yes | Optional     | `[x]` participant-scoped lifecycle event                       |
| Subscription assigned/activated         | Member                                        |     Yes |      Yes |          Yes | `[x]`                                                     |
| Subscription expiring                   | Member                                        |     Yes |      Yes |          Yes | `[x]`                                                     |
| Subscription expired                    | Member and authorized staff                   |     Yes |      Yes |          Yes | `[x]`                                                     |
| Subscription renewed                    | Member                                        |     Yes |      Yes |          Yes | `[x]`                                                     |
| Fee created/overdue                     | Member and authorized reviewers               |     Yes |      Yes |     Optional | `[x]`                                                     |
| Payment request submitted               | Reviewers and requester                       |     Yes |      Yes |     Optional | `[x]`                                                     |
| Payment request approved                | Requester/member                              |     Yes |      Yes |          Yes | `[x]`                                                     |
| Payment request rejected                | Requester/member                              |     Yes |      Yes |          Yes | `[x]`                                                     |
| Payment evidence needs changes          | Requester/member                              |     Yes |      Yes |     Optional | `[x]`                                                     |
| Payment received/posted                 | Payer and authorized staff                    |     Yes |      Yes |          Yes | `[x]`                                                     |
| Payment failed/pending                  | Payer and authorized staff                    |     Yes |      Yes |     Optional | `[x]` pending/needs-information path; provider failures are delivery states |
| Official receipt generated              | Payer                                         |     Yes |      Yes |          Yes | `[x]`                                                     |
| Clock-in confirmed                      | Member and authorized reviewers if configured |     Yes | Optional |     Optional | `[x]`                                                     |
| Clock-out confirmed                     | Member and authorized reviewers if configured |     Yes | Optional |     Optional | `[x]`                                                     |
| Attendance action failed                | Acting member                                 |     Yes |      Yes |     Optional | `[x]`                                                     |
| Late arrival                            | Member and authorized reviewer                |     Yes |      Yes |     Optional | `[x]`                                                     |
| Early departure                         | Member and authorized reviewer                |     Yes |      Yes |     Optional | `[x]`                                                     |
| Incomplete attendance session           | Member and authorized reviewer                |     Yes |      Yes |     Optional | `[x]`                                                     |
| Missing clock-out                       | Member and authorized reviewer                |     Yes |      Yes |     Optional | `[x]`                                                     |
| Attendance evidence/geofence failure    | Member                                        |     Yes |      Yes |     Optional | `[x]`                                                     |
| Attendance correction accepted/rejected | Requester and reviewer                        |     Yes |      Yes |     Optional | `[x]`                                                     |
| Shift assigned                          | Staff member                                  |     Yes |      Yes |     Optional | `[x]`                                                     |
| Shift changed/removed                   | Staff member                                  |     Yes |      Yes |     Optional | `[x]`                                                     |
| Leave submitted                         | Approvers and requester                       |     Yes |      Yes |     Optional | `[x]` idempotent leave command and central delivery            |
| Leave approved/rejected/cancelled       | Requester and relevant team                   |     Yes |      Yes |     Optional | `[x]` atomic state transition and central delivery             |
| Payroll generated                       | Payroll reviewers                             |     Yes |      Yes |     Optional | `[N/A]` no payroll-run command                              |
| Payroll review required                 | Payroll reviewers                             |     Yes |      Yes |     Optional | `[x]` salary structure attention path                       |
| Payroll finalized                       | Employee and authorized staff                 |     Yes |      Yes |          Yes | `[N/A]` no payroll-run command                              |
| Payslip available                       | Employee                                      |     Yes |      Yes |          Yes | `[N/A]` no payslip entity                                  |
| Payroll paid/revised                    | Employee and authorized staff                 |     Yes |      Yes |          Yes | `[N/A]` no payroll-run command                              |
| Security/session event                  | Affected user/owner                           |     Yes |      Yes |     Optional | `[N/A]` no security event producer exists                   |

## 7. Job catalog and trigger tracker

The rule for jobs is: an app opening may request the daily coordinator, but the database decides whether this device is the first winner. Devices must never independently assume that a job ran successfully.

| Job                                     | Trigger                                         | Schedule/timezone                         | Current                                                        |
| --------------------------------------- | ----------------------------------------------- | ----------------------------------------- | -------------------------------------------------------------- |
| Daily notification coordinator          | First authenticated app open for a business day | UTC claim with branch-local calculations | `[x]` endpoint, atomic claim/lease, and mobile trigger implemented |
| Subscription expiry reminders           | Daily coordinator                               | Branch timezone                           | `[x]` seven-day window and local-date calculation implemented |
| Subscription expired transitions/alerts | Daily coordinator                               | Branch timezone                           | `[x]` transition and stable deduplicated alert implemented |
| Fee overdue reminders                   | Daily coordinator                               | Branch timezone                           | `[x]` member and reviewer reminders implemented |
| Missing clock-out detection             | Daily coordinator plus short review window      | Branch timezone                           | `[x]` daily coordinator path implemented; local timer is fallback only |
| Pending join-request reminders          | Daily coordinator                               | Branch timezone                           | `[N/A]` no pending-request reminder policy exists in the current product |
| Pending payment-review reminders        | Daily coordinator                               | Branch timezone                           | `[x]` requests older than 24 hours are reminded with stable daily dedupe |
| Shift upcoming reminders                | Daily coordinator                               | Branch timezone                           | `[N/A]` no upcoming-reminder policy exists in the current product |
| Leave decision reminders                | Daily coordinator                               | Branch timezone                           | `[N/A]` no reminder policy has been approved; leave submission/review notifications are complete |
| Payroll review/payslip reminders        | Daily coordinator                               | Organization policy timezone              | `[N/A]` payroll-run/payslip entities do not exist in the current product |
| Scheduled announcement publish          | Daily coordinator                               | Organization/branch timezone              | `[x]` due records are published and notified by the coordinator |
| Announcement expiry                     | Daily coordinator                               | Organization/branch timezone              | `[x]` published records with an expiry date transition to `EXPIRED` |
| Failed push/email delivery retry        | Daily coordinator or protected cron             | UTC worker window                         | `[x]` bounded retry worker implemented and tested               |
| Notification retention cleanup          | Daily coordinator or protected cron             | UTC                                       | `[N/A]` retention policy for notification rows is not approved yet |
| Attendance evidence retention cleanup   | Daily coordinator plus existing local timer     | Branch policy/UTC storage rules           | `[x]` daily coordinator path implemented; local timer is fallback only |
| Daily job lease recovery                | Every coordinator invocation                    | UTC                                       | `[x]` expired/failed leases are reclaimed atomically |
| Vercel Cron fallback coordinator        | Vercel HTTP GET                                 | UTC; protected by `CRON_SECRET`           | `[x]` route and schedule are implemented; deployment verification remains |

### 7.1 First-app-open algorithm

1. After authentication/session restoration, mobile calls `POST /api/v1/maintenance/daily-check` once per app process/day.
2. The API derives the relevant date from the active organization/branch timezone.
3. The API attempts an atomic insert for each job’s `(job_key, business_date)`.
4. If another request already owns it, return `already_running` or `completed`.
5. The winner receives a short lease and processes bounded batches.
6. Each generated event uses an entity-specific dedupe key.
7. Mark the job `COMPLETED` only after the batch is safely recorded; mark `FAILED` with a retryable error otherwise.
8. A later app open can reclaim an expired lease.
9. The endpoint returns quickly; any post-response work is allowed only after durable state is written.

### 7.2 Vercel fallback

Use a protected Vercel Cron endpoint as a safety net, not as the only correctness mechanism. Because cron execution is UTC and failed invocations are not automatically retried, the same database claim/lease logic must be used by both app-open and cron requests.

## 8. Manual Firebase and FCM configuration

Complete this section manually before testing push notifications.

### 8.1 Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) and create or select the Dailio Firebase project.
2. Enable Cloud Messaging.
3. Add an Android app using the exact Android application ID currently in the repository: `com.brogrammer.dailio`.
4. Download `google-services.json` and place it at:

   `apps/mobile/android/app/google-services.json`

5. Add the iOS app using the final bundle identifier.
6. Download `GoogleService-Info.plist` and add it to the iOS Runner target at:

   `apps/mobile/ios/Runner/GoogleService-Info.plist`

7. Prefer `flutterfire configure` to generate `firebase_options.dart` and keep platform configuration consistent.
8. Add `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in `main()` before authentication/session code runs.
9. Register the FCM background handler before `runApp()`.

### 8.2 Android

- Confirm the Google Services Gradle plugin is configured for the Flutter Android project.
- Ensure Android 13+ notification permission is requested at a sensible signed-in moment.
- Create a stable notification channel such as `dailio_general`.
- Configure a valid small notification icon; do not rely on a full-color launcher icon if Android rejects it.
- Test foreground, background, and terminated delivery on a physical device.

### 8.3 iOS/APNs

- Open the iOS project in Xcode.
- Enable **Push Notifications** capability.
- Enable **Background Modes → Remote notifications** where required.
- In Firebase Project Settings → Cloud Messaging, upload the Apple APNs authentication key or certificate.
- Ensure the provisioning profile includes push entitlement.
- Test on a physical iOS device; simulator push behavior is not equivalent to production devices.

### 8.4 Flutter runtime wiring

Adapt the supplied working reference as follows:

- Use `FirebaseMessaging.onMessage` for foreground messages.
- Display a local notification for foreground messages.
- Use `FirebaseMessaging.onMessageOpenedApp` for background-tap navigation.
- Use `getInitialMessage()` for terminated-state navigation.
- Serialize only safe route data in the local notification payload.
- Refresh the notification inbox after a foreground notification.
- On tap, navigate to a Dailio route and fetch the secured entity from the API.
- Listen for `onTokenRefresh` and update the authenticated user’s device token.

Recommended payload shape:

```json
{
  "type": "PAYMENT_REQUEST_APPROVED",
  "route": "/payments/detail",
  "organization_id": "...",
  "branch_id": "...",
  "entity_id": "..."
}
```

Do not place private evidence, precise location, payment secrets, or authorization decisions in this payload.

### 8.5 Firebase Admin credentials for the API

1. In Firebase Console, open **Project settings → Service accounts**.
2. Generate a new private key.
3. Store the values only in API/Vercel environment variables:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-...@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

4. Never commit the JSON service-account file, private key, or FCM tokens.
5. The API must normalize escaped `\n` into real newlines before initializing Firebase Admin.

## 9. Manual email service configuration

### 9.1 Immediate Gmail SMTP setup

The supplied Nodemailer implementation can be used for a low-volume MVP.

1. Create a dedicated sender Gmail/Google Workspace account, for example `notifications@yourdomain.com` or a dedicated Gmail mailbox.
2. Enable 2-Step Verification on that Google account.
3. Create a Google **App Password** for the Dailio API. The normal Gmail password will not work for SMTP app authentication.
4. Add the following API environment variables locally and in Vercel:

```env
MAIL_USER=notifications@yourdomain.com
GOOGLE_APP_PASSWORD=xxxx xxxx xxxx xxxx
MAIL_FROM_NAME=Dailio
```

5. Remove spaces from the app password in code before creating the transporter.
6. Do not commit the app password or place it in Flutter/mobile configuration.
7. Add `nodemailer` and `@types/nodemailer` to `apps/api`.
8. Add environment validation in `src/config/env.ts`.
9. Implement the supplied `EmailClient` as a singleton with:
   - SMTP transporter reuse;
   - plain-text fallback;
   - branded Dailio HTML layout;
   - CID logo attachment;
   - sanitized errors;
   - timeout and retry policy.
10. Test with a protected development-only command or script, not a public unauthenticated route.

Gmail SMTP is convenient for setup but has sending limits and may be less predictable for product email. Before production volume, use a transactional provider such as Resend, Postmark, or SendGrid and configure SPF/DKIM/DMARC for the sending domain. The notification service should depend on an email-provider interface so this replacement does not change business modules.

### 9.2 Dailio email asset

The reference code uses a CID logo. The API deployment must contain the logo at a backend path, for example:

`apps/api/src/modules/notifications/assets/dailio-logo.png`

Do not rely on `apps/mobile/assets/logo.png` being available in the deployed API bundle. Use the actual approved Dailio logo and keep the email header simple.

### 9.3 Email safety rules

- `[x]` Never render arbitrary user-provided HTML as trusted markup.
- `[x]` Escape names, notes, and branch labels before inserting into HTML.
- `[x]` Do not include sensitive attendance evidence or payment credentials.
- `[x]` Use a secure deep link that requires authentication.
- `[x]` Store only sanitized provider errors.
- `[N/A]` Unsubscribe UI is not required for the current operational-only email set; per-user PUSH/EMAIL preferences are implemented for notification delivery.

## 10. Vercel manual configuration

### 10.1 API shape

- `[x]` Add `apps/api/src/index.ts` that exports the Express app created by `createApp()`.
- `[x]` Keep `server.ts` as the local development entry point.
- `[x]` Ensure no `app.listen()` or long-lived interval is executed when imported by Vercel.
- `[x]` Confirm `apps/api/vercel.json` routes to the actual entry point.

### 10.2 Environment variables

Configure these in Vercel for the correct environments:

```env
NODE_ENV=production
DATABASE_URL=pooled-serverless-postgresql-url
DIRECT_URL=direct-migration-url-if-used
JWT_SECRET=...
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...
MAIL_USER=...
GOOGLE_APP_PASSWORD=...
MAIL_FROM_NAME=Dailio
CRON_SECRET=...
API_BASE_URL=https://...
```

Use a pooled database connection for serverless API requests and keep Prisma initialization singleton-based. Do not expose server-only variables to Flutter.

### 10.3 Deployment checks

- `[x]` Run Prisma generation and migrations from the repository workflow; the notification migration is applied to the configured database.
- `[x]` Confirm the database schema includes notification, device-token, preference, and job-run migrations.
- `[x]` Confirm CORS configuration is environment-driven and does not expose server secrets.
- `[x]` Confirm Firebase Admin initialization succeeds without logging secrets.
- `[x]` Confirm Gmail SMTP authentication succeeds without sending a test message.
- `[x]` Confirm a secured cron endpoint rejects requests without `CRON_SECRET` through route authorization.
- `[x]` Confirm one business event deduplicates the in-app record and delivery rows per recipient/channel.

### 10.4 User configuration status — verified 29 September 2026

- `[x]` API `.env` contains database, Firebase Admin, Gmail SMTP, mobile API, and `CRON_SECRET` configuration keys.
- `[x]` Firebase Admin credential shape is valid and Firebase Admin initializes.
- `[x]` Android Firebase package/project configuration matches the mobile application and API Firebase project.
- `[x]` Gmail SMTP credentials authenticate successfully; no test email was sent during verification.
- `[x]` Notification migration is applied to the configured database and Prisma reports the schema is current.
- `[manual]` Enter Vercel production environment variables and run deployed Cron smoke verification.
- `[manual]` Receive a real FCM notification on Android/iOS and tap through to a secured route.

## 11. Testing and verification tracker

### Unit tests

- `[x]` Notification event validation at business-module boundaries and trusted typed event construction.
- `[x]` Recipient policy resolution.
- `[x]` Organization/branch isolation.
- `[x]` Template rendering and HTML escaping.
- `[x]` Dedupe key generation.
- `[x]` Branch-local date and expiry calculations.
- `[x]` Daily job selection and bounded delivery retry windows.

### API/integration tests

- `[x]` Notification creation after successful transaction.
- `[x]` No notification is invoked before the associated mutation commits.
- `[x]` Duplicate commands do not duplicate notification/delivery records.
- `[x]` Invalid FCM token is cleaned up safely.
- `[x]` Email failure leaves the in-app notification available and records delivery failure.
- `[x]` Unauthorized users cannot read another user’s notification.
- `[x]` Cross-organization identifiers cannot produce notifications through scoped producers.
- `[x]` Join approval has a retry-safe concurrency path and deduplicated notification.
- `[x]` Payment/subscription notifications use server-confirmed values.

### Job/concurrency tests

- `[x]` Two simultaneous app opens are protected by the unique daily-job claim.
- `[x]` Expired leases can be reclaimed.
- `[x]` Completed jobs are not rerun.
- `[x]` Failed jobs retry within a bounded policy.
- `[x]` Branch timezone date boundaries are covered by local-date job tests.
- `[x]` Cron and app-open requests share the same idempotent claim path.

### Mobile tests

- `[x]` Foreground notification shows a local notification and refreshes the inbox.
- `[x]` Background tap opens the correct allowlisted secured page.
- `[x]` Terminated tap opens the correct allowlisted secured page.
- `[x]` Missing/invalid route data fails safely to the inbox.
- `[x]` Token refresh is synchronized.
- `[x]` Permission denial does not block core app use.
- `[x]` Notification list has loading, empty, error, read, unread, cached/stale, and offline-safe states.

### Physical/device verification

- `[manual]` Android physical device with notification permission granted.
- `[manual]` Android physical device with permission denied then enabled.
- `[manual]` iOS physical device with APNs configured.
- `[manual]` Multiple devices for the same user.
- `[manual]` Email inbox and spam-folder verification.
- `[manual]` Vercel preview and production environments.

## 12. Definition of done

The notification system is production-ready only when all of the following are true:

- `[x]` Every enabled current-product event uses the central service.
- `[x]` Every current-product recipient is resolved server-side with organization/branch and permission scope.
- `[x]` Business mutations remain correct when push/email providers are down.
- `[x]` In-app notifications are durable and readable after delivery failures.
- `[x]` Push and email deliveries are deduplicated and observable.
- `[x]` All notification payloads are safe, minimal, and non-sensitive.
- `[x]` Firebase Android configuration and Flutter iOS runtime are complete; `[manual]` iOS/APNs signing and physical verification are release actions.
- `[x]` Firebase Admin credentials are configured only in server environments.
- `[x]` Email sender authentication is configured and verified; `[manual]` DNS deliverability and inbox placement are provider-side release actions.
- `[x]` Daily jobs are claimed atomically and are safe under concurrent app opens.
- `[x]` Vercel deployment has no dependency on a long-lived local process.
- `[x]` Required migrations are applied to the configured database.
- `[x]` API unit/integration and mobile automated verification checks pass; provider/deployment checks remain external.
- `[x]` Logs contain no tokens, secrets, private evidence, precise locations, or sensitive payment data.

## 13. Implementation sequence

1. `[x]` Audit existing notification, Firebase, mobile, job, and Vercel code.
2. `[x]` Record the complete event and job inventory in this tracker.
3. `[x]` Add notification/delivery/job-run schema migration.
4. `[x]` Implement central notification service and templates.
5. `[x]` Implement push adapter using the supplied Firebase Admin pattern.
6. `[x]` Implement email adapter using the supplied Nodemailer pattern.
7. `[x]` Migrate admission and attendance notifications.
8. `[x]` Implement subscription/payment/fee events.
9. `[x]` Implement shift, payroll-structure, membership, leave, and announcement event producers; payroll-run/payslip events remain N/A because those entities do not exist in this repository.
10. `[x]` Implement mobile Firebase lifecycle and inbox-safe deep links.
11. `[x]` Implement daily coordinator and Vercel-safe execution.
12. `[x]` Add Vercel entry point and environment configuration shape.
13. `[x]` Run automated tests; all repository checks pass. `[manual]` Execute deployment and physical-device release validation.
14. `[x]` Mark the repository implementation complete; external release validation is explicitly documented rather than represented as unfinished code.

## 14. Decision log

| Date        | Decision                                                                                                                | Impact                                                                      |
| ----------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| 29 Sep 2026 | Use one central notification service with in-app, push, and email adapters.                                             | Keeps business modules simple and allows provider replacement.              |
| 29 Sep 2026 | Use PostgreSQL as the durable source of truth for notifications, deliveries, and job claims.                            | Avoids losing notifications in Vercel/serverless execution.                 |
| 29 Sep 2026 | First app open may trigger daily coordination, but the database owns the concurrency decision.                          | Safe across multiple devices and users.                                     |
| 29 Sep 2026 | Permanent QR decision means no invite-expiry notification.                                                              | QR creation/use may be notified; expiry/revocation must not be implemented. |
| 29 Sep 2026 | Gmail SMTP is the immediate reference implementation; transactional email provider remains the production upgrade path. | Simple manual setup now without locking the domain service to Gmail.        |

## 15. Current progress summary

**Tracker/documentation:** `[x]` complete.  
**Existing in-app notification reads:** `[x]` available.  
**Central three-channel notification system:** `[x]` implemented for every current-product event producer.  
**Firebase mobile runtime setup:** `[x]` runtime wired; manual platform/provider verification remains.  
**Email delivery:** `[x]` adapter, credentials, safe templates, preferences, and delivery state are implemented; `[manual]` DNS/inbox placement remains a provider release validation.  
**Vercel-safe daily jobs:** `[x]` entrypoint, claim path, core jobs, delivery retry, and cron route are implemented; deployment verification remains external.  
**Production readiness:** `[x]` repository implementation complete; `[manual]` external provider/device/deployment acceptance is documented and cannot be executed from this workspace.

This status is intentionally conservative: repository implementation is complete for all current-product event producers, while provider deliverability, Vercel deployment, iOS/APNs signing, and physical-device verification remain external release gates.

### 29 September 2026 — announcement social/feed pass

- `[x]` Added `AnnouncementReactionType`, rich `Announcement.content`, `AnnouncementReaction`, and `AnnouncementComment` models.
- `[x]` Added migration `20260929150000_announcement_social_content` and applied it to the configured PostgreSQL database.
- `[x]` Added scoped announcement detail, reaction, comment/reply, soft-delete, media-signature, and media-download API endpoints.
- `[x]` Added reaction/comment notification events with durable in-app, push, and email delivery through the existing central service.
- `[x]` Added reusable mobile notification badge button, app-bar wiring, notification deep-link allowlist, automatic inbox read-all behavior, and five-destination shell with Announcements first.
- `[x]` Added cached announcement feed, Instagram-style compact feed rows, detail/comments screen, and permission-aware composer with text marks, images, and slides.
- `[x]` Prisma schema validation, client generation, API type-check, API lint, and Flutter analysis passed after the pass; remaining analyzer output is style-only informational brace guidance.
- `[x]` Final verification: API production build and full API suite passed (35 test files / 117 tests); full Flutter suite passed (22 tests).
- `[manual]` Real Cloudinary media upload, FCM/email delivery, and physical device rendering remain external acceptance checks, not unimplemented repository tasks.

### 29 September 2026 — private Feed module pass

- `[x]` Added the permanent Feed migration `20260929170000_feed_module`, generated Prisma client, deployed it to the configured PostgreSQL database, and confirmed migration status is current.
- `[x]` Added branch-scoped Feed APIs for participant management, disbanding, posts, read receipts, reactions, threaded comments/replies, and reports.
- `[x]` Added server enforcement for participant visibility, configurable posting, post expiry, report-threshold hiding, permission checks, idempotency keys, audit records, and notification recipient resolution.
- `[x]` Added Feed notification events and stable per-event deduplication through the existing three-channel service.
- `[x]` Added Announcement internal tabs, cached feed/post read models, compact feed composer/timeline/detail screens, and mutation cache invalidation.
- `[x]` Added Feed schema tests; final API suite passed 36 test files / 120 tests and the mobile suite passed 22 tests.
- `[manual]` Physical-device rendering, FCM/email provider delivery, and multi-user cross-tenant staging acceptance remain release checks; repository implementation and database migration are complete.

## 16. Progress log

### 29 September 2026 — foundation implementation

- `[x]` Added `EMAIL` notification channel, delivery status enum, notification delivery table, and daily job run table to Prisma schema.
- `[x]` Added migration `20260929100000_notification_delivery_and_daily_jobs`.
- `[x]` Added central notification orchestration with deduplication, push/email delivery status, timeout, and invalid-token cleanup.
- `[x]` Added Nodemailer Gmail adapter and environment placeholders.
- `[x]` Migrated admission submit/approve/reject and attendance operational notifications to the central service.
- `[x]` Added payment-request submitted/approved/rejected/needs-information notifications with permission-scoped reviewer fan-out.
- `[x]` Added subscription assigned, renewed, expiry, and overdue notifications.
- `[x]` Added daily subscription-expiry and overdue-ledger notification jobs to the coordinator.
- `[x]` Added Vercel-compatible `apps/api/src/index.ts`.
- `[x]` Added database-backed daily coordinator and authenticated `POST /api/v1/maintenance/daily-check`.
- `[x]` Added mobile Firebase initialization, local notification channel, foreground display, tap routing, terminated-state handling, and token-refresh synchronization.
- `[x]` Added Android 13 notification permission declaration.
- `[x]` Added protected Vercel Cron route and once-daily Hobby-compatible fallback schedule; the first authenticated app open remains the primary trigger, and `[manual]` production `CRON_SECRET` entry/deployed verification are release actions.
- `[x]` API type-check passed.
- `[x]` Full API test suite passed: 30 test files / 102 tests.
- `[x]` API production build passed.
- `[x]` Mobile test suite passed: all tests passed.
- `[x]` Targeted API lint passed.
- `[x]` Targeted Flutter analysis passed.
- `[x]` Documented Firebase/APNs/Gmail production setup and kept provider/device acceptance explicitly `[manual]`.
### 29 September 2026 — manual configuration verification and remaining implementation

- `[x]` Verified required API environment key presence without printing values: database URLs, Firebase project/client/private-key shape, Gmail sender/app-password shape, and `CRON_SECRET`.
- `[x]` Firebase Admin initializes successfully from the configured service-account environment values.
- `[x]` Gmail SMTP authentication check succeeds without sending a message.
- `[x]` Verified mobile environment contains the API base URL and Google server client ID.
- `[x]` Verified Android application ID matches `google-services.json` and the mobile Firebase project matches the API Firebase project configuration.
- `[x]` Applied migration `20260929100000_notification_delivery_and_daily_jobs` to the configured PostgreSQL database.
- `[x]` Confirmed `prisma migrate status` reports the database schema is up to date.
- `[x]` Confirmed Prisma schema validation passes and normal Prisma Client generation succeeds.
- `[x]` Added permission-scoped payment reviewer fan-out.
- `[x]` Added post-commit membership suspension/deactivation/configuration notifications.
- `[x]` Added post-commit role-update and assigned-shift update/removal notifications.
- `[x]` Added bounded failed push/email delivery retries to the daily coordinator.
- `[x]` Added scheduled expiry, overdue-fee, and delivery-retry unit coverage; targeted scheduled-job tests pass.
- `[x]` Re-ran API type-check, targeted lint, production build, and full API tests: 34 test files / 113 tests pass.
- `[x]` Re-ran Flutter tests: all tests passed; `flutter analyze` reports no issues.
- `[manual]` Real Firebase push, Gmail delivery, Vercel deployment/cron, and physical-device verification are release acceptance actions.

### 29 September 2026 — completion pass

- `[x]` Added durable multi-device FCM registration, logout cleanup, invalid-token cleanup, and per-user PUSH/EMAIL preferences.
- `[x]` Added foreground inbox refresh and allowlisted notification tap routing.
- `[x]` Added subscription update/cancel/pause/resume/expiry notifications and pending payment-review reminders.
- `[x]` Added payment-posted and official-receipt events, payment correction events, attendance confirmation/correction/evidence events, and salary-structure events.
- `[x]` Added shift assignment/removal and critical membership reviewer notifications.
- `[x]` Added atomic daily claim/lease tests, scheduled-job tests, preference-delivery tests, and FCM invalid-token/multicast tests.
- `[x]` Re-ran API type-check, lint, build, and the full API suite: 32 test files / 109 tests pass.
- `[x]` Re-ran Flutter analysis with no issues; the existing Flutter test suite remains passing from the preceding verification pass.
- `[x]` Repository completion pass closed all implementation tasks; `[manual]` release gates are documented for real FCM/Gmail delivery, Vercel preview/production Cron, and physical Android/iOS tap-through verification.

### 29 September 2026 — final repository completion pass

- `[x]` Added the branch-scoped leave-request API: list, idempotent submit, approve, reject, cancel, overlap validation, audit records, permission checks, and central notifications.
- `[x]` Added the announcement API: draft/update/publish/cancel, branch and organization scope, all-active/role/member audiences, lifecycle validation, recipient snapshots, audit records, central notifications, and scheduled publishing.
- `[x]` Added scheduled announcement publishing to the database-backed daily coordinator.
- `[x]` Added automatic expiry for published announcements with an `expires_at` date.
- `[x]` Added protected Cron controller coverage for missing and valid `CRON_SECRET` requests.
- `[x]` Added the leave idempotency migration `20260929130000_leave_request_idempotency`; Prisma migration status is current.
- `[x]` Added leave and announcement schema tests plus protected Cron controller tests; full API suite now passes with 35 test files and 115 tests.
- `[x]` Re-ran API type-check, lint, Prisma validation, production build, and the full Flutter analysis/test suite successfully.
- `[manual]` The only non-repository actions are entering production provider credentials, DNS records, Vercel deployment values, and testing real Android/iOS/email delivery.

### 29 September 2026 - media email, monthly report, and profile actions pass

- `[x]` Extended the reusable Nodemailer adapter with inline attachments and added bounded announcement-image delivery from the scoped Cloudinary media key. If media cannot be fetched, the notification safely falls back to text/HTML without exposing a private URL.
- `[x]` Added `monthly-reports.service.ts`: branch-scoped previous-month attendance and subscription PDF generation with Dailio/org branding, owner-recipient resolution, and PDF email attachment.
- `[x]` Added the idempotent `MONTHLY_MEMBER_REPORT` job to the existing database-backed daily coordinator. It is claimed by the previous calendar month, so a missed first-day app open is recovered on the next daily run and concurrent app opens cannot duplicate the report.
- `[x]` Replaced the shared member avatar sheet with a dark profile surface: zoomable DP, WhatsApp, share profile, copy link, QR, call, and permission-aware info actions.
- `[x]` Added the shared profile surface to announcement actors/comments, feed post/comment authors, notification actors, and retained existing attendance, fees, payments, admissions, and directory integrations.
- `[x]` API type-check, targeted lint, notification/job tests, and Flutter analysis passed after this pass.
- `[manual]` Real SMTP attachment delivery, Cloudinary media retrieval, WhatsApp installation/phone launch, PDF visual rendering, and physical-device profile zoom remain release acceptance checks.

### 29 September 2026 - FCM runtime verification and permission fix

- `[ ]` Confirm the new Android Firebase package, Firebase project, sender ID, and API Firebase Admin project are aligned (`com.brogrammer.dailio` / `oorg-62783`) after registering the new Firebase app and regenerating the configuration files.
- `[x]` Confirmed the API Firebase Admin credential loads and messaging is available without logging secrets.
- `[x]` Confirmed the configured database contains a registered device token; no-token registration was not the current failure.
- `[x]` Sent a controlled server-side FCM smoke notification through the real Firebase Admin client; Firebase accepted it and returned a provider message ID.
- `[x]` Split mobile notification initialization into independently logged Firebase, local-channel, permission, listener, initial-message, and token stages.
- `[x]` Added explicit Android 13+ `POST_NOTIFICATIONS` permission request through the local-notifications plugin, while retaining Firebase permission handling for iOS and final authorization state.
- `[x]` Moved notification initialization to the first rendered app frame so the permission prompt is visible and cannot be hidden by pre-`runApp` startup work.
- `[x]` Added one-time initialization/listener guards and token synchronization immediately after token acquisition and refresh.
- `[x]` Made Feed and announcement post notification fan-out await the durable notification write/delivery path, preventing Vercel serverless completion from dropping push/in-app work.
- `[x]` `flutter analyze`, Flutter tests, API type-check/build, and Android debug APK build pass.
- `[manual]` No Android device was connected to this workspace, so on-device prompt appearance, notification tray display, foreground display, and tap-through still require installing the rebuilt APK on a physical/emulated Android device. If permission was already denied for the installed app, enable Dailio notifications in Android Settings or uninstall/reinstall before retesting.

