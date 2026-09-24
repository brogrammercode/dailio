# Codebase Investigation: End-to-End Status

Based on `CONTEXT.md` and a deep scan of `apps/api` and `apps/mobile`. Last audited: 2026-09-19.

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

**Status: 🟠 50% Complete**

High-level UI and operational screens exist but system preference APIs are missing.

### ✅ Built

- Roles & Permissions CRUD screens wired to backend
- Shift Management screen wired to API
- Edit Organization / Edit Branch pages with map
- QR Code invite in Edit Branch + Setup Checklist

### ❌ Remaining

- Attendance Policy Config (Selfie required, Geofence radius, Late grace period) — no API controller or UI
- Hardware toggles (Push Alerts, Biometric) — static stubs, not wired to SharedPreferences or backend
- Branch Timezone & Currency — not configurable in UI despite being on the schema

---

## 4. 📅 ATTENDANCE

**Status: ✅ 100% Complete**

Core mechanics, evidence collection, and manager corrections are fully implemented.

### 🏗️ Built

- Idempotent Clock-In / Clock-Out state machine (race-condition proof)
- Period filtering (Today / Yesterday / This Week / This Month)
- Attendance cards with real data, cycle performance stats, role-based filtering
- Pull-to-refresh on all tab views
- Evidence Collection (selfie camera + GPS capture based on branch policy)
- Attendance corrections API (`PATCH /attendance/:id/correct`) with transaction audit trails
- Manager Correction UI inside the attendance timeline (bottom sheet for adjusting time/status)

### 🔴 Remaining

- None (Moved to complete)
