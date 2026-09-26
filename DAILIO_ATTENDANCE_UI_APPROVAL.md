# Dailio Attendance UI Approval Tracker

This tracker records screen-by-screen approval for the strict WhatsApp-like Dailio UI direction.

Approval is a product decision, not just a code review. A screen becomes **100% satisfied / DONE** only after Harsh explicitly approves its visual hierarchy, spacing, information density, tile content, overflow actions, empty/loading/error states, and interaction flow on the target device.

## Global approval rules

- Dailio name and canonical logo remain unchanged.
- Space Grotesk remains unchanged.
- Existing bottom navigation remains unchanged.
- Primary redesigned palette is logo orange, white, black, and logo-neutral gray.
- App bars use text-only `Dailio` branding with an overflow/ellipsis action where the screen has secondary actions.
- List screens use compact WhatsApp-like rows/tiles:
  - avatar/DP on the left;
  - status badge at the avatar's bottom-right;
  - title/name above;
  - one recent/current status line below;
  - overflow menu on the right.
- Detail screens expose complete information in clean sections without dashboard clutter.
- Server-confirmed state, pending state, errors, and offline state must remain visually distinct.
- Permissions, branch scope, sensitive evidence protection, and existing API behavior must not change.

## Status legend

- `NOT STARTED` — no implementation review yet.
- `IN PROGRESS` — being redesigned or iterated.
- `READY FOR APPROVAL` — implementation and checks complete; waiting for Harsh's visual approval.
- `ITERATION REQUESTED` — feedback received; changes required.
- `100% SATISFIED / DONE` — explicitly approved and locked.

## Attendance screen tracker

| ID | Screen / surface | Order | Current status | Approval notes |
| --- | --- | ---: | --- | --- |
| ATT-01 | Attendance overview/list | 1 | READY FOR APPROVAL | Dailio text app bar, overflow menu, Today/Yesterday/This Week/This Month tabs, actual role chips, compact DP/status tiles, recent clock event, tile overflow. |
| ATT-02 | Self Attendance — Today | 2 | READY FOR APPROVAL | Live clock, effective policy, current session, server submission state, Clock in/Clock out, gate QR action. |
| ATT-03 | Self Attendance — Attendance record | 3 | READY FOR APPROVAL | Period filters, compact self-history tiles, avatar/status badge, recent clock event, tile overflow. |
| ATT-04 | Gate Attendance | 4 | READY FOR APPROVAL | Branch/action identity, policy requirements, live-scan safety message, confirmation action, overflow cancel action. |
| ATT-05 | Attendance Detail | 5 | READY FOR APPROVAL | Clean summary, timeline, evidence sections, protected selfie viewing, overflow refresh action. |
| ATT-06 | Attendance Policy management | 6 | READY FOR APPROVAL | Owner/admin-only policy configuration, Dailio text app bar, save and overflow refresh actions, scope/assignment sections. |
| ATT-07 | Manual attendance sheet | 7 | READY FOR APPROVAL | Authorized staff-only bottom sheet for member, time, reason, timezone, and server-confirmed submission. |
| ATT-08 | Attendance correction sheet | 8 | READY FOR APPROVAL | Authorized correction flow with original/new values, mandatory reason, and preserved audit/evidence behavior. |
| ATT-09 | Shared QR Scanner — attendance entry | 9 | ITERATION REQUESTED | Shared by join, plan purchase, and gate attendance; attendance-specific scanner review must not break join/gallery behavior. |

## Per-screen approval checklist

For each ID, confirm all items before marking `100% SATISFIED / DONE`:

- [ ] App bar title/branding matches the Dailio text-only pattern.
- [ ] Overflow/ellipsis action contains only useful actions for that screen.
- [ ] Primary and secondary tab order is correct.
- [ ] Avatar/DP is present wherever a person record is shown.
- [ ] Status badge is attached to the avatar and has a text/icon equivalent.
- [ ] Name/title appears above the recent/current status line.
- [ ] Clocked-in/clocked-out wording and time are correct.
- [ ] Status hierarchy is readable without relying on color alone.
- [ ] Tile density feels like WhatsApp: simple, scannable, and low-noise.
- [ ] Detail route opens from the tile and contains the complete record.
- [ ] Loading state is clean.
- [ ] Empty state is useful.
- [ ] Error/forbidden/offline states are safe and actionable.
- [ ] Permission and branch scoping are preserved.
- [ ] Existing attendance API behavior and server confirmation are preserved.
- [ ] Physical-device visual review completed.
- [ ] Harsh explicitly approved the screen.

## Approval log

| Date | Screen ID | Decision | Feedback / follow-up | Implemented commit |
| --- | --- | --- | --- | --- |
| 2026-09-27 | ATT-01 | Iteration delivered | Removed the stat card and inline activity row; added the global bottom-shell toast, flat roster rows, role badge, and reusable minimal overflow menu. Waiting for physical-device visual approval. | Local worktree |
| 2026-09-27 | — | Attendance module pass submitted for review | Waiting for screen-by-screen approval and iteration feedback. | Local worktree |

## Review sequence

Review in this order so visual decisions stay consistent:

1. ATT-01 Attendance overview/list.
2. ATT-02 Self Attendance — Today.
3. ATT-03 Self Attendance — Attendance record.
4. ATT-04 Gate Attendance.
5. ATT-05 Attendance Detail.
6. ATT-06 Attendance Policy management.
7. ATT-07 and ATT-08 bottom sheets.
8. ATT-09 shared QR Scanner attendance entry.

After each approval, update that row from `READY FOR APPROVAL` to `100% SATISFIED / DONE`, add the approval date and feedback to the Approval log, and do not alter the approved screen without recording a new iteration.
