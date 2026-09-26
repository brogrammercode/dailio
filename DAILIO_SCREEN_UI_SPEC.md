# Dailio Screen-by-Screen UI Specification

**Purpose:** This document is the handoff specification for rebuilding the Dailio mobile app screen by screen. A coding agent should be able to implement the complete mobile experience from this document without needing the original design conversation.

**Product:** Dailio — multi-tenant organization and branch management platform.

**Source of truth:** `CONTEXT.md` remains authoritative for domain behavior, permissions, security, tenancy, attendance, subscriptions, payments, and lifecycle rules. This document defines the mobile screen order, visual hierarchy, navigation, and interaction language.

**Current direction:** Keep the existing Dailio name, supplied logo, Space Grotesk font, and bottom navigation. Redesign the screen content into a simple, professional, WhatsApp-like information experience.

---

## 1. Non-negotiable visual rules

### Brand

- Product name is always **Dailio**.
- Use only the supplied canonical logo from `apps/mobile/assets/logo.png`.
- Never redraw, recolor, crop into a new logo, or replace the logo with another mark.
- Keep Space Grotesk throughout the app.
- Do not change the existing bottom navigation structure, labels, order, or interaction behavior.

### Palette

The redesigned screen content uses only the Dailio logo orange, white, and black as its primary palette.

| Use                   | Treatment                                                         |
| --------------------- | ----------------------------------------------------------------- |
| Primary accent        | Existing Dailio logo accent from `AppColors.brandAccent`          |
| Page background       | White                                                             |
| Card/sheet background | White                                                             |
| Main text             | Black                                                             |
| Secondary text        | Black with reduced opacity or a neutral grayscale tint            |
| Dividers              | Very light black/gray line                                        |
| Primary buttons       | Logo orange with readable black/white label according to contrast |
| Selected tabs/chips   | Logo orange underline or pale orange tint                         |
| Errors/warnings       | Black/orange treatment with an icon and text; never color alone   |

Do not introduce WhatsApp teal, unrelated blue, purple, green, or decorative gradients into redesigned Dailio screens. Semantic state must always include a text label or icon in addition to any color.

### Density and shape

- Clean, calm, compact, and professional.
- Prefer one strong information card over many decorative cards.
- Standard horizontal page padding: 16 px.
- Standard section spacing: 12–20 px.
- Card radius: 12–16 px.
- Thin borders and subtle shadows only.
- Avoid giant headings, oversized empty cards, glassmorphism, gradients, and dashboard decoration.
- Touch targets remain comfortable even when the visual scale is compact.
- Use line icons, primarily the existing Iconsax icon family.

### App bars

- White app bar.
- Black title and navigation icons.
- Logo orange for active tabs, primary actions, and small status markers.
- Title is short and left-aligned.
- Branch/organization context appears as a smaller subtitle when operational data is shown.
- Refresh, export, or add actions appear only when the acting user has the required permission.

### Common states

Every data screen must implement:

1. Loading state — compact progress indicator or restrained shimmer.
2. Empty state — short explanation plus the next useful action.
3. Error state — safe human-readable message, retry action, no raw exception.
4. Forbidden state — explain that the user lacks access, without exposing data.
5. Offline/stale state where applicable — clearly distinguish cached/stale data from server-confirmed data.
6. Success/pending state — show the resulting server status after commands.

Server confirmation is authoritative for attendance, admission, subscriptions, and payments. Never present a local optimistic result as confirmed.

---

## 2. Main navigation contract

The main authenticated shell is one screen containing an `IndexedStack` and a fixed four-item bottom navigation bar.

### Bottom navigation order

1. **Attendance** — clock icon.
2. **Fees** — receipt icon.
3. **Payments** — wallet icon.
4. **Settings** — settings icon.

There is no separate Home/Dashboard tab. `/home` is the shell route that contains these four tabs.

### Floating action behavior

- On Attendance, Payments, and Settings, the floating action opens **Self Attendance**.
- On Fees, the floating action opens **Buy a Plan** only when the user has no active, unexpired plan.
- If the member already has valid current coverage, the Fees floating action is hidden.
- Keep the floating action as a single icon button with a short tooltip; do not add a second bottom-navigation item.

### Context behavior

- The active organization and branch are restored after login when possible.
- If no valid context is restored, show the Context Switcher before the main shell.
- Operational screens must identify the active branch.
- Switching context must rebuild/reload all branch-owned screens and must not display data from the previous branch.

---

## 3. Startup, authentication, and context screens

### 3.1 Onboarding / sign-in

**Order:** app launch → Onboarding → Google sign-in.

**Visual structure:**

- Full white screen.
- Canonical Dailio logo near the upper/middle area.
- Short product statement below the logo.
- One dominant action: **Continue with Google**.
- No password form or alternate authentication method in the current release.
- Loading state replaces the button label while authentication is in progress.
- Error appears as a compact orange/black message near the action.

**Behavior:**

- Google account selection must allow the account chooser when multiple accounts exist.
- Successful authentication routes to Context Switcher, Join or Create, or the main shell depending on restored organization/branch context.

### 3.2 Join or Create

**Order:** authenticated user without an organization → Join or Create.

**Visual structure:**

- Dailio logo and welcome message.
- Two simple action choices:
  - Join an existing organization/branch.
  - Create an organization.
- Join is the primary customer/member path.
- Create is the owner path.

### 3.3 Organization Discovery

**Visual structure:**

- Header: “Explore organizations”.
- Search field with compact rounded border.
- Scan QR action prominently available.
- Organization results as simple rows/cards containing logo/avatar, name, branch count, distance or metadata, and a clear action.
- Empty, loading, and search-error states.

### 3.4 Organization Detail and Branch selection

**Visual structure:**

- Organization identity at top.
- Canonical organization logo when available.
- Organization metadata and branch list.
- Each branch is a simple selectable row with name, address/context, and join action.
- Do not show owner-only settings to a prospective member.

### 3.5 QR Scanner

**Purpose:** shared scanner for branch joining, plan purchase, and gate attendance.

**Visual structure:**

- Black camera area with a clean orange scan frame.
- Short instruction: “Scan a Dailio QR code”.
- Gallery button for selecting a QR image.
- Processing overlay while the token is resolved.
- Invalid/revoked QR message in a compact bottom message.

**Routing rules:**

- Join QR → confirmation dialog → membership request → Pending Join.
- Plan QR → prefilled Subscription Purchase.
- Gate QR for active member → Gate Attendance.
- Gallery-selected QR may resolve flows, but attendance punching must require a live camera scan according to the current safety rule.

### 3.6 Pending Join

**Visual structure:**

- Organization and branch identity.
- Clear “Request pending” status.
- Explanation that an authorized branch user must approve the request.
- Refresh/check status action.
- Back to Join or Create action.

### 3.7 Context Switcher

**Visual structure:**

- List of the user’s organizations and branches.
- Active context has an orange marker and clear selected state.
- Each row shows organization, branch, role, and membership status where available.
- A compact action to return to the main shell.

### 3.8 Create Organization and Create Branch

**Owner onboarding flow:** Create Organization → Create Branch → main shell.

**Visual structure:**

- Step indicator for multi-step setup.
- Group fields into logical sections instead of one card per field.
- Logo upload/preview uses the canonical app styling but allows organization branding only where the product model permits it.
- Location/address fields show permission and error states clearly.
- Final action is explicit and server-confirmed.

---

## 4. Attendance module

Attendance is the first fully redesigned module. It must feel like a calm activity/inbox screen: current status first, recent records below, detailed evidence only after opening a record.

### 4.1 Attendance tab — overview/list

**Screen order:** Main shell → Attendance.

**App bar:**

- Title: **Attendance**.
- White background, black title.
- Optional add/manual record action only for users with `ATTENDANCE_CREATE_ALL`.
- Export action only when the effective permission allows it.
- Tabs under the app bar:
  - Today
  - Yesterday
  - This Week
  - This Month

**Content order:**

1. Compact cycle-performance summary.
2. Active period indicator.
3. Role filter only when role filtering is permitted and useful.
4. Attendance record list.

**Cycle-performance summary:**

- Present count.
- Late count.
- Absent count.
- Use black text and orange emphasis; include labels and icons.

**Attendance card:**

- Member avatar or initials.
- Member name.
- Date and local branch time.
- Status label: Present, Late, Open, Completed, or other server-derived state.
- Clock-in time.
- Clock-out time or Open.
- Logged duration.
- Small evidence pills such as Selfie evidence or Location evidence.
- Timeline-event count.
- “View details” affordance.

The list card must remain compact. Do not render the complete server timeline inside every list card.

**Member visibility:**

- A normal member sees only their permitted self attendance records.
- Owner/admin/team views are controlled by server permissions and scope.
- UI hiding is not authorization; the API must enforce the same scope.

**Empty state:** “No attendance records found” plus the selected period and pull-to-refresh.

### 4.2 Self Attendance

**Entry:** Attendance/Payments/Settings floating action → Self Attendance.

**App bar:**

- Title: **Self attendance**.
- Branch name as subtitle.
- Refresh icon.
- Two tabs:
  - Today
  - Attendance record

#### Today tab content order

1. Live branch-local clock card.
2. Effective attendance policy card.
3. Current open session card, if present.
4. Server submission status card, when applicable.
5. Main Clock in/Clock out button.
6. Scan branch gate QR button.

**Clock card:**

- Branch-local date.
- Large but restrained time.
- “Server-synchronized clock” when server time is available.
- Clear note that the server confirms every punch.

**Policy card:**

- Location required, if applicable.
- Live selfie required, if applicable.
- Geofence enabled, if applicable.
- Late grace.
- Shift window when assigned.
- Policy version and source scope.
- If punching is disabled, show a clear text explanation and disable the action.

**Session card:**

- Open/closed label.
- Clock-in time.
- Current duration.
- Evidence recorded indicator.
- “Tap for full details”.

**Action behavior:**

- Clock-in and clock-out collect exactly the evidence required by the effective policy.
- Location permission, geofence, selfie, shift, and network failures are explained before/after submission.
- Button shows submitting state.
- Only a successful server response shows confirmed state.
- Reuse idempotency behavior for retries.

#### Attendance record tab

- Period chips: Today, Yesterday, This week, This month, This year, Custom.
- History rows show date, clock-in/out, duration, and open/closed marker.
- Tapping a row opens Attendance Detail.

### 4.3 Gate Attendance

**Entry:** Self Attendance → Scan branch gate QR → live QR resolution → Gate Attendance.

**Visual structure:**

- White app bar titled **Gate attendance**.
- Branch name at the top of the main card.
- Large next-action label: Clock in or Clock out.
- Effective requirements listed in plain language.
- Policy version/source and shift window.
- If a gallery image was used, show the safety explanation and prevent punch submission.
- One primary action: Confirm clock in or Confirm clock out.

**Confirmation dialog:**

- Explain that Dailio will apply the assigned policy, gather required evidence, and submit a server-confirmed action.
- Cancel and Continue actions.

**Success:** replace the gate screen with Attendance Detail for the returned server session.

**Failure:** remain on the gate screen, preserve retry context, and show a safe actionable message.

### 4.4 Attendance Detail / Timeline / Evidence

**Entry:** any attendance card or session card → Attendance Detail.

**App bar:**

- Title: **Attendance details**.
- White background, black title, normal back action.

**Content sections:**

1. Summary.
2. Timeline.
3. Evidence.

**Summary:**

- Local date.
- Open/closed state.
- Member name when permitted.
- Clock-in, clock-out, duration.
- Derived attendance status.
- Source and clock-out source.
- Branch timezone.
- Late/early variance.
- Shift snapshot.
- Correction reason when present.

**Timeline:**

- Vertical/simple chronological list.
- Each event has an icon, human-readable label, reason when available, and branch-local time.
- Typical events include clock-in, clock-out, selfie capture, location capture, and correction.

**Evidence:**

- Evidence type.
- Capture time.
- Location accuracy/geofence distance when permitted.
- Selfie evidence is private and opens only through an authorized protected download.
- Never log or expose raw private evidence URLs.

### 4.5 Manual record and correction sheets

These are secondary sheets, not bottom-navigation screens.

**Manual attendance sheet:**

- Member selector.
- Clock-in now or explicit clock-in time.
- Optional clock-out.
- Branch timezone note.
- Mandatory reason.
- Server permission and validation errors.

**Correction sheet:**

- Existing clock-in and clock-out values.
- New values.
- Mandatory reason.
- Preserve original evidence and audit history.
- Explicit save confirmation.

### 4.6 Attendance Policy management

**Entry:** Settings → Attendance Policy, owner/admin/policy-authorized user only.

**Visual structure:**

- White app bar titled **Attendance Policy**.
- Save action in the app bar.
- Group controls into logical cards/sections:
  - Punch requirements.
  - Selfie requirements.
  - Location/geofence requirements.
  - Shift enforcement.
  - Grace/session limits.
  - Policy scope and assignment.
  - Existing policy versions/history.
- Scope selector: Branch, Role, or Member.
- Role/member selector appears only for the selected scope.
- Affected-member preview appears as a small orange information panel.
- Save creates the next effective version; do not rewrite existing session snapshots.

**Precedence shown in copy/help:** direct member override → effective role policy → branch default.

---

## 5. Fees and subscriptions module

### 5.1 Fees tab — member view

**App bar:** Fees & Subscriptions plus branch subtitle.

**Content:**

- “Your plan” header.
- One own subscription card.
- Plan name.
- Coverage dates.
- Expiry urgency.
- Paid amount, due amount, and payment status.
- Detail navigation.
- Buy a plan only when there is no active, unexpired subscription.

Members must never see organization-level fee cards unless they have explicit all-scope permission.

### 5.2 Fees tab — owner/admin view

**Content order:**

1. Summary metrics: Paid, Requested, Pending.
2. Period tabs: This Month, Last Month, Custom.
3. Status filters: All, Paid, Requested, Pending, Partial, Expiring.
4. Member fee cards.

Each card shows member avatar, name, plan, expiry, urgency, paid/due amount, payment date, receipt number, and review action where authorized.

### 5.3 Buy a Plan

**Entry:** Fees floating action or Fees page action.

**Visual structure:**

- Title: Buy a plan.
- Branch subtitle.
- Short explanation that the request is sent for branch review.
- Active plans as simple selectable cards.
- Plan name, duration, plan amount, admission fee, currency, and description.
- Tap a plan to continue.

### 5.4 Subscription Purchase

**Entry:** Buy a Plan selection or Plan QR.

**Visual structure:**

- Prefilled branch and plan summary.
- Amounts come from server plan data; never trust client price.
- Payment method selector.
- Reference field.
- Notes/evidence fields.
- Evidence upload/progress.
- Submit for review button.
- Requested/pending status after server response.

### 5.5 Subscription Detail

**Visual structure:**

- Plan and subscription status.
- Coverage dates.
- Ledger/payment entries.
- Payment request status.
- Receipt action after approval.
- Submit evidence action only when valid.
- Explain when no receipt exists because payment is not approved.

### 5.6 Assign Subscription — owner/admin

**Visual structure:**

- Selected member identity.
- Active branch.
- Plan selector using real subscription IDs correctly.
- New assignment summary.
- Optional assisted payment/evidence flow.
- QR display for plan purchase where permitted.

Existing subscription terms remain snapshot-based and immutable after assignment.

---

## 6. Payments module

### 6.1 Payments tab

**App bar:** Payments.

**Period tabs:**

- Today.
- Yesterday.
- This week.
- This month.
- This year.

**Member view:**

- Only the current member’s payments.
- Use the member’s signed amount direction consistently; do not show organization-level income as the member’s own payment.
- Show plan, date, amount, method, status, evidence count, reference, and receipt number.

**Owner/admin view:**

- Branch/org scoped according to permission.
- Member avatar and name on every card.
- Approval actions only for payment-review permission.

### 6.2 Payment Detail / Receipt

**Content sections:**

1. Member identity/avatar when permitted.
2. Payment amount.
3. Confirmed/posted amount.
4. Method and status.
5. Reference and note.
6. Submitted/posted dates.
7. Receipt number and issue date.
8. Evidence list.
9. Linked subscription plan.

Approved payment shows receipt details. Pending/rejected payment clearly explains why a receipt is unavailable.

---

## 7. Members and admissions module — owner/admin views

These screens are hidden or route-blocked for a normal member.

### 7.1 Member Directory

- Header: Member Directory.
- Search and status filters.
- Summary counts.
- Active/requested/suspended/deactivated states.
- Member rows/cards with avatar, name, member number, role, plan status, and last activity.
- Actions are permission-gated.

### 7.2 Join Requests

- Requested member identity and avatar.
- Organization/branch context.
- Requested time and source.
- Approve/reject actions.
- Default role assignment after approval.
- Safe empty/error/forbidden states.

### 7.3 Member Detail

- Identity/profile information.
- Membership status.
- Role and branch.
- Subscription/fee summary.
- Attendance summary.
- Payment summary.
- Configure action only with permission.

### 7.4 Configure Member

- Member header/avatar/member number.
- Role.
- Manager.
- Shift.
- Subscription.
- Attendance policy link/assignment.
- Salary eligibility and salary structure.
- Administrative controls.
- Danger zone with explicit confirmation.

### 7.5 New Admission

- Assisted staff admission flow.
- Person identity and membership details.
- Role/branch assignment.
- Subscription assignment.
- Evidence/payment handling.
- Final server-confirmed admission.

---

## 8. Organization and branch settings

### 8.1 Settings tab

**Member view:**

- Active organization/branch context pill.
- Profile card with avatar, name, email, role, and Edit action.
- Read-only organization card.
- Empty management section when no management permissions exist.
- Workspace settings rows.
- Sign out.

**Owner/admin view:**

The same page conditionally adds permission-gated cards:

- Roles & Permissions.
- Members & Admissions.
- Branch Locations.
- Subscription Plans.
- Shift Configuration.
- Payroll & Compensation.

Never show a card merely because the route exists. Derive visibility from effective permissions, membership state, and active branch.

### 8.2 Profile

- Avatar and identity header.
- Edit name and profile fields.
- Google-verified sign-in indicator.
- Image picker with upload progress/error.
- Save confirmation.

### 8.3 Organization Edit

- Owner/admin only.
- Organization name, slug, website, industry, contact, and logo where supported.
- Group fields logically.
- Explicit save state and safe error handling.

### 8.4 Branch Management

- Branch list with active/inactive state.
- Add branch action.
- Edit branch action.
- Branch address/timezone/geofence context.
- Permanent join/gate QR display and revoke/replace controls where authorized.

### 8.5 Add/Edit Branch

- Branch identity.
- Address/location.
- IANA timezone.
- Geofence configuration.
- Join/gate QR section.
- Save and server-confirmed success.

### 8.6 Roles & Permissions

- Role list.
- Protected/system role indicators.
- Permission groups.
- Scope labels: self, team, branch, organization/all.
- Save only after explicit review.
- Never allow the final owner to be removed or protected system roles to be weakened.

### 8.7 Subscription Plan Management

- Plan list.
- Active/inactive state.
- Duration, amount, currency, admission fee.
- Create/edit/archive actions.
- Permanent plan-purchase QR display.
- Existing subscriptions keep their plan snapshot.

### 8.8 Shift Management

- Shift list.
- Start/end times.
- Overnight indicator.
- Grace/duty information.
- Create/edit/archive actions.

### 8.9 Payroll Management

- Salary structures.
- Salary eligibility.
- Payroll runs.
- Earnings/deductions/net payable.
- Draft/finalized states.
- Finalized records cannot be edited in place.

---

## 9. Notifications and communication

### 9.1 Notifications

- App bar title: Notifications.
- Unread rows use a small orange marker and stronger text weight.
- Read rows become neutral white/black rows.
- Each row shows title, body, timestamp, and read state.
- Mark individual read and Mark all read.
- Empty state: “You are all caught up.”

### 9.2 Announcements

Announcements are part of the product model and permission catalog. When implemented as a screen, follow the same inbox style:

- Announcement list.
- Organization/branch audience label.
- Role/member targeting label where permitted.
- Read/unread state.
- Detail view.

Do not invent an unrelated social-feed design.

---

## 10. Permission-aware screen rules

### Normal member

The normal member sees:

- Attendance tab and self-scoped records.
- Self Attendance, gate QR attendance, and detail/evidence permitted for self.
- Own Fees/subscription and Buy Plan when eligible.
- Own Payments and payment detail.
- Settings, Profile, context switching, and sign out.

The normal member does not see:

- Member directory.
- Join request review.
- Other people’s attendance.
- Organization-level fees or payments.
- Role management.
- Branch management.
- Attendance policy management.
- Plan management.
- Shift management.
- Payroll management.

### Owner/admin/staff

Management cards and screens appear only when the effective permission allows the action. The server remains the final authorization boundary for every route and API command.

### Scope safety

- Self permissions can only target the acting member.
- Team permissions are restricted to the reporting subtree.
- Branch/all permissions require explicit catalog permissions.
- Organization and branch identifiers are derived/validated server-side.
- Never use hidden UI as a security mechanism.

---

## 11. Navigation map

```text
Onboarding
  └─ Continue with Google
      ├─ Join or Create
      │   ├─ Organization Discovery
      │   │   ├─ Organization Detail
      │   │   └─ QR Scanner
      │   ├─ Create Organization
      │   │   └─ Create Branch
      │   └─ Context Switcher
      └─ Main Shell
          ├─ Attendance
          │   ├─ Self Attendance
          │   │   ├─ QR Scanner
          │   │   │   └─ Gate Attendance
          │   │   └─ Attendance Detail
          │   ├─ Attendance Detail
          │   └─ Attendance Policy (authorized settings users)
          ├─ Fees
          │   ├─ Buy a Plan
          │   ├─ Subscription Purchase
          │   └─ Subscription Detail
          ├─ Payments
          │   └─ Payment Detail / Receipt
          └─ Settings
              ├─ Profile
              ├─ Context Switcher
              ├─ Organization Edit
              ├─ Branch Management
              ├─ Roles & Permissions
              ├─ Subscription Plan Management
              ├─ Shift Management
              └─ Payroll Management
```

---

## 12. Current implementation fidelity notes

These notes prevent a coding agent from assuming that every route constant is a registered standalone route.

- `/home` is the main shell; Attendance, Fees, Payments, and Settings are embedded tabs.
- `attendance`, `fees`, `attendanceDetail`, and `subscriptionDetail` route constants exist for domain naming, but several detail screens currently open through `MaterialPageRoute` from their parent page.
- `NotificationsPage` exists and is routed, but it is not currently a bottom-navigation item.
- `announcements` is declared as a route constant but does not currently have a registered mobile page.
- `branchSelection` is declared as a route constant but context selection currently uses Context Switcher/Discovery flows.
- `newAdmission` is referenced by the member directory and must remain registered before that action is used in production.
- The QR Scanner is shared by joining, plan purchase, and attendance. Its attendance-specific next step is Gate Attendance.
- The Attendance Policy page is an owner/admin settings screen, not a normal member screen.

When implementing or rebuilding, preserve existing working behavior and close route gaps explicitly rather than silently creating placeholder pages.

---

## 13. Acceptance checklist for every screen

Before marking a screen complete, verify:

- [ ] Correct module and navigation order.
- [ ] Correct active organization/branch context is visible where operational data appears.
- [ ] Correct role/permission visibility.
- [ ] API still enforces the same permission and tenant scope.
- [ ] White/black/logo-orange palette only for redesigned content.
- [ ] Space Grotesk and existing Dailio logo are preserved.
- [ ] Bottom navigation is unchanged.
- [ ] Loading state exists.
- [ ] Empty state exists.
- [ ] Error and retry state exists.
- [ ] Forbidden state is safe and understandable.
- [ ] Offline/stale state is explicit where relevant.
- [ ] Success/pending state is distinguishable from server confirmation.
- [ ] Destructive, security-sensitive, and financial actions require confirmation.
- [ ] Color is not the only status signal.
- [ ] Private evidence, precise location, tokens, and secrets never appear in logs or public UI.
- [ ] Changed behavior has the relevant unit/API/widget/integration test.

---

## 14. Implementation order for a coding agent

Implement in this order to keep the app usable after every stage:

1. Preserve the existing app shell and bottom navigation.
2. Establish shared Dailio palette, spacing, card, app-bar, chip, and button primitives.
3. Complete Attendance overview.
4. Complete Self Attendance and policy display.
5. Complete QR Scanner → Gate Attendance → Attendance Detail.
6. Complete Attendance Policy management.
7. Complete Fees member view, then owner/admin view.
8. Complete Buy Plan → Subscription Purchase → Subscription Detail.
9. Complete Payments list and Payment Detail/Receipt.
10. Complete Settings and Profile.
11. Complete member/admission management screens.
12. Complete organization, branch, role, plan, shift, and payroll screens.
13. Add or register missing Notifications/Announcements/New Admission routes.
14. Run analyzer, widget tests, API tests, tenant-isolation tests, permission tests, and physical-device verification.

The agent must not change product terminology, authorization semantics, financial rules, attendance evidence rules, QR permanence, or bottom navigation while applying this visual specification.
