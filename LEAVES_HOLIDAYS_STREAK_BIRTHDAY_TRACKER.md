# Leaves, Holidays, Streaks & Birthday Announcements

This tracker is the implementation record for the four requested features. Status: `[ ]` pending, `[~]` in progress, `[x]` complete, `[!]` blocked.

## Product decisions

- All records are scoped by organization and branch. Server authorization remains authoritative.
- Facing Issue is a universal settings shortcut to WhatsApp; no issue record is stored in Dailio.
- Holidays use explicit local `dates` (`YYYY-MM-DD`) so non-contiguous dates are supported. Optional `recurring_weekdays` uses ISO weekday numbers (1 Monday through 7 Sunday); `is_recurring` still controls annual repetition of explicit dates. Legacy `date`/`end_date` columns are retained only as a compatibility bridge.
- Leaves remain an empty UI state in this phase; existing leave-request APIs remain available for the next phase.
- A streak counts attendance days with at least one completed or open session. Configured holidays are skipped when calculating continuity; attendance on a holiday still counts as a normal attendance day.
- Birthday announcements are branch-scoped, generated once per member and local calendar date, and published through the normal announcement service.
- The daily coordinator is still app-open driven and uses the existing database lease/idempotency mechanism.

## Phase 0 — foundation

- [x] Read product context and confirm tenant, permission, timezone, audit and idempotency constraints.
- [x] Add the tracker and keep it updated in the same changeset as implementation.
- [x] Add focused API/mobile tests and run format, type-check, analyze and test commands.

## Phase 1 — Facing Issue

- [x] Add the universal settings tile with the standard module-card component.
- [x] Build a safe WhatsApp deep link with the prefilled issue message and fallback handling.
- [x] Verify the tile is visible to every signed-in user and does not expose private data.

## Phase 2 — Leaves & Holidays

- [x] Add explicit multi-date and recurring-weekday persistence with a backward-compatible migration.
- [x] Add scoped holiday list/create/update/delete API with permission checks, validation, audit and idempotency.
- [x] Add shared mobile repository, cache-backed list state, loading/empty/error states and routes.
- [x] Add Leaves & Holidays settings tile in the requested order.
- [x] Add centered Leaves/Holidays tabs and empty Leaves state.
- [x] Add compact holiday list tiles, create/edit form, template picker and delete confirmation.
- [x] Add all 49 supplied 2026 templates.
- [x] Add multiple-date selection/removal and recurring weekday chips to the create/edit form.
- [x] Expand configured weekday holidays in streak calculations using branch-local calendar dates.

## Phase 6 — ordering consistency

- [x] Order attendance records with open clock-ins before completed clock-outs, with newest clock-in first within each group.
- [x] Order the fee directory as expiring soon, expired, then ongoing/other statuses, with stable member-name tie breaking.
- [x] Add focused contract, streak, and fee ordering tests.

### Supplied templates

| # | Holiday | Dates |
|---:|---|---|
| 1 | New Year's Day | 2026-01-01 |
| 2 | Makar Sankranti | 2026-01-14 |
| 3 | Vasant Panchami | 2026-01-23 |
| 4 | Karpoori Thakur Jayanti | 2026-01-24 |
| 5 | Republic Day | 2026-01-26 |
| 6 | Sant Ravidas Jayanti | 2026-02-01 |
| 7 | Shab-e-Barat | 2026-02-04 |
| 8 | Mahashivratri | 2026-02-15 |
| 9 | Holika Dahan | 2026-03-02 |
| 10 | Holi | 2026-03-03 to 2026-03-04 |
| 11 | Last Friday of Ramzan | 2026-03-13 |
| 12 | Eid-ul-Fitr | 2026-03-21 to 2026-03-22 |
| 13 | Bihar Day | 2026-03-22 |
| 14 | Samrat Ashok Ashtami | 2026-03-26 |
| 15 | Ram Navami | 2026-03-27 |
| 16 | Mahavir Jayanti | 2026-03-31 |
| 17 | Good Friday | 2026-04-03 |
| 18 | Dr. B. R. Ambedkar Jayanti | 2026-04-14 |
| 19 | Veer Kunwar Singh Jayanti | 2026-04-23 |
| 20 | Janaki Navami | 2026-04-25 |
| 21 | May Day / Labour Day | 2026-05-01 |
| 22 | Buddha Purnima | 2026-05-01 |
| 23 | Eid-ul-Zuha / Bakrid | 2026-05-28 to 2026-05-29 |
| 24 | Anugrah Narayan Singh Jayanti | 2026-06-18 |
| 25 | Muharram | 2026-06-26 to 2026-06-27 |
| 26 | Kabir Jayanti | 2026-06-29 |
| 27 | Chehallum | 2026-08-04 |
| 28 | Independence Day | 2026-08-15 |
| 29 | Last Shravan Monday | 2026-08-24 |
| 30 | Milad-un-Nabi / Prophet Muhammad's Birthday | 2026-08-26 |
| 31 | Raksha Bandhan | 2026-08-28 |
| 32 | Shri Krishna Janmashtami | 2026-09-04 |
| 33 | Hartalika Teej | 2026-09-14 |
| 34 | Vishwakarma Puja | 2026-09-17 |
| 35 | Anant Chaturdashi | 2026-09-25 |
| 36 | Mahatma Gandhi Jayanti | 2026-10-02 |
| 37 | Jivitputrika Vrat | 2026-10-04 |
| 38 | Durga Puja Kalash Sthapana | 2026-10-11 |
| 39 | Jayaprakash Narayan Jayanti | 2026-10-11 |
| 40 | Durga Puja | 2026-10-17 to 2026-10-20 |
| 41 | Durga Puja Ekadashi | 2026-10-21 |
| 42 | Shri Krishna Singh Jayanti | 2026-10-21 |
| 43 | Diwali | 2026-11-08 |
| 44 | Chitragupt Puja / Bhai Dooj | 2026-11-10 |
| 45 | Chhath Puja – Kharna | 2026-11-14 |
| 46 | Chhath Puja | 2026-11-15 to 2026-11-16 |
| 47 | Dr. Rajendra Prasad Jayanti | 2026-12-03 |
| 48 | Christmas Eve | 2026-12-24 |
| 49 | Christmas Day | 2026-12-25 |

## Phase 3 — attendance streaks

- [x] Add durable per-member streak snapshot and unique branch/member constraint.
- [x] Calculate streaks in the branch timezone with holiday gaps ignored.
- [x] Add a leased daily streak job to the app-open coordinator.
- [x] Add scoped read API for the current member and authorized member detail views.
- [x] Add compact streak card to settings, the DP profile surface and member detail.
- [x] Use the supplied fire asset with a resilient image fallback.

## Phase 4 — birthday announcements

- [x] Add a leased daily birthday job to the existing coordinator.
- [x] Find active branch members whose local birthday is today.
- [x] Create one published announcement per branch/member/date with a deterministic dedupe marker.
- [x] Use the normal announcement recipient, audit and notification path.
- [x] Add job/idempotency tests.

## Phase 5 — verification and handoff

- [x] Add API unit/integration tests for tenant scope, permissions, duplicate retries and date boundaries.
- [x] Run the existing mobile widget/state test suite after the shared route and repository wiring.
- [x] Run API build/type-check/tests and mobile format/analyze/tests.
- [x] Update this tracker with final verification and any environment/migration steps.

## Current implementation log

- 2026-09-30: tracker created; repository and existing leave/daily-job/announcement patterns inspected.
- 2026-09-30: holiday CRUD, templates, settings entry point, streak snapshot/API/card, leased jobs and birthday announcement automation implemented.
- 2026-09-30: migration `20260930100000_holidays_and_attendance_streaks` deployed to the configured `dailio_test` database. API: 38 files / 130 tests passed, lint/type-check/build passed. Mobile: analyze clean and 25 tests passed.
- 2026-09-30: added migration `20260930130000_holiday_date_lists` for explicit date arrays and recurring weekdays; existing ranges are backfilled without dropping legacy columns. Attendance and fee list ordering now follow the operational priority requested.
- 2026-09-30: verified migration status is up to date; API full suite passed (40 files / 138 tests), lint, type-check and production build passed; mobile analyze and full Flutter suite passed (25 tests).
