# Dailio Attendance Security and Privacy Review

Review type: internal engineering pre-release audit  
Date: 2026-09-26  
Scope: attendance policies, manual punches, permanent gate QR, evidence, reporting, corrections, retention, and request logging.

This document records implementation evidence for handoff to an independent
security/privacy reviewer. It is not a substitute for that independent review.

## Controls reviewed

| Control                            | Result                     | Evidence                                                                                                                                                   |
| ---------------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Organization and branch isolation  | Pass                       | Attendance reads and commands scope organization + branch; cross-branch and cross-tenant guarded PostgreSQL checks pass.                                   |
| Branch timezone integrity           | Pass                       | Organization/branch settings validate IANA identifiers; server query boundaries use branch time; mobile attendance displays and manager-entered corrections convert branch wall time to UTC before submission. |
| Self/team/branch/all authorization | Pass                       | `getAttendanceScopeMemberIds`, detail lookup, evidence download, export, policy-target validation, policy listing/update, and correction services enforce effective permissions and reporting scope. |
| Manual attendance records          | Pass                       | Manager creation requires `ATTENDANCE_CREATE_ALL`, an active target member, an effective policy allowance, valid ordered timestamps, a mandatory reason, scoped idempotency, one-open-session protection, and an audit event; unsupported offline capture is rejected. |
| Permanent QR handling              | Pass                       | Raw tokens are hashed at rest, QR endpoints are rate-limited, revocation is checked, action is server-derived, and replay is idempotent.                   |
| QR token logging                   | Pass                       | `redactSensitiveRequestUrl` removes bearer token path segments from Morgan access logs.                                                                    |
| Attendance evidence privacy        | Pass                       | Coordinates, device metadata, and IP address are removed from ordinary evidence responses; selfie downloads are authorized, private, and time-limited.     |
| Selfie storage ownership           | Pass                       | Upload signatures and server validation bind the storage key to the authenticated actor, organization, branch, and a 10-minute expiry; branch prefixes remain enforced. |
| Evidence retention                 | Pass with operational gate | Asset deletion occurs before sensitive-field purge; deletion failure preserves the reference for retry. A guarded staging run against configured Cloudinary deleted the private object and purged the database fields; production scheduling/monitoring still requires sign-off. |
| Idempotency and concurrency        | Pass                       | Unique idempotency fields, one-open-session partial index, serializable transitions, and guarded concurrent punch checks are present.                      |
| Append-only corrections            | Pass                       | Correction versions preserve original values/evidence and record actor, reason, before/after state, and audit events.                                      |
| Sensitive data in errors           | Pass                       | User-facing errors are structured and do not return raw database details; validation logs contain field names/details only.                                |
| Unknown exception logging          | Pass                       | Generic API failures log only safe type/code metadata and request ID; raw messages/stacks are excluded from logs and member notifications.                 |

## Open release gates

- Independent security/privacy review of deployment, logs, Cloudinary configuration,
  permissions, retention operations, and monitoring.
- Physical Android/iOS verification of camera, gallery, selfie, location, and
  permission-denial behavior.
- Production retention scheduling, monitoring, and recovery-runbook sign-off.
- Product-owner release sign-off.

The master tracker remains intentionally below 100% until these gates have
independent evidence.
