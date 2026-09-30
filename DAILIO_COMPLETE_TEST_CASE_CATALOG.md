# Dailio Complete Test Case Catalogue

**Purpose:** End-to-end, API, security, reliability, and UI test coverage for every currently implemented Dailio page and user flow.

**Last reviewed:** 2026-09-29  
**Scope:** Flutter mobile app, TypeScript API, PostgreSQL/Prisma, JSON cache, FCM, email delivery, media upload, jobs, and tenant/RBAC boundaries.

## How to use this file

Each case has a stable ID. Execute cases in the listed order for a new environment, then rerun the regression sections after every release.

Status notation:

- `[ ]` Not executed or not yet automated.
- `[~]` Existing automated coverage is present; still run the manual acceptance path where listed.
- `[x]` Passed with evidence attached to the release record.
- `[!]` Known gap or blocked by an implementation/product decision.

The catalogue is a test plan, not a claim that every case has already passed. A case is complete only when the expected result is observed and the evidence is recorded.

## Required test fixtures

Create these before executing the full suite:

| Fixture | Required data |
|---|---|
| `ORG_A` | Fitness Gym, branches `Barari` and `Downtown`, Asia/Kolkata timezone |
| `ORG_B` | A second organization owned by a different user |
| `OWNER_A` | Active owner of `ORG_A` |
| `ADMIN_A` | Admin with branch/all operational permissions but no owner-only permissions |
| `TRAINER_A` | Trainer/team role with limited attendance scope |
| `MEMBER_A` | Active member with an active subscription |
| `MEMBER_B` | Active member with no subscription and a pending join/request state when needed |
| `OUTSIDER` | User with no membership in `ORG_A` |
| `PLAN_1` | 1 month, INR 1,000, admission fee INR 100 |
| `PLAN_3` | 3 months, INR 2,500, no admission fee |
| `FEED_1` | Participants `MEMBER_A` and `MEMBER_B`, posting enabled |
| `FEED_2` | Same participants, posting disabled |
| `MEDIA_SET` | Small image, large image, invalid type, corrupt image, multi-slide set |
| `CLOCK` | A controllable device clock/location or seeded server records for today/yesterday/month/year boundaries |

Use at least two devices and two accounts for notification, concurrent-action, cache, and permission tests. Use two organizations for every cross-tenant case.

## Global acceptance rules

Run these against every page that loads data or submits a mutation:

- [ ] Loading state is visible and matches the page layout; no blank, overflow, duplicate, or infinite skeleton.
- [ ] Cached JSON is shown immediately when available; the fresh response replaces it without losing scroll, selected tab, or local user action.
- [ ] First-load empty, forbidden, expired-session, timeout, offline, server-error, and retry states are distinct and actionable.
- [ ] Pull-to-refresh and retry are idempotent and do not duplicate list rows.
- [ ] Back navigation preserves the correct parent tab/context and does not resubmit a mutation.
- [ ] All actions are disabled while their own request is pending; repeated taps cannot create duplicates.
- [ ] Success updates the visible state immediately, then reconciles with the server response.
- [ ] Failed optimistic actions roll back and show a retryable error.
- [ ] Tenant, branch, member, permission, and self/all scopes are enforced by the API, not only hidden by the UI.
- [ ] Sensitive location, selfie, token, payment, and secret values never appear in UI logs or API logs.
- [ ] Indian locale/timezone presentation is correct while stored timestamps remain UTC.
- [ ] Accessibility: labels, tap targets, contrast, keyboard focus, screen reader order, and dynamic text do not break layout.
- [ ] Android back, app background/foreground, rotation where supported, process restart, and deep links are safe.
- [ ] Every destructive, financial, permission, membership, or lifecycle action uses the reusable confirmation UI.

---

## 1. Authentication and onboarding

### `AUTH` — Onboarding/Login (`/onboarding`)

- [ ] `AUTH-01` Fresh install opens onboarding/login and does not expose protected data.
- [ ] `AUTH-02` Google sign-in opens account chooser when multiple accounts exist.
- [ ] `AUTH-03` Selecting a valid account creates/loads the correct global user and enters context selection.
- [ ] `AUTH-04` Cancelled Google sign-in returns to the login state without an error toast.
- [ ] `AUTH-05` Invalid/expired Google token is rejected by the API with a safe message.
- [ ] `AUTH-06` Android debug build succeeds with the registered debug SHA-1.
- [ ] `AUTH-07` Release/ Shorebird APK succeeds with the registered release or Play App Signing SHA-1.
- [ ] `AUTH-08` Wrong package/SHA/client ID produces an actionable configuration error and no partial login.
- [ ] `AUTH-09` FCM permission prompt appears at the intended first-run point; deny, allow, and later-enable paths work.
- [ ] `AUTH-10` FCM token registration is retried safely and never blocks login.
- [ ] `AUTH-11` Existing access/refresh tokens restore the session after app restart.
- [ ] `AUTH-12` Expired access token refreshes once, retries the original request once, and does not loop.
- [ ] `AUTH-13` Invalid refresh token returns to onboarding and clears protected cached data.
- [ ] `AUTH-14` Logout revokes the refresh token, clears JSON cache/session state, and returns to onboarding.
- [ ] `AUTH-15` Account deletion confirms, deletes/archives according to policy, clears local data, and prevents reuse of old tokens.

### `CTX` — Join/create/context selection

- [ ] `CTX-01` `Join or create` shows both choices and respects current auth state.
- [ ] `CTX-02` Create organization validates required name, duplicate/invalid values, and creates the owner context.
- [ ] `CTX-03` Create organization failure preserves entered values and allows retry.
- [ ] `CTX-04` Create branch validates name, timezone, address/contact fields, and creates the branch under the selected organization.
- [ ] `CTX-05` Back from create branch returns without creating a partial organization/branch.
- [ ] `CTX-06` Organization discovery loads, searches, paginates/refreshes, and shows an empty state.
- [ ] `CTX-07` Discovery never shows branches from another organization outside the allowed discovery response.
- [ ] `CTX-08` Organization detail lists only accessible branches and opens the join flow.
- [ ] `CTX-09` QR scanner accepts a valid permanent branch invite from the camera.
- [ ] `CTX-10` QR scanner accepts the same valid QR from the gallery.
- [ ] `CTX-11` Invalid, expired, revoked, plan, and unrelated QR payloads show the correct error and do not submit a request.
- [ ] `CTX-12` Camera permission denied, unavailable camera, torch, camera switch, and scanner retry work.
- [ ] `CTX-13` Valid QR shows confirmation details before joining; cancellation makes no request.
- [ ] `CTX-14` Join request submits once, becomes `REQUESTED`, and duplicate taps/retries remain idempotent.
- [ ] `CTX-15` Inactive/suspended branch membership returns the correct owner-contact message and does not create access.
- [ ] `CTX-16` Pending join page shows pending state, refresh/check approval, rejection, and approved transitions.
- [ ] `CTX-17` Approved user enters the correct branch; rejected user can choose another context.
- [ ] `CTX-18` Context switcher lists only the current user’s organizations/branches and persists the selected context.
- [ ] `CTX-19` Switching context clears scoped stale cache, reloads badges, and cannot leak prior branch data.
- [ ] `CTX-20` `ORG_A` identifiers cannot be used to read or mutate `ORG_B` data.

---

## 2. Main shell, navigation, profile, and notifications

### `SHELL` — App shell and bottom navigation

- [ ] `SHELL-01` Five shell destinations open: Announcements, Attendance, Fees, Payments, Settings.
- [ ] `SHELL-02` Selected destination, icon, label, safe area, toast, and screen-level FAB render correctly.
- [ ] `SHELL-03` Changing branch context rebuilds each page with the new context only.
- [ ] `SHELL-04` Announcement, attendance, and payment badges show the correct current-day counts.
- [ ] `SHELL-05` Badge counts do not flicker, become stale after refresh, or duplicate after app resume.
- [ ] `SHELL-06` Tapping a badge destination marks only the intended records read/seen according to its module rules.
- [ ] `SHELL-07` Screen-level FABs appear only on screens that own the action; no FAB appears on Payments/Settings where not applicable.
- [ ] `SHELL-08` Global toast remains compact, non-blocking, screen-aware, and does not cover input or navigation.
- [ ] `SHELL-09` Overflow menus are compact, dismiss on outside tap/back, and expose only permitted actions.

### `PROFILE` — Profile (`/profile`)

- [ ] `PROFILE-01` Loads the current user’s profile and never another user’s profile as the editable self profile.
- [ ] `PROFILE-02` Edit name, phone, date of birth, emergency contact, and supported fields with validation.
- [ ] `PROFILE-03` Profile image preview is local first, upload occurs on save, and failed upload preserves the old image.
- [ ] `PROFILE-04` Save is optimistic only for safe profile fields, disables duplicate submissions, and reconciles server data.
- [ ] `PROFILE-05` Cancel/back with unsaved changes asks for confirmation; discard preserves server values.
- [ ] `PROFILE-06` Invalid phone/date/empty name and oversized/invalid image show field-level errors.
- [ ] `PROFILE-07` Tapping any supported DP opens the reusable profile popup with call, WhatsApp, info, and zoom actions where data permits.
- [ ] `PROFILE-08` Missing phone/email/avatar hides unavailable actions without breaking layout.

### `NOTIFY` — Notification page (`/notifications`)

- [ ] `NOTIFY-01` App-bar notification icon opens the notification page and shows the correct unread badge.
- [ ] `NOTIFY-02` Page lists notifications with actor DP, related image/media when available, title, body, time, and status.
- [ ] `NOTIFY-03` Opening the page marks unread notifications read exactly once; failed mark-read can retry.
- [ ] `NOTIFY-04` Opening one notification marks only that item read and navigates to a valid entity when possible.
- [ ] `NOTIFY-05` Read-all is idempotent and updates the app-bar/bottom badge immediately.
- [ ] `NOTIFY-06` Empty, loading, stale-cache, offline, forbidden, and server-error states work.
- [ ] `NOTIFY-07` Notification pagination/deduplication keeps stable order and does not show the same item twice.
- [ ] `NOTIFY-08` Preferences load and save per channel/event; invalid preferences are rejected safely.
- [ ] `NOTIFY-09` Notification deep link to deleted/cancelled/inaccessible content shows a safe fallback.
- [ ] `NOTIFY-10` Actor avatar and related image use protected URLs and never expose private media publicly.
- [ ] `NOTIFY-11` In-app, FCM, and email delivery share the same event/dedupe identity.

---

## 3. Announcements module

### `ANN-LIST` — Announcement page (`/announcements`)

- [ ] `ANN-LIST-01` Loads published announcements visible to the current user and current branch.
- [ ] `ANN-LIST-02` Announcement tab is centered as designed; feed tabs and add-feed action are shown only when allowed.
- [ ] `ANN-LIST-03` Refresh, cached-first load, stale replacement, empty state, timeout, and retry work.
- [ ] `ANN-LIST-04` Each card shows actor DP, title/body preview, media at real aspect ratio, reaction state/count, comments preview, and time.
- [ ] `ANN-LIST-05` Two or three comments preview correctly and does not load comments from another post.
- [ ] `ANN-LIST-06` Tapping the card opens the correct announcement detail.
- [ ] `ANN-LIST-07` Tapping actor/avatar opens the reusable profile popup.
- [ ] `ANN-LIST-08` Announcement badge reflects today’s actionable/new items and resets only under the defined read rule.
- [ ] `ANN-LIST-09` Creator/admin overflow exposes only permitted edit/cancel actions.
- [ ] `ANN-LIST-10` Cancelled/expired/unauthorized announcements disappear or show the correct management state.

### `ANN-CREATE` — Create/update announcement (`/announcements/new`, `/announcements/:id/edit`)

- [ ] `ANN-CREATE-01` Composer opens with the same fields and editor behavior for create and update.
- [ ] `ANN-CREATE-02` Title/body required validation, length limits, whitespace-only values, and malformed links are rejected.
- [ ] `ANN-CREATE-03` Audience `all active members`, selected roles, and selected members save the correct recipients.
- [ ] `ANN-CREATE-04` Empty/invalid role or member selection is handled without silently widening the audience.
- [ ] `ANN-CREATE-05` Priority, publish time, expiry time, and branch scope validate local/UTC boundaries correctly.
- [ ] `ANN-CREATE-06` Rich blocks support paragraph, heading, quote, divider, bold, italic, underline, link, image, and slide.
- [ ] `ANN-CREATE-07` Image/slide selection previews locally before upload; cancel removes only the selected media.
- [ ] `ANN-CREATE-08` Invalid type, oversized image, corrupt file, and upload failure show recoverable errors.
- [ ] `ANN-CREATE-09` Publish uploads media, attaches returned storage keys/URLs to content blocks, and creates exactly one announcement.
- [ ] `ANN-CREATE-10` Publish double-tap, timeout retry, app background, and process restart cannot duplicate the announcement.
- [ ] `ANN-CREATE-11` Update preserves existing media unless explicitly removed and does not rewrite unrelated content.
- [ ] `ANN-CREATE-12` Back with unsaved content asks for confirmation and draft loss is intentional/visible.
- [ ] `ANN-CREATE-13` Member without `ANNOUNCEMENT_CREATE` cannot open or submit the composer through a direct route/API call.
- [ ] `ANN-CREATE-14` Server validation failure maps to the correct field/error state and preserves the editor content.

### `ANN-DETAIL` — Detail, reaction, comments, and moderation

- [ ] `ANN-DETAIL-01` Detail page loads the selected announcement, actor, all content blocks, media, counts, and current reaction.
- [ ] `ANN-DETAIL-02` Protected images load with the correct signed/protected URL and retain natural aspect ratio/full width.
- [ ] `ANN-DETAIL-03` Missing/expired media shows a compact fallback, not a raw storage filename or grey broken image.
- [ ] `ANN-DETAIL-04` React with each supported reaction updates state/count immediately and syncs once.
- [ ] `ANN-DETAIL-05` Selecting the same reaction again removes it; switching reaction replaces it rather than incrementing twice.
- [ ] `ANN-DETAIL-06` Reaction timeout/error rolls back optimistic state and permits retry.
- [ ] `ANN-DETAIL-07` Comments load in stable order with actor DP and deleted-comment treatment.
- [ ] `ANN-DETAIL-08` Create a comment, empty comment, max-length comment, and duplicate submit behave correctly.
- [ ] `ANN-DETAIL-09` Reply to a comment stores `reply_to_id`, renders nested/associated reply, and notifies the parent commenter.
- [ ] `ANN-DETAIL-10` Delete own comment soft-deletes it; deleting another user’s comment requires permission.
- [ ] `ANN-DETAIL-11` Creator edit opens the same composer with existing data; unauthorized edit is rejected.
- [ ] `ANN-DETAIL-12` Cancel announcement requires confirmation, changes lifecycle state, and prevents normal member access.
- [ ] `ANN-DETAIL-13` Creator/admin action after cancellation is safe and idempotent.
- [ ] `ANN-DETAIL-14` Deep link to nonexistent, expired, cancelled, or cross-tenant announcement shows safe not-found/forbidden state.
- [!] `ANN-DETAIL-15` Permanent announcement delete: no delete announcement API route currently exists; verify product decision is cancel/archive, or add and test a separately authorized soft-delete flow. Never hard-delete audit/history silently.

### `ANN-NOTIFY` — Announcement notifications

- [ ] `ANN-NOTIFY-01` Published announcement reaches exactly the intended recipients in-app, FCM, and email according to preferences.
- [ ] `ANN-NOTIFY-02` Comment notifies the announcement actor, excluding the commenter when they are the actor.
- [ ] `ANN-NOTIFY-03` Reply notifies the parent commenter and announcement actor without duplicate deliveries.
- [ ] `ANN-NOTIFY-04` Reaction notifies the actor and toggling unlike does not create a second reaction notification.
- [ ] `ANN-NOTIFY-05` Recipient audience changes do not leak the announcement to non-recipients.
- [ ] `ANN-NOTIFY-06` Actor DP and related announcement image appear in notification UI/email when available.

---

## 4. Feeds module

### `FEED-LIST` — Feed tabs and feed timeline

- [ ] `FEED-LIST-01` Announcement tab plus `Feed 1`, `Feed 2`, and add-feed action render in the correct order.
- [ ] `FEED-LIST-02` Only feeds the current user can read are listed; disbanded feeds show the defined archived state.
- [ ] `FEED-LIST-03` Switching feeds loads the correct posts without mixing cached posts between feeds.
- [ ] `FEED-LIST-04` Feed cards show actor DP, title/body, full-width real-height media/slides, reactions, comments, and timestamps.
- [ ] `FEED-LIST-05` Post image loading never displays a storage key, filename, raw URL, or permanent grey placeholder.
- [ ] `FEED-LIST-06` Refresh, cache-first, empty, error, offline, and pagination states work.
- [ ] `FEED-LIST-07` Feed read/unread state updates after opening a post and updates related notification/badge state.
- [ ] `FEED-LIST-08` Participant who cannot post sees no usable create-post action and direct API post is forbidden.

### `FEED-MANAGE` — Create/update/disband/feed participants

- [ ] `FEED-MANAGE-01` Create feed validates name, participants, posting toggle, timeout, and report threshold.
- [ ] `FEED-MANAGE-02` Feed can be created with no participants only when the permission/product rule allows it.
- [ ] `FEED-MANAGE-03` Add participant works for an active member in the same branch and is idempotent.
- [ ] `FEED-MANAGE-04` Add outsider, inactive member, duplicate participant, or cross-tenant member is rejected.
- [ ] `FEED-MANAGE-05` Remove participant removes access and prevents future reads/posts while preserving history as required.
- [ ] `FEED-MANAGE-06` Update feed changes only editable fields and preserves participants/history.
- [ ] `FEED-MANAGE-07` Disband feed requires confirmation, is idempotent, stops new posts, and applies the correct read-only state.
- [ ] `FEED-MANAGE-08` Unauthorized create/update/participant/disband actions fail through direct API calls.
- [ ] `FEED-MANAGE-09` Feed timeout rejects posts after the configured window and shows the correct reason.
- [ ] `FEED-MANAGE-10` Report threshold behavior is deterministic and does not disband on unrelated/cross-tenant reports.

### `FEED-POST` — Create/update post (`/feeds/:feedId/posts/new|edit`)

- [ ] `FEED-POST-01` Create and update use the same editor UI/validation contract as announcements.
- [ ] `FEED-POST-02` Required title/body and maximum lengths are enforced client and server side.
- [ ] `FEED-POST-03` Paragraph, heading, quote, divider, bold, italic, underline, link, image, and slide blocks work.
- [ ] `FEED-POST-04` Images/slides preview locally and upload only while publishing; failed upload does not publish a broken post.
- [ ] `FEED-POST-05` Multiple slides preserve order, indices, aspect ratios, and captions/alt text.
- [ ] `FEED-POST-06` Double publish, timeout retry, back navigation, and app restart are idempotent.
- [ ] `FEED-POST-07` Update preserves existing media and removes media only when explicitly requested.
- [ ] `FEED-POST-08` Participant-posting toggle and permissions are rechecked by the API at publish time.
- [ ] `FEED-POST-09` Draft/editor errors preserve all typed content and selected media metadata.

### `FEED-DETAIL` — Post detail, social actions, delete, report

- [ ] `FEED-DETAIL-01` Detail page opens the correct feed/post and loads actor/media/comments.
- [ ] `FEED-DETAIL-02` React, switch reaction, unlike, optimistic update, rollback, and duplicate-tap protection work.
- [ ] `FEED-DETAIL-03` Create comment and reply store correct feed/post/parent IDs and show immediately.
- [ ] `FEED-DETAIL-04` Delete own comment soft-deletes; unauthorized comment deletion is rejected.
- [ ] `FEED-DETAIL-05` Creator can edit own post; non-creator cannot edit through UI or direct API.
- [ ] `FEED-DETAIL-06` Creator delete asks confirmation, removes the post from feed/detail after success, and remains removed after refresh/cache reconciliation.
- [ ] `FEED-DETAIL-07` Delete timeout/error keeps the post visible and offers retry; repeated delete is safe.
- [ ] `FEED-DETAIL-08` Report requires a reason, prevents duplicate report spam, and updates moderation state at threshold.
- [ ] `FEED-DETAIL-09` A user cannot report/read/react/comment on a post outside an accessible feed.
- [ ] `FEED-DETAIL-10` Read marker is sent once and does not mark another post read.

### `FEED-NOTIFY` — Feed notifications

- [ ] `FEED-NOTIFY-01` Adding a participant creates an in-app, FCM, and email notification when enabled.
- [ ] `FEED-NOTIFY-02` Feed post notifies only intended participants and excludes the author where defined.
- [ ] `FEED-NOTIFY-03` Feed comment/reply/reaction notifications identify the actor and related post image.
- [ ] `FEED-NOTIFY-04` Unlike/delete/retry does not create duplicate or stale notifications.
- [ ] `FEED-NOTIFY-05` Disbanded/removed participants cannot receive new feed notifications.

---

## 5. Attendance module

### `ATT-LIST` — Attendance page (`/home/attendance`)

- [ ] `ATT-LIST-01` Today, yesterday, week, and month filters request the correct branch-local date range.
- [ ] `ATT-LIST-02` Role tabs filter without mixing owner/admin/member records.
- [ ] `ATT-LIST-03` Tiles show DP, name/role, latest event, date, status badge, and menu correctly.
- [ ] `ATT-LIST-04` Active, completed, late, absent, open, corrected, and policy-failed statuses display accurately.
- [ ] `ATT-LIST-05` Admin/all scope sees permitted records; member/self scope sees only own records.
- [ ] `ATT-LIST-06` Refresh, cache-first, skeleton, empty, timeout, and retry states work.
- [ ] `ATT-LIST-07` Tapping DP opens profile popup; tapping tile opens the correct session detail.
- [ ] `ATT-LIST-08` Export appears only with `ATTENDANCE_EXPORT` and downloads the correct filtered data.

### `ATT-SELF` — Self attendance (`/home/attendance/self` or shell action)

- [ ] `ATT-SELF-01` Today view shows current policy parameters, branch, timezone, and current open-session state.
- [ ] `ATT-SELF-02` Clock-in action shows confirmation/policy information before submitting.
- [ ] `ATT-SELF-03` Required location freshness, accuracy, geofence, selfie, QR/gate, and confirmation rules are enforced in order.
- [ ] `ATT-SELF-04` Clock-in succeeds once with server time; repeated taps/retries return the same session.
- [ ] `ATT-SELF-05` QR gate scan starts the same policy-checked clock-in flow; gallery QR, invalid QR, revoked QR, and wrong branch are rejected.
- [ ] `ATT-SELF-06` Open session shows timeline and clock-out action; no second open session can be created.
- [ ] `ATT-SELF-07` Clock-out follows all configured policy/evidence rules and uses authoritative server timestamp.
- [ ] `ATT-SELF-08` Clock-out retry after timeout is idempotent and does not create a second session.
- [ ] `ATT-SELF-09` Attendance Record tab shows only the current user’s records with date filters and detail navigation.
- [ ] `ATT-SELF-10` Offline mode never displays a locally queued punch as server-confirmed.
- [ ] `ATT-SELF-11` Permission denied, stale location, outside geofence, invalid selfie, and QR failures explain the exact next action.

### `ATT-GATE` — Gate attendance (`/home/attendance/gate`)

- [ ] `ATT-GATE-01` Permanent printed branch QR resolves to the intended branch/gate purpose.
- [ ] `ATT-GATE-02` Member camera scan and gallery scan both work.
- [ ] `ATT-GATE-03` Gate QR cannot be used to join a branch, purchase a plan, or punch another branch.
- [ ] `ATT-GATE-04` Clock-in/clock-out direction is determined from the user’s current open session, not client input.
- [ ] `ATT-GATE-05` Geofence, freshness, policy, membership, and status checks run in the required order.
- [ ] `ATT-GATE-06` Rate limiting, replay, malformed payload, revoked token, and concurrent scans are safe.
- [ ] `ATT-GATE-07` Success updates self page, attendance list, cache, badge, and notification state.

### `ATT-DETAIL` — Attendance detail (`/home/attendance/:session_id`)

- [ ] `ATT-DETAIL-01` Detail shows timeline of all events, server times, local date, policy result, and evidence.
- [ ] `ATT-DETAIL-02` Location evidence opens the correct point in Google Maps without exposing unrelated location data.
- [ ] `ATT-DETAIL-03` Selfie/evidence preview is protected, zoomable where appropriate, and unavailable after retention expiry.
- [ ] `ATT-DETAIL-04` Member cannot open another member’s detail without the required permission.
- [ ] `ATT-DETAIL-05` Correction action requires permission, reason, preserves original values/evidence, and adds audit history.
- [ ] `ATT-DETAIL-06` Concurrent correction/punch operations produce one consistent state.

### `ATT-POLICY` — Attendance policy and assignment

- [ ] `ATT-POLICY-01` Policy list loads active/versioned policies and branch scope.
- [ ] `ATT-POLICY-02` Create/update policy validates geofence, location accuracy/freshness, selfie, QR, schedule, grace, and maximum session rules.
- [ ] `ATT-POLICY-03` Assign policy to a member/role applies to the correct effective date and does not rewrite past sessions.
- [ ] `ATT-POLICY-04` Removing/changing policy preserves historical policy snapshots.
- [ ] `ATT-POLICY-05` Unauthorized policy read/manage/assign API calls return forbidden.
- [ ] `ATT-POLICY-06` Invalid timezone, negative values, conflicting limits, and missing required settings are rejected.

### `ATT-JOBS` — Attendance jobs/retention

- [ ] `ATT-JOBS-01` Daily missing-clock-out job runs once per business date despite concurrent app opens.
- [ ] `ATT-JOBS-02` Duplicate `job_key/business_date` does not surface an unhandled Prisma error.
- [ ] `ATT-JOBS-03` Job lease/expiry/retry behavior recovers from a crashed runner.
- [ ] `ATT-JOBS-04` Missing clock-out notification is deduplicated per session/user/date.
- [ ] `ATT-JOBS-05` Evidence retention removes/invalidates private media according to policy while preserving audit metadata.

---

## 6. Fees, plans, subscriptions, and payments

### `FEE-LIST` — Fees page (`/home/fees`)

- [ ] `FEE-LIST-01` Active, expiring, expired, pending, requested, paid, and due states map to the correct cards/badges.
- [ ] `FEE-LIST-02` Card shows member DP, role, plan name, expiry/subtitle, paid/due amount, and date/menu.
- [ ] `FEE-LIST-03` Owner/admin all scope and member self scope show only authorized records.
- [ ] `FEE-LIST-04` Active non-expired member does not see an unnecessary buy-plan action.
- [ ] `FEE-LIST-05` Buy-plan action appears for eligible users and opens the self-purchase flow.
- [ ] `FEE-LIST-06` Cache-first, skeleton, empty, timeout, forbidden, refresh, and retry work.

### `PLAN-MGMT` — Subscription plans (`/home/branch/subscription-plans`)

- [ ] `PLAN-MGMT-01` List plans by branch and active state.
- [ ] `PLAN-MGMT-02` Create plan validates name, duration, currency, price minor units, admission fee, and active state.
- [ ] `PLAN-MGMT-03` Update plan does not rewrite existing subscription snapshots.
- [ ] `PLAN-MGMT-04` Duplicate name/conflicting values/negative or floating money are rejected.
- [ ] `PLAN-MGMT-05` Permanent plan QR generation displays Dailio branding and does not expire/revoke unexpectedly.
- [ ] `PLAN-MGMT-06` Plan QR resolves only to the intended plan/branch and cannot be edited by a member.
- [ ] `PLAN-MGMT-07` Unauthorized plan read/manage calls fail through direct API access.

### `FEE-BUY` — Buy plan/subscription purchase

- [ ] `FEE-BUY-01` Eligible member sees available plans with correct currency and fee breakdown.
- [ ] `FEE-BUY-02` Active plan prevents duplicate/overlapping purchase unless renewal is explicitly allowed.
- [ ] `FEE-BUY-03` Permanent plan QR opens the correct plan with autofilled branch/plan values.
- [ ] `FEE-BUY-04` Payment method, UTR/reference, note, evidence upload, and amount validation work.
- [ ] `FEE-BUY-05` Evidence previews locally, uploads through the supported signature flow, and attaches only the returned protected key.
- [ ] `FEE-BUY-06` Payment request is created exactly once with idempotency/retry handling.
- [ ] `FEE-BUY-07` Overpayment, underpayment, expired plan, inactive branch, and changed plan price are handled server-side.
- [ ] `FEE-BUY-08` Review/pending/approved/rejected states render correctly and refresh from the server.

### `SUBSCRIPTION` — Assignment/detail/renew/pause/cancel

- [ ] `SUBSCRIPTION-01` Admin assignment selects a valid member and plan and snapshots terms.
- [ ] `SUBSCRIPTION-02` Assignment rejects inactive/cross-branch member, inactive plan, duplicate active coverage, and unauthorized actor.
- [ ] `SUBSCRIPTION-03` Detail page shows plan, dates, totals, outstanding balance, access state, payments, activity, and receipt actions.
- [ ] `SUBSCRIPTION-04` Pause, resume, renew, cancel, and update each require the correct permission/state and confirmation.
- [ ] `SUBSCRIPTION-05` Repeated lifecycle commands are idempotent and invalid transitions return conflict.
- [ ] `SUBSCRIPTION-06` Member sees only own subscription unless granted all-scope permission.
- [ ] `SUBSCRIPTION-07` Receipt sheet has brand color, wavy edges, correct totals, image share, PDF/download behavior, and no raw secrets.

### `PAYMENT-LIST` — Payments page

- [ ] `PAYMENT-LIST-01` Today, yesterday, week, month, and year filters use branch-local boundaries.
- [ ] `PAYMENT-LIST-02` Member sees only own payment records and correct debit/credit direction.
- [ ] `PAYMENT-LIST-03` Admin/all scope sees permitted branch/org payments, never another tenant.
- [ ] `PAYMENT-LIST-04` Cards show actor DP, amount, direction badge, status, plan/reference, and timestamp.
- [ ] `PAYMENT-LIST-05` Loading skeleton matches cards; no overflow, blank grey shell, or duplicate rows.
- [ ] `PAYMENT-LIST-06` Refresh, cache-first, timeout, forbidden, empty, and retry work.

### `PAYMENT-DETAIL` — Payment detail/review/receipt

- [ ] `PAYMENT-DETAIL-01` Detail loads the correct request/attempt and shows immutable payment facts.
- [ ] `PAYMENT-DETAIL-02` Evidence preview/download uses protected access and correct media.
- [ ] `PAYMENT-DETAIL-03` Reviewer approve/reject requires permission, valid state, reason where required, and confirmation.
- [ ] `PAYMENT-DETAIL-04` Double review, stale review, timeout retry, and concurrent review are safe.
- [ ] `PAYMENT-DETAIL-05` Refund/void/correction requires the exact permission, reason, audit record, and immutable reversal.
- [ ] `PAYMENT-DETAIL-06` Receipt is generated from server ledger facts, can be shared as an image, and cannot be altered by client data.
- [ ] `PAYMENT-DETAIL-07` Member cannot inspect another member’s request, evidence, receipt, or payment attempt.

---

## 7. Organization, branch, member, role, and admission pages

### `ORG` — Organization/branch pages

- [ ] `ORG-01` Edit organization loads current values and validates updates.
- [ ] `ORG-02` Organization logo preview/upload/save/failure/rollback works and uses private media rules.
- [ ] `ORG-03` Manage branches lists only the organization’s branches with correct loading skeleton.
- [ ] `ORG-04` Add branch validates required fields and creates one branch under the active organization.
- [ ] `ORG-05` Edit branch updates only the selected branch; cross-tenant/branch IDs are rejected.
- [ ] `ORG-06` Branch QR is permanent, branded, scannable from camera/gallery, and cannot be revoked accidentally.
- [ ] `ORG-07` QR management action is permission-protected and audit logged.
- [ ] `ORG-08` All organization/branch pages use white background, compact tabs, correct app bar, skeleton, empty, error, and retry states.

### `MEMBER` — Members directory/detail/configuration

- [ ] `MEMBER-01` Directory loads branch members with role/status/branch tabs and search below the tab group.
- [ ] `MEMBER-02` Tabs, underline width, content margins, and tile spacing remain within the actual tab bounds.
- [ ] `MEMBER-03` Search by name/member number/phone filters server/client data without stale rows.
- [ ] `MEMBER-04` Role/status filters combine correctly and reset predictably.
- [ ] `MEMBER-05` Member tile shows DP, name, role/status, joined date, member number, and action menu.
- [ ] `MEMBER-06` Member detail loads subscription, payments, attendance summary, role, status, and profile information.
- [ ] `MEMBER-07` DP opens profile popup; call/WhatsApp/info actions use the correct phone/member.
- [ ] `MEMBER-08` Configure member assigns role/manager/shift/subscription only within the branch and with permission.
- [ ] `MEMBER-09` Duplicate subscription/invalid role/invalid shift/inactive member values are rejected.
- [ ] `MEMBER-10` Suspend and deactivate require confirmation, are idempotent, notify affected users, and preserve history.
- [ ] `MEMBER-11` Reactivate or recovery behavior matches the defined lifecycle; no ordinary destructive hard delete occurs.
- [ ] `MEMBER-12` Member skeleton mirrors real tiles and does not run layout recursively or null-assert missing data.

### `ADMISSION` — New admission entry point

- [ ] `ADMISSION-01` New admission is available only to users with `MEMBER_CREATE` and opens from the members page without losing the active branch.
- [ ] `ADMISSION-02` Required person/profile fields validate using the standard profile field design.
- [ ] `ADMISSION-03` Admission creates exactly one active/pending membership with the selected default role.
- [ ] `ADMISSION-04` Optional plan/subscription assignment uses a server-validated plan and immutable snapshot.
- [ ] `ADMISSION-05` Duplicate submit, duplicate existing member, inactive branch, and cross-tenant member cases are rejected safely.
- [ ] `ADMISSION-06` Successful admission refreshes directory, fees, notifications, cache, and audit state.
- [!] `ADMISSION-07` `newAdmission` is declared in route names and referenced by the members page, but no standalone `NewAdmissionPage` GoRoute is currently registered; verify the intended entry implementation before release.

### `JOIN` — Join requests

- [ ] `JOIN-01` Admin sees pending requests for the active branch only.
- [ ] `JOIN-02` Member name/DP/details and request date render correctly.
- [ ] `JOIN-03` Approve assigns the default role and creates/activates the correct membership exactly once.
- [ ] `JOIN-04` Reject requires confirmation/reason as configured and notifies the requester.
- [ ] `JOIN-05` Duplicate approve/reject and concurrent actions return the stable final state without Prisma unique errors.
- [ ] `JOIN-06` Existing active membership plus pending request is handled without duplicate `(user, branch, status)` records.
- [ ] `JOIN-07` Unauthorized read/approve/reject and cross-tenant request IDs are rejected.

### `ROLE` — Roles and permissions

- [ ] `ROLE-01` Role page loads roles scoped to organization/branch and shows centered compact tabs.
- [ ] `ROLE-02` Role skeleton matches the actual role/permission sections and remains stable during list updates.
- [ ] `ROLE-03` Create role validates name, scope, duplicate names, and allowed atomic permissions.
- [ ] `ROLE-04` Protected system/owner role cannot be deleted, weakened, or made ownerless.
- [ ] `ROLE-05` Edit role changes permissions only with `ROLE_UPDATE`, invalidates effective permission cache, and updates UI.
- [ ] `ROLE-06` Permission category expansion/collapse, select all, clear, and search preserve selected values.
- [ ] `ROLE-07` Assign role through member configuration applies branch scope correctly.
- [ ] `ROLE-08` Direct API attempts to grant `ALL`, cross-tenant role IDs, or protected permissions are rejected.
- [ ] `ROLE-09` A permission change immediately affects navigation/action visibility after refresh/context reload.

---

## 8. Shifts, payroll, leave, and operational settings

### `SHIFT` — Shift management

- [ ] `SHIFT-01` List shifts scoped to organization/branch and loads a real matching skeleton.
- [ ] `SHIFT-02` Create shift validates name, local start/end, overnight behavior, breaks, and duplicate conflicts.
- [ ] `SHIFT-03` Update shift preserves assigned-member history and validates affected assignments.
- [ ] `SHIFT-04` Delete shift requires confirmation and rejects deletion when invariants prevent it.
- [ ] `SHIFT-05` Unauthorized/cross-tenant shift mutations fail.

### `PAYROLL` — Payroll/salary structures

- [ ] `PAYROLL-01` List salary structures scoped to organization/branch.
- [ ] `PAYROLL-02` Create/update validates integer money minor units, currency, components, deductions, and effective date.
- [ ] `PAYROLL-03` Delete requires confirmation and preserves any generated/payroll audit history.
- [ ] `PAYROLL-04` Duplicate submit, invalid money, cross-tenant IDs, and unauthorized generation are rejected.
- [ ] `PAYROLL-05` UI is compact, consistent with profile fields, and skeleton matches real form/list layout.

### `ASSIGN-SUBSCRIPTION` — Assign subscription page

- [ ] `ASSIGN-01` Assign-subscription flow opens from member configuration with the correct member and branch context.
- [ ] `ASSIGN-02` Plans load with a real skeleton, active/inactive state, price, duration, and admission fee.
- [ ] `ASSIGN-03` Selecting a plan updates the summary and prevents selection of an inactive or incompatible plan.
- [ ] `ASSIGN-04` Submit validates member/plan/amount server-side, creates one assignment, and refreshes member/fees data.
- [ ] `ASSIGN-05` Double submit, timeout retry, stale member, and concurrent assignment are idempotent/conflict-safe.
- [ ] `ASSIGN-06` Unauthorized direct access or assignment for another branch/member is rejected.

### `LEAVE` — API leave flow (page coverage if enabled by navigation)

- [ ] `LEAVE-01` Member creates leave request with valid dates/reason and sees pending state.
- [ ] `LEAVE-02` Invalid range, overlap, empty reason, and cross-branch values are rejected.
- [ ] `LEAVE-03` Manager/admin lists only permitted requests and approves/rejects once.
- [ ] `LEAVE-04` Member cancels own pending request only; approved/rejected cancellation follows policy.
- [ ] `LEAVE-05` Notifications and badges update on create/approve/reject/cancel.

### `SETTINGS` — Settings page and shared settings navigation

- [ ] `SETTINGS-01` Settings shows only cards permitted by effective permissions.
- [ ] `SETTINGS-02` Workspace/management/operations cards do not render empty placeholders when unavailable.
- [ ] `SETTINGS-03` Every settings page uses the standard Dailio app bar, white background, compact tabs, margins, and reusable picker fields.
- [ ] `SETTINGS-04` Picker sheets are compact, searchable where needed, keyboard-safe, cancellable, and preserve selected values.
- [ ] `SETTINGS-05` Settings cache invalidates after organization/branch/role changes.
- [ ] `SETTINGS-06` Back, refresh, forbidden, no-context, and stale-data states work on every settings route.

---

## 9. Media, QR, cache, performance, and delivery

### `MEDIA`

- [ ] `MEDIA-01` Organization DP upload uses the established signature/upload/finalize flow.
- [ ] `MEDIA-02` Announcement/feed media preview is local before publish and uploads only on publish.
- [ ] `MEDIA-03` Cloud upload failure, cancellation, retry, invalid MIME, size limit, and corrupt image are handled.
- [ ] `MEDIA-04` Server response stores the usable protected media reference/URL, never a temporary local path.
- [ ] `MEDIA-05` List/detail/email/notification all resolve the same media correctly.
- [ ] `MEDIA-06` Private media cannot be read with another organization’s token or guessed storage key.

### `QR`

- [ ] `QR-01` Branch, plan, and gate QR generation is permanent by default.
- [ ] `QR-02` Repeated generation returns the same durable purpose/resource identity or explicitly documented stable identity.
- [ ] `QR-03` QR display includes Dailio branding/logo without reducing scan reliability.
- [ ] `QR-04` Camera and gallery scanning handle screen capture, printed QR, low light, rotation, and duplicate scan.
- [ ] `QR-05` QR purpose, branch, plan, and membership state are validated server-side.
- [ ] `QR-06` No QR silently expires/revokes unless an explicitly authorized administrative lifecycle action exists.

### `CACHE`

- [ ] `CACHE-01` First page open without cache shows loading and saves a valid JSON snapshot after success.
- [ ] `CACHE-02` Reopen with cache renders immediately, fetches in background, and atomically replaces valid data.
- [ ] `CACHE-03` Failed refresh retains last-known-good data with stale/offline indication.
- [ ] `CACHE-04` Cache keys include user, organization, branch, route/query/filter, and permission scope.
- [ ] `CACHE-05` Switching user, logout, account deletion, and clock-out cleanup clear only the required protected JSON data.
- [ ] `CACHE-06` Malformed, partial, old-schema, oversized, and permission-incompatible JSON is ignored/migrated safely.
- [ ] `CACHE-07` Optimistic reactions/comments do not get overwritten by an older background response.
- [ ] `CACHE-08` Sensitive media URLs/tokens/evidence are not persisted in an unsafe cache file.

### `PERF`

- [ ] `PERF-01` Cold app open, warm app open, login, shell, each tab, detail page, publish, and upload have measured timings.
- [ ] `PERF-02` No endpoint repeatedly waits for a 30-second timeout under normal local/staging load.
- [ ] `PERF-03` Prisma queries use tenant/branch indexes and bounded pagination; no N+1 query appears in list/detail traces.
- [ ] `PERF-04` Concurrent daily checks do not produce unique-constraint error noise or duplicate work.
- [ ] `PERF-05` Large announcement/feed media does not block UI or publish longer than the agreed budget.
- [ ] `PERF-06` API response/error logs contain status, method, path, duration, and request ID but no private payload/token/media data.

### `DELIVERY`

- [ ] `DELIVERY-01` In-app notification is created after committed business state, not before.
- [ ] `DELIVERY-02` FCM token registration, invalid token removal, foreground, background, terminated, and permission-denied paths work.
- [ ] `DELIVERY-03` Email delivery contains branded HTML, correct actor/content/media, and safe fallback text.
- [ ] `DELIVERY-04` Notification retries/deduplication prevent duplicate inbox, push, and email deliveries.
- [ ] `DELIVERY-05` First app open daily-check job runs at most once per job/business date across all users/devices.
- [ ] `DELIVERY-06` Daily job lease, failure, retry, and observability work on Vercel/serverless execution.
- [ ] `DELIVERY-07` Monthly attendance/subscription PDF report contains correct branch-local period, branding, totals, and owner recipient.
- [ ] `DELIVERY-08` Report generation failure does not mark the job successful and can be retried idempotently.

---

## 10. Cross-tenant, permission, and concurrency matrix

Run each relevant mutation/read with these actors:

| Case | Owner | Admin | Trainer | Member | Outsider |
|---|---:|---:|---:|---:|---:|
| Read own profile | Allow | Allow | Allow | Allow | Own only |
| Read all members | Allow | Permission-dependent | Deny/limited | Deny | Deny |
| Read own attendance/fees/payments | Allow | Allow | Allow if granted | Allow | Deny |
| Read all attendance/fees/payments | Permission-dependent | Permission-dependent | Permission-dependent | Deny | Deny |
| Create announcement/feed | Permission-dependent | Permission-dependent | Permission-dependent | Permission-dependent | Deny |
| React/comment accessible content | Allow | Allow | Allow | Allow | Deny |
| Manage roles/branch/plans | Owner/protected permission | Permission-dependent | Deny | Deny | Deny |
| Approve join request | Owner/admin permission | Permission-dependent | Deny | Deny | Deny |
| Clock own attendance | If assigned | If assigned | If assigned | If assigned | Deny |
| Correct another user’s attendance | Permission-dependent | Permission-dependent | Permission-dependent | Deny | Deny |

- [ ] `SEC-01` Repeat every read/mutation with an `ORG_B` identifier in the path and body; expect forbidden/not-found, never data.
- [ ] `SEC-02` Repeat every self endpoint with another member ID; expect server-side self-scope rejection.
- [ ] `SEC-03` Remove UI permission but call the API directly; expect forbidden.
- [ ] `SEC-04` Change organization/branch/role IDs in payloads; server derives/validates scope.
- [ ] `SEC-05` Replay the same idempotency key with identical and conflicting payloads.
- [ ] `SEC-06` Run concurrent approve, clock-in/out, subscription, payment, reaction, comment, delete, and job requests.
- [ ] `SEC-07` Verify audit records for permission, membership, attendance, subscription, payment, announcement/feed moderation, and job transitions.
- [ ] `SEC-08` Verify financial records and attendance evidence are append-only/corrected, not destructively overwritten.

---

## 11. Release regression checklist

- [ ] `REL-01` `flutter analyze` passes with no new errors.
- [ ] `REL-02` `flutter test` passes; changed widget/API contract tests are included.
- [ ] `REL-03` API type-check, lint, unit tests, build, Prisma generate, and migration status pass.
- [ ] `REL-04` Database migrations apply to a clean database and a database containing representative data.
- [ ] `REL-05` Android debug Google sign-in passes.
- [ ] `REL-06` Android release APK/AAB is signed with the intended certificate and Google sign-in passes.
- [ ] `REL-07` Shorebird release/patch uses an explicit Flutter version and a new version code.
- [ ] `REL-08` FCM foreground/background/terminated delivery passes on a physical device.
- [ ] `REL-09` Notification, announcement, feed, attendance, fee, payment, and cache smoke flows pass on two accounts.
- [ ] `REL-10` No secrets, tokens, client secrets, private URLs, or personal evidence appear in the release artifact or repository diff.
- [ ] `REL-11` Performance timings and API slow-query/error logs are reviewed before release.
- [ ] `REL-12` Evidence for all `[x]` cases is attached to the release/QA record.

## Existing automated coverage to extend

The repository already contains focused tests for attendance, subscriptions, payments, notifications, announcements/feed schemas, authorization, cache, QR scanning, roles, and selected widgets. Map every automated test to one or more IDs above and add missing API/widget/e2e coverage rather than treating file presence as proof of completion.

Minimum additions indicated by this catalogue:

- Announcement/feed composer, media preview/upload-on-publish, detail, reaction toggle, comment/reply, delete/cancel, and notification tests.
- Notification actor/media rendering, exact unread badge counts, FCM permission/token paths, and email media tests.
- Release-signed Google sign-in and certificate/client-ID configuration verification.
- Member directory/detail, join approval concurrency, roles/settings skeletons, plan/shift/payroll forms, and permission-aware UI tests.
- Cache isolation/invalidation tests for user/org/branch/filter combinations.
- Cross-tenant and concurrent integration tests for every retry-prone command.

## Execution record

| Run date | Build/commit | Environment | Tester | Passed | Failed | Blocked | Evidence |
|---|---|---|---|---:|---:|---:|---|
| 2026-09-29 | current `main` | Not executed as a full suite | Codex | 0 | 0 | 0 | This catalogue created |

Update this table after every full run and link the report, screenshots, logs, or test-run artifact. Do not mark a section complete based only on a successful build; the expected behavior for each case must be verified.
