# Codebase Investigation: End-to-End Status

Based on `CONTEXT.md` and a deep scan of `apps/api` and `apps/mobile`. Last audited: 2026-09-26.

---

## 1. 🔐 AUTH (Authentication)

**Status: 🟢 100% Complete**

Core auth is solid, production-ready, and fully verified end-to-end.

### ✅ Built End-to-End

- Google OAuth: Mobile token extraction → Backend Google ID token verification → JWT issuance
- Short-lived JWT Access Tokens + Long-lived Refresh Tokens
- Automatic token rotation via `AuthInterceptor` (Dio `QueuedInterceptor`) — handles race conditions correctly
- `/auth/me`, `/auth/logout`, `/auth/refresh`, `/auth/google` endpoints all wired
- Server-side logout token revocation (Redis JTI blocklist) to prevent replay attacks
- Full profile synchronization (`emergency_contact_name`, `date_of_birth`, etc.)
- FCM token registration on sign-in (silent, best-effort)
- Account deletion (`DELETE /users/me`) — gracefully clears local storage and anonymizes data
- Sign-out clears `SecureStorage` + calls backend logout
- `AuthCubit` + `AuthState` properly wires all states and captures backend errors natively

---

## 2. 🟢 ONBOARDING

**Status: 🟢 100% Complete**

Core flows are fully wired and end-to-end verified. No integration bugs remain.

### ✅ Built End-to-End

- `OnboardingPage` (login screen) with Google Sign-In button + hero visualizer
- Post-login routing: zero-org → `JoinOrCreatePage`, has-org-no-context → `ContextSwitcherPage`, ready → `AppRoutes.home`
- `ContextSwitcherPage` loads memberships and sets active org/branch in `PreferencesStorage`
- `OrganizationDiscoveryPage` — search, filter, browse orgs; fully dynamic.
- `QrScannerPage` — parses `dailio://join?orgId=...&branchId=...`, dynamically fetches `BranchDiscoveryModel` from API and pushes to `orgDetail` seamlessly.
- `OrgDetailPage` — shows branch list, triggers `JoinRequestSheet`
- `JoinRequestSheet` — collects message, emergency contact, DOB; updates profile then calls `joinBranch`
- `PendingJoinPage` — intelligent 15-second polling system to dynamically jump to the dashboard immediately upon admin approval.
- `JoinRequestsPage` — admin view of pending join requests
- Approve/Reject flow wired to `AdmissionRepository` → backend `approveJoinRequest` atomically creates Member, assigns MEMBER role, triggers FCM push notification, and logs audit record.
- `CreateOrganizationPage` + `CreateBranchPage` — owner creation wizard with map location picker
- Backend `POST /organizations` — seeds Owner/Admin/Member roles, creates first Branch, creates Owner `Member` record atomically in a transaction
- QR Code in `EditBranchPage` — shows `QrImageView` with join deep link + Setup Checklist wizard

---

## 3. ⚙️ SETTINGS

**Status: 🟢 80% Complete; final release hardening tracked**

High-level UI and operational screens exist but system preference APIs are missing.

### ✅ Built

- Roles & Permissions CRUD screens wired to backend
- Shift Management screen wired to API
- Edit Organization / Edit Branch pages with map
- QR Code invite in Edit Branch + Setup Checklist

### ❌ Remaining

- Hardware toggles (Push Alerts, Biometric) — static stubs, not wired to SharedPreferences or backend
- Branch Timezone & Currency — not configurable in UI despite being on the schema

---

## 4. 📅 ATTENDANCE

**Status: Core flow and domain hardening implemented; production completion tracked in [ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md](ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md)**

The core self/admin surfaces, scoped policy assignment, private selfie evidence, and permanent gate QR flow are implemented. The remaining production hardening is tracked in [ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md](ATTENDANCE_POLICY_AND_GATE_QR_PLAN.md).

### 🏗️ Built

- Clock-In / Clock-Out state machine with idempotency-key support, serializable transitions, and database open-session guard
- Period filtering (Today / Yesterday / This Week / This Month / This Year / Custom)
- Attendance cards with real data, cycle performance stats, role-based filtering
- Pull-to-refresh on all tab views
- Evidence Collection (GPS persistence + private selfie upload/asset association)
- Scoped attendance detail endpoint/page with server-built timeline and sanitized evidence metadata
- Attendance corrections API (`PATCH /attendance/:id/correct`) with immutable correction history and transaction audit trails
- Manager Correction UI inside the attendance timeline (bottom sheet for adjusting time/status)
- Authorized branch-scoped attendance CSV export with role filtering
- Configurable evidence retention (90-day default) that purges precise location/device data and deletes private selfie assets in batches
- Stable cursor pagination, one-minute live activity refresh, server-authoritative branch timezone snapshots, and policy-impact previews
- Deduplicated attendance exception alerts with an authenticated in-app notification inbox and push delivery when configured
- Policy-controlled manager manual attendance records with mandatory reasons, audited `ADMIN`/`MANUAL` state, idempotency, and one-open-session protection
- Offline attendance capture remains disabled at the API boundary until tamper-evident synchronization is implemented
- Attendance displays, manager manual-entry pickers, and corrections use the active branch's validated IANA timezone and convert submitted wall times to UTC

### 🔴 Remaining

- Physical-device UI/permission verification, device attestation assessment, production retention scheduling/monitoring review, and independent privacy/security review
- Final product-owner sign-off; server E2E, cross-tenant isolation, and database punch concurrency have passed through guarded staging harnesses
- Final staging/device/cross-tenant/privacy sign-off is documented in [ATTENDANCE_RELEASE_VERIFICATION.md](ATTENDANCE_RELEASE_VERIFICATION.md) and [ATTENDANCE_SECURITY_REVIEW.md](ATTENDANCE_SECURITY_REVIEW.md), and is intentionally not marked complete without execution evidence.
- Latest automated verification: 92 API tests across 27 files, API startup/health smoke with maintenance status, all 16 Flutter tests and analyzer, an Android emulator startup smoke pass, a guarded attendance acceptance matrix, and a real configured-private-storage retention check; the guarded PostgreSQL flow, concurrency, cross-tenant isolation, and concurrent-correction checks also passed again against `dailio_test`.
