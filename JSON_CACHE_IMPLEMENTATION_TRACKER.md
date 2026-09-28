# Dailio JSON Cache: Implementation and Verification Tracker

## Objective

Dailio should render the last server-confirmed read data from private JSON files
as soon as a page is opened. A background GET then refreshes the same resource;
the fresh response replaces the file and updates the page without forcing the
user through a full loading state on every visit.

The cache is a performance layer only. It is never an authorization source,
payment confirmation source, attendance truth source, or replacement for API
validation.

## Product and security contract

- [x] Domain cache uses JSON files only. No Hive, SQLite, Isar, or key-value
  domain cache was added.
- [x] Files are private under the app's application documents directory.
- [x] Keys include the signed-in user and resource context. Organization,
  branch, endpoint, query, period, status, and filter values are included where
  the repository has them.
- [x] Every file has `version`, `saved_at`, `scope`, and `payload` metadata.
- [x] Only successful GET responses are persisted.
- [x] Writes use a temporary file and replacement; malformed files are ignored
  rather than allowed to break the app.
- [x] A cached response never bypasses API authentication or authorization.
- [x] Access/refresh tokens, upload signatures, private evidence URLs, selfies,
  precise location evidence, and payment secrets are not cached.
- [x] Attendance payload caching strips evidence and upload-secret fields.
- [x] Sign-out and account deletion clear the complete cache and reset the user
  namespace.
- [x] A confirmed manual clock-out clears the complete cache. A QR punch that
  returns a closed session does the same.
- [ ] Add an explicit visual stale/offline marker to every cached page. Current
  pages retain their existing error/offline handling while fresh replacement is
  silent.

## Track A: JSON storage foundation

- [x] Add `JsonCacheStore` in `apps/mobile/lib/core/storage`.
- [x] Resolve the cache directory lazily and create it on demand.
- [x] Add JSON envelope parsing and schema-version rejection.
- [x] Add temporary-file writes and tolerant read recovery.
- [x] Add user-scoped keys and resource scopes.
- [x] Add `clearKey`, `clearScope`, and `clearAll`.
- [x] De-duplicate simultaneous background refreshes per key.
- [x] Make cache failures non-fatal to server-confirmed requests.
- [ ] Add production diagnostics for cache hit/miss/refresh timing without
  logging payloads or personal data.

## Track B: Repository stale-while-revalidate behavior

- [x] Add one shared cached-first/background-refresh loader.
- [x] Cache organization discovery, organization detail, roles, branches, and
  plans.
- [x] Cache branch discovery results for onboarding and context selection.
- [x] Cache member directory, member detail, and join requests.
- [x] Cache shifts and payroll structures.
- [x] Cache fees, payment-request lists, payment-request details, subscriptions,
  and safe payment metadata through the fees repository.
- [x] Cache attendance policy, active session, list pages, and session details.
- [x] Cache attendance policy collections.
- [x] Keep evidence downloads, receipt retrieval, upload signatures, and cloud
  media operations network-only.
- [x] Invalidate branch read models after member, admission, fee/payment,
  attendance, shift, and payroll mutations.
- [x] Invalidate organization/user read models after organization, branch, role,
  and plan mutations where the affected scope is known.
- [x] Use a safe full-cache invalidation for role updates whose organization and
  branch scope cannot be known from the request before the response.
- [ ] Add repository-level contract tests for every cached endpoint and every
  mutation invalidation path.

## Track C: Page integration

The repositories now return cached data before waiting for refresh and expose an
`onFresh` callback on the primary list/detail methods. The checked items below
mean the page is wired to that behavior; unchecked items still need callback or
stale-state completion.

- [x] Attendance list receives fresh list replacement.
- [x] Self attendance receives fresh policy, active-session, and history data.
- [x] Attendance detail receives fresh detail replacement.
- [x] Fees list receives fresh fee-card replacement.
- [x] Payments list receives fresh payment-request replacement.
- [x] Members directory receives fresh filtered-list replacement.
- [x] Member detail receives fresh profile/subscription replacement.
- [x] Join requests receives fresh pending-request replacement.
- [x] Roles page receives fresh role replacement.
- [x] Branch management receives fresh branch replacement.
- [x] Plans and buy-plan pages receive fresh plan replacement.
- [x] Shift management receives fresh shift replacement.
- [x] Payroll management receives fresh salary-structure replacement.
- [ ] Configure-member page updates each independently refreshed dependency;
  it currently benefits from cached-first repository loading and applies the
  complete result after its initial load.
- [ ] Attendance policy management exposes fresh callbacks for every secondary
  role/member collection and its stale/offline visual state.
- [ ] Profile, announcements, notifications, and other read-only surfaces need
  a dedicated cache contract. Authentication `/auth/me` remains network
  authoritative and is intentionally not replaced with cached identity data.
- [ ] Add a shared stale/offline indicator to pages rather than silently
  treating old cached data as current.

## Track D: Lifecycle, privacy, and invalidation

- [x] Cache is set to the authenticated user after Google sign-in and `/auth/me`.
- [x] Cache is cleared before the next account can use the local store on
  sign-out/account deletion.
- [x] Clock-in remains server-authoritative and does not clear useful cache.
- [x] Confirmed clock-out clears all JSON files after the API response succeeds.
- [x] QR attendance clears all JSON files only when the server returns a closed
  session, so a QR clock-in does not destroy the cache.
- [x] Attendance cache sanitization excludes sensitive evidence and upload data.
- [x] Payment receipt/evidence URL retrieval remains uncached.
- [ ] Add explicit cache cleanup/size limits for long-lived accounts.
- [ ] Add an upgrade migration strategy if `currentVersion` changes.

## Track E: Automated verification

- [x] Add cache-store tests for cached-first behavior and background replacement.
- [x] Add cache-store tests for user-key isolation and full cleanup.
- [x] Existing mobile widget/unit tests pass after repository signature changes.
- [x] `flutter analyze` passes.
- [x] `flutter test` passes.
- [ ] Add repository tests for all endpoint decoders and mutation invalidation.
- [ ] Add offline/stale UI tests for each primary page family.
- [ ] Verify on a physical Android device: first visit, cached revisit, fresh
  replacement, offline revisit, logout, account switch, and process death.
- [ ] Verify two organizations and two branches cannot read each other's cache.
- [ ] Verify clock-out after process death rebuilds the next page from server
  data.
- [ ] Verify release-build cache directory growth and upgrade behavior.

## Page-by-page contract

| Module | Resource | JSON scope/key | Current status |
|---|---|---|---|
| Context | Organization discovery | user + query | Implemented |
| Context | Organization/branch context | user/org/branch | Implemented for repository reads; visual stale marker pending |
| Admission | Join requests | branch | Implemented |
| Members | Directory | branch/org + filters | Implemented |
| Members | Member detail | branch/member | Implemented |
| Members | Configure member | member + supporting lists | Cached-first implemented; independent live replacement pending |
| Attendance | Attendance list | branch + period/role/cursor | Implemented |
| Attendance | Self attendance | branch + active/history/policy | Implemented |
| Attendance | Attendance detail | branch/session | Implemented with sensitive fields removed from cache |
| Fees | Fees list | branch + period/status/date | Implemented |
| Fees | Buy plan/plans | org/branch | Implemented |
| Fees | Subscription detail | branch/subscription | Implemented through safe fees read model |
| Payments | Payment list | branch + period/status | Implemented |
| Payments | Payment detail | branch/payment request | Implemented through cached read model |
| Payments | Official receipt/evidence URL | network-only | Intentionally not cached |
| Settings | Roles/branches/plans | organization/branch | Implemented |
| Operations | Shifts/payroll | organization/branch | Implemented |
| Settings | Attendance policy | branch + policy collections | Repository implemented; page secondary refresh completion pending |
| Profile | Authenticated profile | user | Network-authoritative; dedicated profile cache pending |

## Runtime sequence

1. The authenticated user and active organization/branch context are established
   from secure/authenticated state, never from JSON cache.
2. A page asks its repository for a scoped resource.
3. If a valid JSON record exists, it is decoded and rendered immediately.
4. One background GET starts for that resource.
5. A successful response is validated, sanitized where necessary, written to a
   temporary JSON file, and replaces the old record.
6. The page receives the fresh value through `onFresh` and updates in place.
7. If refresh fails, the cached view remains available and the page's existing
   error/offline state can be shown without deleting good last-known data.
8. If no record exists, the page uses its normal first-visit loading state.
9. After server-confirmed clock-out, all JSON cache files are deleted. The next
   page visit repopulates data progressively from the API.

## Definition of done

- [x] JSON-only cached-first behavior exists in the mobile data layer.
- [x] Primary attendance, fee, payment, member, admission, settings, shift, and
  payroll surfaces use the cache.
- [x] Fresh background data replaces cached data on the primary surfaces.
- [x] Auth, tenant scope, sensitive data, and server truth remain protected.
- [x] Automated analyzer and Flutter test suite pass.
- [ ] Remaining page callback/stale-state work is complete.
- [ ] Physical-device, offline, process-death, release, and two-tenant checks are
  complete.
