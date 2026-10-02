# Dailio Web Application and QR Flow Plan

**Status:** Draft for product review  
**Prepared:** 2026-10-02  
**Repository:** `C:\F0526\Quest\gym`  
**Planned frontend:** React + TypeScript + Tailwind CSS  
**Primary goal:** Let members use the most important Dailio flows from a phone browser after scanning a printed QR code, without requiring the mobile app.

This is a planning document only. It does not authorize implementation, schema changes, API changes, deployment, or changes to `CONTEXT.md` until the product decisions marked **OPEN** are reviewed and approved.

---

## 1. Executive summary

The repository already has:

- a modular TypeScript/Express API in `apps/api`;
- a Flutter mobile application in `apps/mobile`;
- an empty `apps/web` directory;
- permanent opaque QR invites for branch admission and subscription-plan purchase;
- permanent branch QR attendance where the server determines the next action as clock-in or clock-out;
- tenant-aware permissions, attendance evidence rules, payment-request review, immutable ledger behavior, and OpenAPI generation.

The web application should therefore be a new client of the existing API, not a second business-logic implementation. It should reproduce the member-facing mobile experience with React and Tailwind, preserve the existing Dailio visual system, and add browser-safe deep-link handling for printed QR codes.

The delivery should be staged:

1. **QR/member MVP:** login, QR resolution, QR attendance, plan purchase, payment evidence, self attendance/fees, and status pages.
2. **Member web parity:** the remaining self-service mobile screens.
3. **Permission-aware operator parity:** owner/admin/staff screens when the QR/member release is stable.

This order gives the gym a useful browser experience quickly while keeping the larger “everything in mobile also exists on web” target intact.

---

## 2. Product outcome

### 2.1 Member experience

A member scans a printed QR at the gym or on a plan poster:

1. The phone opens the web application.
2. If unauthenticated, the member signs in with Google.
3. The web application restores the original QR intent after login.
4. The server resolves the opaque invite token and determines the organization, branch, purpose, membership state, plan, attendance policy, and next allowed action.
5. The member completes the permitted flow in a mobile-shaped Dailio UI.
6. The browser shows a clear server-confirmed result, or a pending/error/forbidden state that is never presented as success.

### 2.2 Supported QR purposes

The plan follows the approved product rules in `CONTEXT.md`:

- **Branch QR:** permanent, reusable branch admission QR and physical gate attendance QR.
- **Plan QR:** permanent, reusable purpose-bound subscription purchase QR for one active plan.
- Existing permanent QR tokens remain valid. New web-compatible QR payloads must not invalidate or replace older printed codes.

### 2.3 UI outcome

The browser experience will use the same:

- Dailio logo and Space Grotesk typography;
- orange, white, black, and approved semantic status palette;
- compact page density, flat rows, app bar, tabs, badges, cards, loading skeletons, and bottom navigation language;
- member terminology, states, copy, and server-confirmed behavior;
- responsive mobile-first layout.

“Exactly the same UI” will mean visual and behavioral parity with the mobile app at phone widths, while still meeting browser accessibility, keyboard, back-button, refresh, and desktop requirements. Literal Flutter pixel reuse is not possible; the design tokens and screen contracts will be reproduced in React/Tailwind.

---

## 3. Current repository reality

### 3.1 Existing applications

```text
apps/
  api/       TypeScript + Express + Prisma + PostgreSQL API
  mobile/    Flutter/Dart Dailio app
  web/       Present but currently empty
```

### 3.2 Existing API organization

The API uses a modular monolith with controller/service/schema/routes boundaries:

```text
apps/api/src/
  config/
  docs/
  jobs/
  lib/
  middleware/
  modules/
    admissions/
    announcements/
    attendance/
    attendance-streaks/
    auth/
    authorization/
    branches/
    feeds/
    holidays/
    invites/
    leave/
    members/
    notifications/
    organizations/
    payments/
    payroll/
    plans/
    roles/
    shifts/
    subscriptions/
    users/
  routes/
  types/
```

The web application will mirror these **module boundaries and names**, but its files will be React client files rather than Express controllers or Prisma services. It must not copy server authorization or financial logic into the browser.

### 3.3 Existing QR/API capabilities

Relevant API routes already exist under `/api/v1`:

```text
GET  /invites/:token
POST /join-invites/:token/requests
POST /attendance/qr-punch
POST /purchase-invites/:token/subscription-drafts

POST /branches/:branch_id/join-invites
POST /branches/:branch_id/plans/:plan_id/purchase-invites
```

The API currently:

- stores only a SHA-256 hash of an opaque invite token;
- resolves organization and branch from the token, not from client-supplied tenant data;
- derives attendance clock-in versus clock-out from server state;
- supports idempotency keys for retry-prone commands;
- snapshots subscription plan terms into subscriptions;
- keeps manual payment evidence in `REQUESTED` until an authorized reviewer confirms it;
- records audit entries for sensitive operations.

### 3.4 Existing mobile references to reuse as contracts

The implementation team must inspect and use these as behavior/design references:

- `apps/mobile/lib/core/theme/app_colors.dart`
- `apps/mobile/lib/core/theme/app_typography.dart`
- `apps/mobile/lib/core/theme/app_theme.dart`
- `apps/mobile/lib/core/widgets/app_shell.dart`
- `apps/mobile/lib/features/context_selection/pages/qr_scanner_page.dart`
- `apps/mobile/lib/features/attendance/pages/gate_attendance_page.dart`
- `apps/mobile/lib/features/fees/pages/subscription_purchase_page.dart`
- `apps/mobile/lib/features/fees/pages/fees_page.dart`
- `apps/mobile/lib/features/attendance/pages/attendance_page.dart`
- mobile repositories for auth, invites, attendance, fees, payments, and branch context.

### 3.5 Existing repository status

At planning time there are unrelated deleted documentation files in the worktree. They are preserved and must not be restored, staged, or modified as part of the web project.

---

## 4. Scope and release boundaries

### 4.1 Release 1: QR/member web MVP

The first production-capable web release should include:

- Google authentication;
- session restoration and logout;
- QR deep-link intake and server resolution;
- branch QR join/pending/member state;
- branch QR attendance clock-in/out;
- browser geolocation and live camera selfie when the effective policy requires them;
- plan QR purchase wizard;
- server-created subscription draft;
- manual payment evidence upload and payment-request submission;
- member Fees view with Paid / Requested / Pending states;
- member Self Attendance and attendance result/detail views;
- payment/subscription/attendance success, pending, forbidden, conflict, and retry states;
- responsive mobile-first shell matching mobile UI;
- analytics/observability that never records raw QR tokens, selfies, precise locations, payment evidence, secrets, or raw payment data.

### 4.2 Release 2: member self-service parity

Add the remaining member-facing capabilities already represented in mobile:

- profile and settings;
- context switcher;
- announcements and private feeds;
- notifications;
- self attendance record/history;
- subscriptions and payment history/detail;
- leave requests;
- holiday visibility where permitted;
- member profile/streak summaries;
- authorized payslip/self payroll views.

### 4.3 Release 3: permission-aware operator parity

Add web screens for owners, admins, and authorized staff:

- organization and branch management;
- roles and permissions;
- members/admissions/hierarchy;
- attendance operations, ongoing activity, evidence, corrections, and exports;
- plan/subscription configuration;
- payment-request review, ledger, refunds/voids where authorized;
- shifts, leaves, holidays;
- salary eligibility, salary structures, payroll, payslips;
- announcements, feeds, reports, audit, and operational settings.

### 4.4 Explicit non-goals for Release 1

- rewriting the mobile application;
- changing the payment business rules to make a submitted request immediately paid;
- bypassing selfie/location/QR attendance policy for browser convenience;
- accepting organization, branch, plan, price, member, or attendance action from URL parameters as authoritative;
- building a separate API or microservice;
- making the whole operator console part of the first QR launch;
- adding offline attendance confirmation;
- adding a new platform super-admin console.

---

## 5. Decisions that need approval before implementation

These are the items that should be confirmed during plan review. Until then, the safest defaults are listed below.

### OPEN-1: Web authentication/session strategy

**Recommendation:** use Google Identity Services in the browser, exchange the ID token with the existing API, keep the short-lived access token in memory, and move browser refresh-token handling to a secure, `HttpOnly`, `Secure`, `SameSite` cookie endpoint. Do not put refresh tokens in `localStorage`.

**Required API work:** preserve mobile compatibility while adding a browser-safe refresh/logout path, exact CORS origins, and CSRF protection where cookie-authenticated operations are added.

### OPEN-2: Web QR payload format

**Recommendation:** new QR images encode an HTTPS web URL using a fragment, for example:

```text
https://web.example.com/invite#token=<opaque-token>
```

The browser extracts the fragment, immediately calls the existing invite-resolution API, and removes the token from the visible URL with `history.replaceState`. This reduces accidental token leakage through HTTP referrers and logs.

Compatibility requirements:

- old `dailio://invite?token=...` payloads remain supported by the mobile scanner;
- new mobile scanner code accepts both legacy app links and HTTPS web links;
- no existing permanent invite token is revoked or invalidated;
- raw tokens are never logged or sent to analytics.

### OPEN-3: Browser attendance physical-presence assurance

A browser link opened from a QR code cannot cryptographically prove that the member is physically at the printed QR. A link can be forwarded or copied. Browser geolocation and a live selfie improve assurance but do not prove the QR was scanned at the gym.

**Recommended Release 1 policy:** allow the browser path only when the effective attendance policy’s required live evidence succeeds, clearly label the source as QR gate attendance, and document that a forwarded link is not equivalent to a physical scan. Keep any stronger anti-forwarding requirement mobile-only until a dedicated challenge design is approved.

Alternative decision: keep web attendance disabled and support only web subscription purchase until anti-forwarding is designed.

### OPEN-4: Payment method in first web release

**Recommended default:** manual payment evidence first, because the existing product already models `REQUESTED` review and private evidence. Gateway checkout can be added later only with provider selection, webhook signature verification, idempotency, refunds, and reconciliation rules.

### OPEN-5: Web shell geometry

**Recommended default:** phone-width mobile shell at small screens and a centered, constrained Dailio content shell on desktop. Do not stretch member cards into a large desktop dashboard in Release 1. Operator desktop layouts can be designed separately in Release 3 while retaining the same component vocabulary.

### OPEN-6: Web domain and hosting

Confirm:

- production web origin;
- staging web origin;
- API origin;
- HTTPS certificate/hosting;
- allowed CORS origins;
- Google OAuth authorized origins/redirect configuration;
- upload/media origin policy;
- deployment branch and preview policy.

### OPEN-7: QR labels and physical signage

Confirm the text and signage design for:

- “Scan to Check In / Check Out”;
- “Scan to Buy a Plan”;
- whether one branch QR remains the admission + attendance QR as already approved in `CONTEXT.md`;
- help text for members without Google or without camera/location permission.

---

## 6. Target architecture

### 6.1 Principles

- React is a client, not a second backend.
- API responses and server permissions are authoritative.
- Every query and mutation carries the active organization/branch context when the API requires it.
- QR resolution may derive tenant context from the invite before a normal active branch context exists.
- React Router handles intent/deep links; TanStack Query handles server state and invalidation.
- Tailwind implements the existing Dailio tokens; no arbitrary per-page palette.
- Zod or equivalent validates response boundaries and form payloads.
- Shared UI components handle loading, empty, error, forbidden, offline/stale, validation, and mutation success states.
- All request keys and caches include organization, branch, user, and relevant QR purpose.

### 6.2 Proposed `apps/web` structure

The structure intentionally mirrors `apps/api/src` module names while keeping browser concerns separate:

```text
apps/web/
  package.json
  tsconfig.json
  vite.config.ts
  tailwind.config.ts
  postcss.config.js
  eslint.config.js
  .env.example
  README.md
  public/
    favicon.svg
    manifest.webmanifest
    robots.txt
  src/
    main.tsx
    app/
      App.tsx
      router.tsx
      providers.tsx
      route-config.ts
      error-boundary.tsx
    config/
      env.ts
      feature-flags.ts
    docs/
      page-contracts/
        auth.md
        qr-attendance.md
        qr-subscription.md
        member-fees.md
        member-attendance.md
    lib/
      api-client.ts
      api-errors.ts
      auth-session.ts
      browser-capabilities.ts
      idempotency.ts
      media.ts
      query-client.ts
      qr.ts
      telemetry.ts
      tenant-context.ts
      time.ts
    middleware/
      auth-guard.tsx
      context-guard.tsx
      permission-guard.tsx
      qr-intent-guard.tsx
    modules/
      admissions/
      announcements/
      attendance/
      attendance-streaks/
      auth/
      authorization/
      branches/
      feeds/
      holidays/
      invites/
      leave/
      members/
      notifications/
      organizations/
      payments/
      payroll/
      plans/
      roles/
      shifts/
      subscriptions/
      users/
    routes/
      public-routes.tsx
      authenticated-routes.tsx
      qr-routes.tsx
      operator-routes.tsx
    components/
      layout/
      navigation/
      forms/
      feedback/
      data-display/
      media/
      qr/
      attendance/
      payments/
      subscriptions/
    styles/
      tokens.css
      globals.css
    types/
      api.ts
      domain.ts
      router.ts
```

### 6.3 Module file convention

Each web module should follow a consistent shape, analogous to the API module convention:

```text
modules/invites/
  invites.api.ts          # endpoint calls only
  invites.hooks.ts        # TanStack Query hooks
  invites.pages.tsx       # route-level pages
  invites.components.tsx  # module-only components
  invites.schemas.ts      # client boundary/form schemas
  invites.types.ts        # client domain types
  invites.routes.tsx      # route definitions if module-owned
  invites.test.tsx
```

Shared components belong in `components/`; they must not be copied into each module. Business authorization remains in the API. The web client may use server-returned effective permissions to decide visibility, but every protected request must still be rejected by the API when unauthorized.

### 6.4 Initial module priority

Implement first:

```text
auth
authorization
branches
invites
attendance
members
plans
subscriptions
payments
users
```

Then add the remaining API-matching modules in Release 2 and Release 3. Even when a module has no Release 1 page, reserving the same boundary prevents a later monolithic `web-app.tsx` structure.

---

## 7. Route and flow design

### 7.1 Public and intent routes

```text
/                         Landing/redirect to auth or active context
/sign-in                  Google sign-in
/invite                   QR intent intake and server resolution
/invite/continue          Authenticated QR state router
/join/pending             Pending branch admission
/attendance/qr            QR attendance confirmation/evidence flow
/subscription/purchase   Plan purchase wizard
/auth/callback            Provider callback if redirect flow is used
/forbidden                Permission/membership denial
/error                    Safe generic error boundary
```

QR route handling must:

1. read only the supported token format;
2. validate token presence and size locally;
3. remove the raw token from the visible URL;
4. call `GET /api/v1/invites/:token`;
5. preserve only a short-lived in-memory/session intent reference;
6. send the user to login if needed;
7. restore the intended flow after authentication;
8. never accept organization, branch, plan, price, or attendance action from the URL as authoritative.

### 7.2 Authenticated member routes

```text
/home/announcements
/home/attendance
/home/attendance/record
/home/fees
/home/fees/buy-plan
/home/fees/:subscriptionId
/home/payments
/home/profile
/home/notifications
/home/settings
```

The first release can expose only the routes that are implemented, but the route naming should stay compatible with the mobile screen map and future deep links.

### 7.3 QR attendance flow

```text
Printed branch QR
  -> HTTPS /invite#token=...
  -> resolveInvite
  -> if unauthenticated: /sign-in, preserve intent
  -> if pending/non-member: join/pending state
  -> if active member: server-provided CLOCK_IN/CLOCK_OUT state
  -> display policy and branch-local context
  -> collect required live selfie/location/confirmation
  -> POST /attendance/qr-punch with Idempotency-Key
  -> show server-confirmed session result
```

Rules:

- The web client does not send a chosen clock-in/clock-out action.
- The server determines the next action from the member’s open-session state.
- A retry reuses the same idempotency key and returns the original result.
- A new confirmed scan refreshes the invite state and shows the next action.
- A required camera or location failure blocks submission and explains how to retry.
- Gallery upload cannot satisfy a live-selfie requirement.
- Browser offline state is never shown as confirmed attendance.

### 7.4 QR subscription purchase flow

```text
Printed plan QR
  -> HTTPS /invite#token=...
  -> resolveInvite
  -> sign in if necessary
  -> verify active membership and active plan server-side
  -> show plan terms returned by server
  -> select valid server-calculated start date
  -> POST /purchase-invites/:token/subscription-drafts
  -> show authoritative amount/coverage snapshot
  -> collect payment method/evidence
  -> POST payment request with idempotency key
  -> show Requested/pending-review state
  -> authorized staff reviews in existing API/mobile operator flow
```

Rules:

- Price, duration, joining fee, currency, and plan availability come from the server.
- The client cannot override amount, branch, member, or activation state.
- Manual evidence creates `REQUESTED`; it is not `PAID`.
- A payment review creates confirmed payment, ledger allocation, receipt, and activation only through the existing authorized API transition.
- Duplicate submit, refresh, timeout, or double-click must not create duplicate drafts or requests.

### 7.5 Floating action button

The member web shell may show a bottom-right floating action button labeled **Buy the plan** when:

- the active member has permission to purchase/request their own subscription;
- the branch has an eligible active plan;
- the current route is not already the purchase wizard;
- the member is not in a forbidden/suspended state.

The API remains authoritative. The button is a shortcut, not a permission mechanism. Its visibility and destination must be covered by UI tests and direct-route API tests.

---

## 8. Shared web UI system

### 8.1 Tokens to extract from mobile

Create a web token layer from the existing Flutter theme:

- brand accent: `#B45309`;
- dark brand: `#3D1F00`;
- page background: `#F0F2F5`;
- white surfaces and black/dark text;
- semantic status colors mapped to text/icons/badges, never color alone;
- 8px-ish spacing rhythm, compact controls, 8px input radius, 12px card radius;
- Space Grotesk font;
- focused/disabled/error/pressed states.

The exact final values should be verified against the rendered mobile screens during visual review, not guessed from names alone.

### 8.2 Required shared components

Build and use:

- `WebAppShell`
- `MobileWidthShell`
- `DailioAppBar`
- `BottomNavigation`
- `ContextSwitcher`
- `QrIntentBanner`
- `ProfileAvatar`
- `OrgLogo`
- `SectionHeader`
- `StatusChip`
- `RoleChip`
- `SubscriptionCard`
- `PlanCard`
- `MoneyAmount`
- `PrimaryButton`
- `SecondaryButton`
- `FormSection`
- `EvidenceBadge`
- `EvidenceUploader`
- `SelfieCapture`
- `LocationPermissionState`
- `LoadingSkeleton`
- `EmptyState`
- `ErrorState`
- `ForbiddenState`
- `PendingState`
- `SuccessState`
- `ConfirmDialog`
- `Toast/InlineNotice`

### 8.3 Accessibility requirements

- keyboard-accessible controls and navigation;
- visible focus state;
- proper labels for camera/location/payment fields;
- minimum touch target sizes even in compact mode;
- reduced-motion support;
- screen-reader text for status icons and QR intent states;
- no color-only status communication;
- browser back/forward and refresh safe at each flow checkpoint.

---

## 9. API and platform work required

The web client should reuse existing endpoints wherever possible. API work should be additive and backward compatible.

### 9.1 Web origin and deployment configuration

- add a validated `WEB_APP_BASE_URL` or equivalent API configuration;
- define staging and production origins;
- replace wildcard CORS in production with exact origins;
- configure HTTPS, security headers, CSP, HSTS, and clickjacking protection;
- update Google OAuth authorized origins/redirects;
- document environment variables in `.env.example` files;
- add web origin health/deployment checks.

### 9.2 QR payload compatibility

- generate HTTPS web payloads for new QR displays;
- retain server token hashing and permanent-lifetime rules;
- keep old `dailio://` tokens resolvable;
- update mobile parser for both formats;
- test QR payload generation without logging raw tokens;
- support a browser-safe fragment payload or document the approved alternative;
- ensure the web page clears the token from the visible URL after capture.

### 9.3 Browser auth support

- add or adapt browser-safe refresh/logout behavior;
- keep mobile bearer-token behavior working;
- add exact CORS and credential behavior;
- add CSRF protection if refresh/auth uses cookies;
- handle revoked/expired permissions by clearing scoped query state and reloading context;
- ensure Google auth retry cannot create duplicate users.

### 9.4 API response/contract hardening

- confirm all web-used routes are represented in OpenAPI;
- add stable response types for invite resolution, attendance QR preview, attendance result, subscription draft, payment request, and fees;
- standardize safe error codes for invalid invite, inactive branch, pending membership, suspended membership, evidence failure, duplicate command, forbidden, and stale context;
- ensure `404`/`403` behavior does not disclose another tenant’s records;
- preserve `Request-ID`/correlation IDs for support without returning secrets.

### 9.5 Media and browser capability support

- use private, signed upload paths already established by the API;
- do not send selfie/payment evidence blobs through general logs;
- validate content type, size, and retention server-side;
- request camera/location only at the point of need;
- make browser permission failure a normal recoverable state;
- preserve the server’s evidence and retention rules.

### 9.6 No new database model by default

The current `InviteToken`, `AttendanceSession`, `AttendanceEvidence`, `Subscription`, `PaymentRequest`, `PaymentAttempt`, `PaymentAllocation`, `Receipt`, and `LedgerEntry` models are sufficient for the first web release.

Add a migration only if an approved decision requires a browser-specific QR session/challenge, browser refresh-token session, or another durable domain concept. Never add a duplicate web-only attendance/payment record.

---

## 10. Delivery phases

Each phase has an exit gate. We should not move to the next phase merely because the happy path renders.

### Phase 0 — Product and technical decisions

**Goal:** freeze the minimum safe web contract before coding.

Tasks:

- [ ] Review and resolve OPEN-1 through OPEN-7.
- [ ] Confirm Release 1 scope: member/QR only versus additional self-service pages.
- [ ] Confirm web domain, staging domain, API origin, hosting, and OAuth configuration.
- [ ] Confirm whether web QR attendance is allowed under the physical-presence limitation.
- [ ] Confirm manual payment evidence as the first payment method.
- [ ] Confirm browser session storage strategy.
- [ ] Confirm the QR signage wording and support path.
- [ ] Update `CONTEXT.md` and append a Decision Log entry only after product approval.

Exit gate:

- approved product decision list;
- approved web/QR/auth threat model;
- no unresolved security-sensitive behavior hidden inside implementation assumptions.

### Phase 1 — Web workspace foundation

**Goal:** create the React/TypeScript/Tailwind application and a stable shell.

Tasks:

- [ ] Initialize `apps/web` using the repository’s package-manager/workspace conventions.
- [ ] Add the smallest approved dependency set: React, TypeScript, Vite, Tailwind, router, server-state client, and validation utilities as approved.
- [ ] Add web scripts for dev, build, lint, type-check, format, test, and E2E.
- [ ] Add `.env.example` with web origin, API origin, Google client ID, and safe feature flags.
- [ ] Create `src/app`, `config`, `lib`, `middleware`, `modules`, `routes`, `components`, `styles`, and `types`.
- [ ] Add Tailwind tokens and Space Grotesk loading.
- [ ] Implement `WebAppShell`, `MobileWidthShell`, app bar, bottom navigation, buttons, cards, status chips, and required state components.
- [ ] Add error boundary and safe error page.
- [ ] Add browser capability detection for camera, geolocation, secure context, and storage.
- [ ] Add CI checks for build, lint, type-check, unit tests, and dependency audit policy.

Verification:

- [ ] `pnpm --filter web ...` commands are documented and pass.
- [ ] A blank authenticated shell renders at phone and desktop widths.
- [ ] No API or database behavior changes yet.

### Phase 2 — Auth, session, and context

**Goal:** allow a browser user to authenticate and restore a safe organization/branch context.

Tasks:

- [ ] Implement Google Identity Services entry screen matching the mobile auth screen.
- [ ] Exchange the Google ID token through the existing API.
- [ ] Implement the approved access/refresh/session strategy.
- [ ] Implement logout, expiry, refresh failure, disabled-account, network, and auth-cancelled states.
- [ ] Implement `/auth/me` bootstrap and active-user state.
- [ ] Implement organization/branch context restoration and context selection.
- [ ] Add tenant headers exactly as required by the API (`X-Organization-Id`, `X-Branch-Id`; retain legacy compatibility only where needed).
- [ ] Scope query cache keys by user, organization, branch, and route intent.
- [ ] Clear sensitive scoped cache on logout, context switch, permission refresh, or membership change.
- [ ] Preserve the pending QR intent through login without storing a raw token longer than required.

Verification:

- [ ] Google retry does not create duplicate users.
- [ ] A user belonging to two organizations/branches cannot leak data across context switch.
- [ ] Expired permissions force safe refresh/forbidden behavior.
- [ ] Refresh and logout do not expose tokens in URL, logs, or error messages.

### Phase 3 — QR intake and invite resolution

**Goal:** make printed QR scans reliably enter the correct web flow.

Tasks:

- [ ] Implement QR fragment/query parser with legacy `dailio://` compatibility.
- [ ] Validate and bound token input before API use.
- [ ] Call `GET /invites/:token` without trusting client tenant fields.
- [ ] Remove token from browser address bar after capture.
- [ ] Display organization, branch, purpose, active/inactive plan, membership state, pending state, and server-provided attendance action.
- [ ] Implement invalid, inactive-branch, inactive-plan, already-member, already-pending, suspended, and network states.
- [ ] Add explicit confirmation before creating a join request or performing attendance.
- [ ] Add reusable QR intent state machine shared by attendance and plan purchase.

API/mobile tasks:

- [ ] Add HTTPS web payload generation for new QR output.
- [ ] Preserve existing permanent invite semantics and legacy payload behavior.
- [ ] Update mobile QR parsing and QR display copy to support the web path.
- [ ] Add API and mobile compatibility tests.

Verification:

- [ ] Old and new printed QR formats resolve correctly.
- [ ] A plan QR cannot enter attendance.
- [ ] A branch QR cannot create a plan purchase draft.
- [ ] Tokens do not appear in request logs, analytics, or user-facing error text.

### Phase 4 — Web QR attendance

**Goal:** complete browser clock-in/out using the same server rules as mobile.

Tasks:

- [ ] Build QR attendance preview page showing branch, local date/time, action determined by server, shift, and policy requirements.
- [ ] Implement live selfie capture using browser camera APIs where required.
- [ ] Disable gallery fallback when policy requires a live selfie.
- [ ] Implement geolocation capture and freshness/accuracy display.
- [ ] Add consent and privacy explanation before first sensitive capture.
- [ ] Add confirmation step with clear “will clock in” or “will clock out” copy from server state.
- [ ] Generate a stable idempotency key per user action attempt and reuse it on retry.
- [ ] Submit `/attendance/qr-punch` with the required evidence metadata.
- [ ] Show pending submission, confirmed result, conflict, evidence failure, permission denial, timeout, and retry states.
- [ ] Link to attendance detail only after confirmed server response.
- [ ] Refresh invite state after success so the next action is accurate.
- [ ] Ensure branch-local time and overnight-shift presentation match API results.

Security/testing tasks:

- [ ] Never allow a client-sent `CLOCK_IN`/`CLOCK_OUT` choice to override server state.
- [ ] Do not claim that an HTTPS browser link cryptographically proves physical QR presence.
- [ ] Add duplicate submission and timeout-after-success tests.
- [ ] Add camera denied, location denied, stale location, inaccurate location, and insecure-context tests.
- [ ] Add cross-tenant token/member tests.
- [ ] Add browser tests in Chrome mobile emulation and Safari-compatible conditions where available.

Exit gate:

- real server-confirmed attendance works on an HTTPS staging origin;
- no offline confirmation;
- evidence and privacy review passes;
- product decision OPEN-3 is explicitly accepted.

### Phase 5 — Web QR subscription purchase and payment request

**Goal:** let members purchase/request a plan without the mobile app.

Tasks:

- [ ] Build Buy Plan page matching the mobile wizard.
- [ ] Display only server-resolved plan terms and coverage rules.
- [ ] Validate start-date bounds and display branch-local dates.
- [ ] Create an idempotent `DRAFT` subscription through the plan invite endpoint.
- [ ] Show authoritative amount, joining fee, discount, currency, and coverage dates from the draft.
- [ ] Implement supported manual payment method and reference fields.
- [ ] Implement private evidence upload with signed upload flow and progress/error states.
- [ ] Submit payment request with idempotency key.
- [ ] Show `REQUESTED`/needs-information/rejected/approved states accurately.
- [ ] Never present a requested, pending, or failed payment as paid.
- [ ] Add receipt/payment detail navigation only when data is authorized and available.
- [ ] Add the floating **Buy the plan** shortcut to the member shell under server-permission/plan-availability rules.

Verification:

- [ ] Duplicate draft/request submission is safe.
- [ ] Two reviewers cannot double-post payment or ledger entries.
- [ ] Plan edits do not rewrite the snapshot shown in an existing draft/subscription.
- [ ] Evidence is private and short-lived; it is not included in logs or public URLs.
- [ ] Cross-tenant plan IDs and subscription IDs fail safely.

### Phase 6 — Member Fees, attendance, and subscription parity

**Goal:** make QR actions feel like part of the full mobile member experience rather than isolated pages.

Tasks:

- [ ] Implement Fees page with period tabs and Paid / Requested / Pending states.
- [ ] Display payment date separately from coverage dates.
- [ ] Implement subscription/payment detail page.
- [ ] Implement self attendance today state and confirmed timeline.
- [ ] Implement self attendance record tabs: This Week, This Month, Custom.
- [ ] Implement self-only evidence/detail visibility.
- [ ] Add stale/offline labels for cached reads, never for confirmed mutations.
- [ ] Add subscription/attendance notifications or deep-link handling when supported by the API.
- [ ] Add member profile/settings and context switcher as agreed for Release 2.

Verification:

- [ ] Self routes cannot read another member by changing a URL ID.
- [ ] Fees use stable pagination/sorting and current branch context.
- [ ] Active member status, plan status, and permission changes invalidate stale actions.
- [ ] Loading, empty, error, forbidden, stale, validation, and success states exist for every page.

### Phase 7 — Full member web parity

**Goal:** reproduce the remaining self-service mobile modules.

Tasks:

- [ ] Announcements and announcement detail.
- [ ] Participant-scoped feeds, reactions, comments, reports, and notification deep links.
- [ ] Notifications and unread badges.
- [ ] Leave list and leave request form.
- [ ] Safe member profile and streak summary.
- [ ] Self payroll/payslip views where permission permits.
- [ ] Profile editing with server-side field restrictions.
- [ ] Browser media handling for private announcement media and payslips.
- [ ] Full responsive and accessibility pass.

Verification:

- [ ] Each page has a written page contract.
- [ ] Announcement/feed audience and media are tenant/branch scoped.
- [ ] Salary and payslip data are self/permission scoped.
- [ ] Comments/reactions/read receipts are retry-safe.

### Phase 8 — Operator web parity

**Goal:** add owner/admin/staff workflows only after member web flows are reliable.

Tasks:

- [ ] Organization/branch settings.
- [ ] Roles, permissions, and hierarchy.
- [ ] Members, join requests, configure member.
- [ ] Attendance all-records, ongoing activity, evidence, correction, void, and export.
- [ ] Plans, subscriptions, fees, payment review, ledger, receipt, refund/void.
- [ ] Shifts, leaves, holidays, attendance policies.
- [ ] Salary eligibility, salary structures, payroll, payslips.
- [ ] Announcements, feeds, reports, audit log.
- [ ] Operator desktop layouts while preserving mobile-responsive behavior.

Verification:

- [ ] Direct-route/API access is denied without the required atomic permission.
- [ ] Team scope uses server-resolved reporting subtree, never client member lists.
- [ ] Final-owner and protected-role invariants remain enforced.
- [ ] Financial, payroll, attendance, and sensitive-media actions are audited.

### Phase 9 — Production hardening and rollout

**Goal:** release safely at gym scale.

Tasks:

- [ ] Threat-model review for QR forwarding, session theft, CSRF, token leakage, media access, and tenant escape.
- [ ] Browser compatibility matrix: current Chrome Android, Safari iOS, Chrome desktop, Edge/Firefox as supported.
- [ ] Real-device camera and geolocation testing on HTTPS.
- [ ] Load/rate-limit testing for invite resolution, attendance punch, uploads, and payment requests.
- [ ] Accessibility audit and keyboard/screen-reader verification.
- [ ] Observability dashboards for auth, QR resolution, attendance failures, evidence failures, payment requests, API latency, and client errors.
- [ ] Redaction review for API/web logs, analytics, error reporting, and support tooling.
- [ ] Backup/restore and migration runbooks if schema changes were approved.
- [ ] Staged rollout to one branch, then a small member group, then all branches.
- [ ] Print/signage validation: QR contrast, physical size, scan distance, lighting, and replacement process.
- [ ] Support runbook for camera/location denial, unsupported browsers, expired sessions, pending approvals, and payment review.

Exit gate:

- signed release checklist;
- owner/admin pilot completed;
- member pilot completed;
- no unresolved high-risk security or financial findings;
- rollback and support paths documented.

---

## 11. Testing strategy

### 11.1 Web unit tests

- QR payload parsing and token removal.
- Route-intent preservation through login.
- Permission-aware navigation/action visibility.
- Money/date/currency formatting.
- Branch-local date/time display.
- Form schemas and validation.
- Idempotency-key lifecycle.
- Browser capability/error state mapping.
- Attendance and payment state rendering.

### 11.2 API and integration tests

Extend existing API coverage for:

- HTTPS QR payload generation.
- legacy/new QR compatibility.
- permanent invite behavior.
- invite-purpose separation.
- QR attendance server-derived next action.
- duplicate/timeout retry behavior.
- cross-tenant token/member/plan isolation.
- payment-request idempotency and concurrent review.
- browser auth/session behavior.
- CORS/CSRF/security headers where changed.

### 11.3 Web component tests

Cover:

- auth loading/error/cancelled/disabled states;
- QR invalid/pending/suspended/already-member states;
- camera and location permission states;
- attendance pending versus confirmed result;
- payment requested versus paid distinction;
- plan FAB visibility;
- forbidden direct routes;
- context switch cache clearing;
- responsive navigation and back-button behavior.

### 11.4 End-to-end tests

Use a real or controlled staging API and fictional seed data:

1. Unauthenticated branch QR opens login and returns to join.
2. Authenticated non-member submits one idempotent join request.
3. Pending member sees pending state and cannot punch.
4. Active member sees server-derived clock-in, submits evidence, and receives confirmed session.
5. Retry after a network timeout does not duplicate attendance.
6. Active member scans plan QR, creates a draft, submits evidence, and sees Requested.
7. Requested payment is not shown in Paid.
8. Cross-tenant identifiers return safe errors.
9. Permission revocation removes actions and API rejects direct access.
10. User with multiple branch memberships can switch without stale data leakage.

### 11.5 Manual device matrix

- iOS Safari: camera, geolocation, browser back, refresh, private browsing behavior as supported.
- Android Chrome: camera, geolocation, QR-to-browser handoff, upload.
- Desktop Chrome/Edge: keyboard and constrained shell.
- Slow network and offline transitions.
- Camera/location denied, approximate location, stale location, and low-light selfie.

---

## 12. Security, privacy, and financial safeguards

These are release-blocking requirements, not optional polish:

- HTTPS in every environment where camera/location or authentication is tested.
- Exact CORS origins in production.
- No raw QR token in logs, analytics, URLs after intake, screenshots, or error messages.
- No refresh token in `localStorage`.
- Secure session expiry and revocation handling.
- No open redirects through `returnTo` or QR intents.
- Server-derived organization, branch, member, plan, price, attendance action, and lifecycle state.
- Organization and branch scope in every query, cache key, upload path, and mutation.
- Live selfie and precise location kept private and permissioned.
- Payment evidence kept private and short-lived.
- Requested/failed/pending payments never treated as paid.
- Ledger and attendance evidence remain append-only/reversible according to domain rules.
- Idempotency for join request, QR punch, subscription draft, payment request, payment confirmation, refund, and notification operations.
- Rate limits for QR resolution, auth, punch, uploads, and payment requests.
- Browser analytics limited to safe event names and coarse outcome metadata.
- User-facing errors contain safe messages and correlation IDs only.

---

## 13. Documentation and operational deliverables

The implementation should add or update:

- `apps/web/README.md` with setup, scripts, environment variables, and deployment notes;
- web page contracts under `apps/web/src/docs/page-contracts/`;
- QR signage and member help instructions;
- API/OpenAPI documentation for any changed endpoint;
- auth/session threat model;
- browser camera/location privacy notice;
- release verification checklist;
- support troubleshooting guide;
- staging and production deployment runbook;
- `CONTEXT.md` Decision Log after each approved product decision.

Do not add secrets, real member evidence, real payment evidence, or production QR tokens to documentation or fixtures.

---

## 14. Definition of done for the web project

The web project is complete for a release only when the applicable items are true:

- the requested QR/member flows work end to end against the existing API;
- the UI matches the mobile design system and has been checked at real phone widths;
- organization/branch isolation is enforced server-side and represented safely client-side;
- permissions, membership status, and record state control actions;
- authentication/session behavior is secure for browsers;
- QR token handling does not leak secrets;
- attendance evidence and browser limitations are handled explicitly;
- payment requests remain distinct from confirmed payment;
- all retry-prone commands are idempotent;
- loading, empty, error, forbidden, stale/offline, validation, and success states exist;
- unit, API, isolation, component, and E2E tests cover failure/retry paths;
- browser/device/accessibility checks pass;
- deployment, monitoring, support, and rollback documentation exists;
- approved product decisions are recorded in `CONTEXT.md`.

---

## 15. Recommended implementation order after approval

If the plan is approved without changing the major boundaries, the first implementation command should start with:

1. Phase 0 decisions and `CONTEXT.md` Decision Log update where approved.
2. Phase 1 empty React web shell and repository scripts.
3. Phase 2 browser auth/session/context.
4. Phase 3 QR intake and compatibility.
5. Phase 4 web QR attendance.
6. Phase 5 web QR subscription/payment request.
7. Phase 6 member shell parity.

The operator console and full web parity should follow only after the QR/member release has passed real-device and tenant-isolation verification.

---

## 16. Review checklist for the product owner

Please review and mark changes against these points before implementation begins:

- [ ] Release 1 includes both web QR attendance and web QR subscription purchase.
- [ ] Branch QR remains the reusable admission + attendance QR.
- [ ] Plan QR remains a separate reusable purchase QR.
- [ ] New QR payloads may open an HTTPS web URL while old QR payloads remain valid.
- [ ] Google is the only login method in the first web release.
- [ ] Browser attendance may require live selfie/location according to policy.
- [ ] Manual payment evidence is acceptable for the first web release.
- [ ] The web shell should remain mobile-shaped on desktop.
- [ ] The first release is member-focused; operator parity is later.
- [ ] The proposed `apps/web/src/modules` mirror of API module names is acceptable.
- [ ] The proposed browser auth/session model is acceptable.
- [ ] The physical-presence limitation of forwarded web QR links is acceptable, or web attendance should wait for a stronger challenge.

Once these decisions are approved, implementation can begin phase by phase with the repository completion standard in `AGENTS.md` and the authoritative requirements in `CONTEXT.md`.
