# Dailio API Performance & Social Media Reliability Pass

## Objective

Make feed/announcement actions fast and reliable while preserving tenant isolation,
private media, notification delivery, and cache-first mobile behavior.

## Tracking

### P0 — user-visible failures

- [x] Deleted feed posts disappear from normal feed timelines.
- [x] Deleted announcements remain soft-deleted and are not exposed as active content.
- [x] Media placeholders do not expose local filenames or internal storage names.
- [x] Media delivery uses the stored Cloudinary format and a signed authenticated URL.
- [x] Announcement and feed media endpoints use lightweight scoped queries.
- [x] Feed and announcement list/detail responses include an authorized signed media URL,
  removing one API round trip per image; the media-url endpoint remains as a secure fallback.
- [x] Feed post notifications include related media metadata.
- [x] Announcement notifications include related media metadata.
- [x] Email notifications embed related images when the media can be fetched safely.

### P1 — latency and connection pressure

- [x] Daily job claiming is atomic and does not generate expected duplicate-key errors.
- [x] Maintenance scans remain sequential instead of saturating a small database pool.
- [x] Social post image selection is resized before upload.
- [x] New post publishing uploads selected media directly to Cloudinary using a server-issued
  signature, then sends only the scoped storage key in the post request.
- [x] Post/announcement media keys are validated against the current organization/branch before
  being persisted.
- [x] Notification fan-out creates all inbox rows before bounded push/email delivery, so a slow
  provider cannot delay later recipients.
- [x] JSON cache invalidation prevents an in-flight stale refresh from recreating a deleted post.
- [x] Added hot-path indexes for active members, active feed posts, and unread notifications.
- [ ] Capture production-like latency for organizations, unread count, feeds, media-url,
  and post publish after restarting the API.
- [ ] Add database query plans/index review from a real staging database.

### P2 — notification correctness

- [x] In-app notification rows are created by the central notification service.
- [x] Feed post events use the same notification path as announcements.
- [x] Notification media metadata supports both announcement and feed entities.
- [ ] Verify FCM device-token registration and Android foreground/background handling on a
  physical device.

## Technical direction

1. Business commands commit their own data first.
2. In-app notification creation is part of the central notification service.
3. Push/email delivery remains best-effort and is idempotent through delivery records.
4. Private media is stored as a scoped Cloudinary key; a signed URL is generated only after
   an authorized media ownership check. Permanent public URLs are not stored.
5. Normal feed queries return only active posts. Moderation access can inspect hidden posts
   through detail/moderation paths without polluting the member timeline.

## Manual verification checklist

- Restart `apps/api` so the new service code is loaded.
- Publish a small image post in Announcement and Feed; confirm it appears without a filename
  placeholder.
- Delete each post as its creator; confirm it disappears after returning to the timeline and
  after a full refresh.
- Open the recipient account and confirm the in-app notification appears with actor and image.
- Confirm Gmail contains the image inline, not only an empty attachment.
- Compare request durations for `/organizations`, `/notifications/unread-count`, feed posts,
  and media-url in the Dailio HTTP logs.

## Remaining production gate

The code checks are necessary but cannot prove database/network latency from this workspace.
The remaining unchecked items require the running API, real PostgreSQL data, Cloudinary, SMTP,
and a registered FCM device token.

The additive migration `20260929195000_performance_indexes` has been applied to the configured
local Neon database. A production deploy must apply the same migration through the normal release
pipeline before serving the new build.

## API-wide latency pass (2026-09-29)

### Completed implementation tasks

- [x] Reduced authentication lookup to `User.id` and active status only. Profile and
  sensitive user fields are no longer transferred on every authenticated request.
- [x] Reduced tenant bootstrap payloads to the branch identity/status/timezone/week-start
  and organization identity/status needed by the request pipeline.
- [x] Reduced tenant membership/role loading to permission-bearing fields only while
  preserving effective-role ordering and expiry checks.
- [x] Reworked fee listing so it no longer loads complete ledger, allocation, payment
  attempt, evidence, receipt, and user graphs for every member. Ledger totals and confirmed
  payment totals are aggregated in PostgreSQL; requests and member data use narrow selects.
- [x] Narrowed payment-request list payloads and member-directory payloads to fields required
  by the clients. FCM tokens, Google IDs, emergency contacts, and other private user fields
  are no longer returned by list endpoints.
- [x] Added scoped indexes for member fee filtering, subscription lookup, ledger aggregation,
  payment-request lookup, and member-directory ordering.
- [x] Bounded request-body log sanitization by depth, array length, and object-field count so
  large editor/media payloads cannot make diagnostic logging a latency hotspot.
- [x] Applied migration `20260929210000_fee_query_indexes` to the configured Neon database.

### Verification completed in this pass

- [x] Prisma schema validation passed.
- [x] Prisma migration status is up to date.
- [x] API type-check passed.
- [x] API lint passed.
- [x] API regression suite passed: 37 files / 124 tests.
- [x] Targeted HTTP-log, tenant, payment, and member tests passed: 10 tests.
- [x] Existing migration `20260929195000_performance_indexes` remains applied.
- [x] Executed a read-only Neon smoke query against the new PostgreSQL fee aggregate;
  the query completed successfully and returned the expected grouped shape.

### Required release measurement

- [ ] Restart the running API process after pulling the changes.
- [ ] Capture authenticated timings for organizations, unread count, attendance, fees,
  members, feed posts, media-url, and post publish from a physical device.
- [ ] Compare cold-start and warm-request timings separately. Neon connection establishment
  can dominate the first request and must not be confused with query latency.
- [ ] If pool timeouts remain, use the Neon pooled connection string and set
  `DATABASE_CONNECTION_LIMIT`/`DATABASE_POOL_TIMEOUT` for the deployed instance according
  to the database plan; increasing the client timeout alone does not fix pool starvation.

### Operational note

The API process currently serving port 3000 must be restarted so the new middleware and fee
query code are guaranteed to be loaded. The Android `proc/fas/render` AVC lines are device
vendor warnings and are unrelated to API latency.
