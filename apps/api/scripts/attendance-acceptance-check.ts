/* eslint-disable no-console */
import { ulid } from 'ulid';

import { prisma } from '../src/lib/prisma';
import {
  clockIn,
  clockOut,
  createManualSession,
  createAttendanceSelfieUploadSignature,
  exportSessions,
  getEffectivePolicyForMember,
  getSessionDetail,
  listSessions,
  reviewOpenAttendanceSessions,
  updatePolicy,
} from '../src/modules/attendance/attendance.service';
import {
  createBranchInvite,
  punchAttendanceFromInvite,
  resolveInvite,
} from '../src/modules/invites/invites.service';
import type { ListSessionsQuery } from '../src/modules/attendance/attendance.schema';

if (process.env.RUN_ATTENDANCE_ACCEPTANCE_CHECK !== 'true') {
  throw new Error(
    'Refusing to run. Set RUN_ATTENDANCE_ACCEPTANCE_CHECK=true against a disposable staging database.',
  );
}

const ids = {
  organization: `att_accept_org_${ulid()}`,
  branch: `att_accept_branch_${ulid()}`,
  foreignOrganization: `att_accept_foreign_org_${ulid()}`,
  foreignBranch: `att_accept_foreign_branch_${ulid()}`,
  ownerUser: `att_accept_owner_${ulid()}`,
  subjectUser: `att_accept_subject_${ulid()}`,
  managerUser: `att_accept_manager_${ulid()}`,
  childUser: `att_accept_child_${ulid()}`,
  unrelatedUser: `att_accept_unrelated_${ulid()}`,
  pendingUser: `att_accept_pending_${ulid()}`,
  inactiveUser: `att_accept_inactive_${ulid()}`,
  foreignUser: `att_accept_foreign_user_${ulid()}`,
  ownerMember: `att_accept_owner_member_${ulid()}`,
  subjectMember: `att_accept_subject_member_${ulid()}`,
  managerMember: `att_accept_manager_member_${ulid()}`,
  childMember: `att_accept_child_member_${ulid()}`,
  unrelatedMember: `att_accept_unrelated_member_${ulid()}`,
  inactiveMember: `att_accept_inactive_member_${ulid()}`,
  foreignMember: `att_accept_foreign_member_${ulid()}`,
  priorityRole: `att_accept_priority_role_${ulid()}`,
  secondaryRole: `att_accept_secondary_role_${ulid()}`,
  priorityAssignment: `att_accept_priority_assignment_${ulid()}`,
  secondaryAssignment: `att_accept_secondary_assignment_${ulid()}`,
  pendingRequest: `att_accept_pending_request_${ulid()}`,
  oldSession: `att_accept_old_session_${ulid()}`,
};

const policyManagementPermissions = new Set(['ATTENDANCE_POLICY_MANAGE']);

const organizationIds = [ids.organization, ids.foreignOrganization];
const branchIds = [ids.branch, ids.foreignBranch];
const userIds = [
  ids.ownerUser,
  ids.subjectUser,
  ids.managerUser,
  ids.childUser,
  ids.unrelatedUser,
  ids.pendingUser,
  ids.inactiveUser,
  ids.foreignUser,
];

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

async function expectRejected(action: () => Promise<unknown>, label: string) {
  try {
    await action();
  } catch {
    return;
  }
  throw new Error(`${label} unexpectedly succeeded`);
}

async function waitForNotification(dedupeKey: string) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const notification = await prisma.notification.findUnique({ where: { dedupe_key: dedupeKey } });
    if (notification) return notification;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return null;
}

async function cleanup() {
  // Attendance failure notifications are intentionally fire-and-forget in the
  // production path. Give the staging verifier's cleanup a short window to
  // observe those auxiliary writes before removing the users they reference.
  await new Promise((resolve) => setTimeout(resolve, 300));
  await prisma.notification.deleteMany({
    where: {
      OR: [{ organization_id: { in: organizationIds } }, { user_id: { in: userIds } }],
    },
  });
  await prisma.inviteToken.deleteMany({ where: { organization_id: { in: organizationIds } } });
  await prisma.auditLog.deleteMany({ where: { organization_id: { in: organizationIds } } });
  await prisma.mediaAsset.deleteMany({ where: { organization_id: { in: organizationIds } } });
  await prisma.attendanceEvidence.deleteMany({
    where: { organization_id: { in: organizationIds } },
  });
  await prisma.attendanceCorrection.deleteMany({
    where: { organization_id: { in: organizationIds } },
  });
  await prisma.attendanceSession.deleteMany({
    where: { organization_id: { in: organizationIds } },
  });
  await prisma.attendancePolicy.deleteMany({
    where: { organization_id: { in: organizationIds } },
  });
  await prisma.joinRequest.deleteMany({ where: { organization_id: { in: organizationIds } } });
  await prisma.memberRoleAssignment.deleteMany({
    where: { organization_id: { in: organizationIds } },
  });
  await prisma.role.deleteMany({ where: { organization_id: { in: organizationIds } } });
  await prisma.member.deleteMany({ where: { organization_id: { in: organizationIds } } });
  await prisma.branch.deleteMany({ where: { id: { in: branchIds } } });
  await prisma.organization.deleteMany({ where: { id: { in: organizationIds } } });
  await prisma.user.deleteMany({ where: { id: { in: userIds } } });
}

async function createUser(id: string, name: string) {
  return prisma.user.create({
    data: {
      id,
      name,
      email: `${ulid().toLowerCase()}@invalid.test`,
      status: 'ACTIVE',
    },
  });
}

async function createSession(
  userId: string,
  keyPrefix: string,
  evidence: {
    latitude?: number;
    longitude?: number;
    accuracy?: number;
    selfie_storage_key?: string;
    selfie_upload_token?: string;
  } = {},
) {
  const { latitude, longitude, accuracy } = evidence;
  const opened = await clockIn(userId, ids.organization, ids.branch, {
    idempotency_key: `${keyPrefix}-in-${ulid()}`,
    timezone: 'UTC',
    ...evidence,
  });
  return clockOut(
    userId,
    ids.organization,
    ids.branch,
    {
      session_id: opened.id,
      idempotency_key: `${keyPrefix}-out-${ulid()}`,
      timezone: 'UTC',
      selfie_upload_token: evidence.selfie_upload_token,
      latitude,
      longitude,
      accuracy,
    },
    new Set(),
  );
}

async function main() {
  await prisma.organization.create({
    data: {
      id: ids.organization,
      name: `Attendance acceptance ${ulid()}`,
      slug: `attendance-acceptance-${ulid().toLowerCase()}`,
      type: 'GYM',
      status: 'ACTIVE',
      timezone: 'UTC',
      currency: 'INR',
    },
  });
  await prisma.branch.create({
    data: {
      id: ids.branch,
      organization_id: ids.organization,
      name: 'Acceptance Branch',
      timezone: 'UTC',
      status: 'ACTIVE',
      latitude: 0,
      longitude: 0,
    },
  });
  await prisma.organization.create({
    data: {
      id: ids.foreignOrganization,
      name: `Foreign attendance acceptance ${ulid()}`,
      slug: `foreign-attendance-acceptance-${ulid().toLowerCase()}`,
      type: 'GYM',
      status: 'ACTIVE',
      timezone: 'UTC',
      currency: 'INR',
    },
  });
  await prisma.branch.create({
    data: {
      id: ids.foreignBranch,
      organization_id: ids.foreignOrganization,
      name: 'Foreign Acceptance Branch',
      timezone: 'UTC',
      status: 'ACTIVE',
    },
  });

  await Promise.all([
    createUser(ids.ownerUser, 'Acceptance Owner'),
    createUser(ids.subjectUser, 'Acceptance Subject'),
    createUser(ids.managerUser, 'Acceptance Manager'),
    createUser(ids.childUser, 'Acceptance Child'),
    createUser(ids.unrelatedUser, 'Acceptance Unrelated'),
    createUser(ids.pendingUser, 'Acceptance Pending'),
    createUser(ids.inactiveUser, 'Acceptance Inactive'),
    createUser(ids.foreignUser, 'Acceptance Foreign'),
  ]);

  await prisma.role.createMany({
    data: [
      {
        id: ids.priorityRole,
        organization_id: ids.organization,
        branch_id: ids.branch,
        name: 'Acceptance Priority Role',
        permissions: [],
      },
      {
        id: ids.secondaryRole,
        organization_id: ids.organization,
        branch_id: ids.branch,
        name: 'Acceptance Secondary Role',
        permissions: [],
      },
    ],
  });

  await prisma.member.createMany({
    data: [
      {
        id: ids.ownerMember,
        user_id: ids.ownerUser,
        organization_id: ids.organization,
        branch_id: ids.branch,
        status: 'ACTIVE',
      },
      {
        id: ids.subjectMember,
        user_id: ids.subjectUser,
        organization_id: ids.organization,
        branch_id: ids.branch,
        status: 'ACTIVE',
      },
      {
        id: ids.managerMember,
        user_id: ids.managerUser,
        organization_id: ids.organization,
        branch_id: ids.branch,
        status: 'ACTIVE',
      },
      {
        id: ids.childMember,
        user_id: ids.childUser,
        organization_id: ids.organization,
        branch_id: ids.branch,
        manager_member_id: ids.managerMember,
        status: 'ACTIVE',
      },
      {
        id: ids.unrelatedMember,
        user_id: ids.unrelatedUser,
        organization_id: ids.organization,
        branch_id: ids.branch,
        status: 'ACTIVE',
      },
      {
        id: ids.inactiveMember,
        user_id: ids.inactiveUser,
        organization_id: ids.organization,
        branch_id: ids.branch,
        status: 'INACTIVE',
      },
    ],
  });
  await prisma.member.create({
    data: {
      id: ids.foreignMember,
      user_id: ids.foreignUser,
      organization_id: ids.foreignOrganization,
      branch_id: ids.foreignBranch,
      status: 'ACTIVE',
    },
  });
  await prisma.memberRoleAssignment.createMany({
    data: [
      {
        id: ids.priorityAssignment,
        organization_id: ids.organization,
        branch_id: ids.branch,
        member_id: ids.subjectMember,
        role_id: ids.priorityRole,
        priority: 10,
        effective_from: new Date(Date.now() - 60_000),
      },
      {
        id: ids.secondaryAssignment,
        organization_id: ids.organization,
        branch_id: ids.branch,
        member_id: ids.subjectMember,
        role_id: ids.secondaryRole,
        priority: 20,
        effective_from: new Date(Date.now() - 60_000),
      },
    ],
  });

  // P-01..P-05: branch, deterministic role priority, direct override, and future version.
  const branchPolicy = await updatePolicy(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    {
      late_grace_minutes: 15,
    },
    policyManagementPermissions,
  );
  const branchResolved = await getEffectivePolicyForMember(
    ids.organization,
    ids.branch,
    ids.unrelatedMember,
  );
  assert(branchResolved.source_scope === 'BRANCH_DEFAULT', 'Branch-only policy was not selected');
  assert(branchResolved.id === branchPolicy.id, 'Branch default policy id was not resolved');
  const priorityPolicy = await updatePolicy(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    {
      role_id: ids.priorityRole,
      late_grace_minutes: 5,
    },
    policyManagementPermissions,
  );
  await updatePolicy(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    {
      role_id: ids.secondaryRole,
      late_grace_minutes: 7,
    },
    policyManagementPermissions,
  );
  const roleResolved = await getEffectivePolicyForMember(
    ids.organization,
    ids.branch,
    ids.subjectMember,
  );
  assert(roleResolved.source_scope === 'ROLE', 'Role policy was not selected');
  assert(roleResolved.id === priorityPolicy.id, 'Role priority was not deterministic');
  assert(roleResolved.version === priorityPolicy.version, 'Role version was not resolved');

  const directPolicy = await updatePolicy(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    {
      member_id: ids.subjectMember,
      late_grace_minutes: 3,
    },
    policyManagementPermissions,
  );
  const directResolved = await getEffectivePolicyForMember(
    ids.organization,
    ids.branch,
    ids.subjectMember,
  );
  assert(directResolved.source_scope === 'MEMBER', 'Direct member policy did not win');
  assert(directResolved.id === directPolicy.id, 'Direct member policy id was not resolved');

  const futurePolicy = await updatePolicy(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    {
      member_id: ids.subjectMember,
      late_grace_minutes: 1,
      effective_from: new Date(Date.now() + 60_000).toISOString(),
    },
    policyManagementPermissions,
  );
  const beforeFuture = await getEffectivePolicyForMember(
    ids.organization,
    ids.branch,
    ids.subjectMember,
  );
  assert(beforeFuture.id === directPolicy.id, 'Future policy changed the current resolution');
  assert(futurePolicy.version > directPolicy.version, 'Future policy version did not advance');
  assert(branchPolicy.version === 1, 'Branch default version was not created');

  // A-01..A-04: valid punch, missing evidence, geofence rejection, stale version.
  const manual = await clockIn(ids.subjectUser, ids.organization, ids.branch, {
    idempotency_key: `accept-manual-in-${ulid()}`,
    policy_version: directPolicy.version,
    timezone: 'UTC',
  });
  assert(manual.state === 'OPEN', 'Valid manual clock-in was not open');
  const closedManual = await clockOut(
    ids.subjectUser,
    ids.organization,
    ids.branch,
    {
      session_id: manual.id,
      idempotency_key: `accept-manual-out-${ulid()}`,
      policy_version: manual.policy_version,
      timezone: 'UTC',
    },
    new Set(),
  );
  assert(closedManual.state === 'CLOSED', 'Valid manual clock-out did not close the session');

  const evidencePolicy = await updatePolicy(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    {
      member_id: ids.childMember,
      selfie_on_clock_in: true,
      location_on_clock_in: true,
      geofence_enabled: true,
      geofence_lat: 0,
      geofence_lng: 0,
      geofence_radius_meters: 50,
      geofence_accuracy_threshold: 20,
    },
    policyManagementPermissions,
  );
  await expectRejected(
    () =>
      clockIn(ids.childUser, ids.organization, ids.branch, {
        idempotency_key: `accept-missing-evidence-${ulid()}`,
        policy_version: evidencePolicy.version,
        timezone: 'UTC',
      }),
    'Missing required evidence',
  );
  const childSessionsAfterMissing = await prisma.attendanceSession.count({
    where: { member_id: ids.childMember, state: 'OPEN' },
  });
  assert(childSessionsAfterMissing === 0, 'Missing evidence created a session');

  await expectRejected(
    () =>
      clockIn(ids.childUser, ids.organization, ids.branch, {
        idempotency_key: `accept-outside-geofence-${ulid()}`,
        policy_version: evidencePolicy.version,
        timezone: 'UTC',
        latitude: 10,
        longitude: 10,
        accuracy: 5,
        selfie_storage_key: `organizations/${ids.organization}/branches/${ids.branch}/attendance-selfies/staging`,
      }),
    'Outside geofence',
  );
  await expectRejected(
    () =>
      clockIn(ids.childUser, ids.organization, ids.branch, {
        idempotency_key: `accept-stale-policy-${ulid()}`,
        policy_version: evidencePolicy.version + 100,
        timezone: 'UTC',
      }),
    'Stale policy version',
  );

  // Q-01..Q-05 server-side parts: state-derived action, replay, pending/inactive,
  // revocation, and cross-tenant punch rejection. Gallery/live-camera behavior is
  // covered by the mobile widget suite and remains a physical-device gate.
  const gateInvite = await createBranchInvite(ids.ownerUser, ids.organization, ids.branch);
  const gateToken = String(gateInvite.token);
  const gatePreview = await resolveInvite(ids.subjectUser, gateToken);
  assert(gatePreview.attendance_action === 'CLOCK_IN', 'Gate did not derive clock-in');
  const qrKey = `accept-qr-${ulid()}`;
  const qrOpened = await punchAttendanceFromInvite(ids.subjectUser, gateToken, qrKey, {
    token: gateToken,
    timezone: 'UTC',
  });
  const qrReplay = await punchAttendanceFromInvite(ids.subjectUser, gateToken, qrKey, {
    token: gateToken,
    timezone: 'UTC',
  });
  assert(qrOpened.id === qrReplay.id, 'QR replay did not return the original session');
  assert(qrOpened.source === 'QR_GATE', 'QR session source was not persisted');
  const clockOutPreview = await resolveInvite(ids.subjectUser, gateToken);
  assert(clockOutPreview.attendance_action === 'CLOCK_OUT', 'Gate did not derive clock-out');
  const qrClosed = await punchAttendanceFromInvite(
    ids.subjectUser,
    gateToken,
    `accept-qr-out-${ulid()}`,
    {
      token: gateToken,
      timezone: 'UTC',
    },
  );
  assert(qrClosed.state === 'CLOSED', 'QR clock-out did not close the session');

  await prisma.joinRequest.create({
    data: {
      id: ids.pendingRequest,
      user_id: ids.pendingUser,
      organization_id: ids.organization,
      branch_id: ids.branch,
      status: 'PENDING',
      idempotency_key: `accept-pending-${ulid()}`,
    },
  });
  const pendingPreview = await resolveInvite(ids.pendingUser, gateToken);
  assert(pendingPreview.joinability === 'ALREADY_PENDING', 'Pending QR state was not preserved');
  const inactivePreview = await resolveInvite(ids.inactiveUser, gateToken);
  assert(
    inactivePreview.joinability === 'MEMBERSHIP_INACTIVE',
    'Inactive QR state was not preserved',
  );

  const replacementInvite = await createBranchInvite(ids.ownerUser, ids.organization, ids.branch);
  await expectRejected(
    () => resolveInvite(ids.subjectUser, gateToken),
    'Revoked gate QR was accepted',
  );
  const foreignInvite = await createBranchInvite(
    ids.foreignUser,
    ids.foreignOrganization,
    ids.foreignBranch,
  );
  await expectRejected(
    () =>
      punchAttendanceFromInvite(
        ids.subjectUser,
        String(foreignInvite.token),
        `accept-foreign-${ulid()}`,
        {
          token: String(foreignInvite.token),
          timezone: 'UTC',
        },
      ),
    'Cross-tenant QR punch',
  );
  assert(replacementInvite.active === true, 'Replacement gate QR was not active');

  // S-01..S-03: manager subtree, self detail isolation, and audited export.
  await createSession(ids.managerUser, 'accept-manager');
  const childSelfie = createAttendanceSelfieUploadSignature(
    ids.childUser,
    ids.organization,
    ids.branch,
    'acceptance',
  );
  const childSession = await createSession(ids.childUser, 'accept-child', {
    latitude: 0,
    longitude: 0,
    accuracy: 5,
    selfie_storage_key: childSelfie.storage_key,
    selfie_upload_token: childSelfie.upload_token,
  });
  const unrelatedSession = await createSession(ids.unrelatedUser, 'accept-unrelated');
  const teamRows = await listSessions(
    ids.managerUser,
    ids.organization,
    ids.branch,
    { period: 'today', limit: 50 } satisfies ListSessionsQuery,
    new Set(['ATTENDANCE_READ_TEAM']),
  );
  const teamMemberIds = new Set(teamRows.map((row) => row.member_id));
  assert(teamMemberIds.has(ids.managerMember), 'Manager team report omitted the manager');
  assert(teamMemberIds.has(ids.childMember), 'Manager team report omitted the child');
  assert(!teamMemberIds.has(ids.unrelatedMember), 'Manager team report leaked unrelated member');
  const selfRows = await listSessions(
    ids.subjectUser,
    ids.organization,
    ids.branch,
    { period: 'today', limit: 50 } satisfies ListSessionsQuery,
    new Set(['ATTENDANCE_READ_SELF']),
  );
  assert(
    selfRows.every((row) => row.member_id === ids.subjectMember),
    'Self report leaked another member',
  );
  await expectRejected(
    () =>
      getSessionDetail(
        ids.subjectUser,
        ids.organization,
        ids.branch,
        unrelatedSession.id,
        new Set(['ATTENDANCE_READ_SELF']),
      ),
    'Self detail scope',
  );
  const csv = await exportSessions(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    { period: 'today', limit: 50 } satisfies ListSessionsQuery,
    new Set(['ATTENDANCE_READ_ALL']),
  );
  assert(csv.includes('member_name'), 'Attendance export did not return CSV headers');
  const exportAudit = await prisma.auditLog.findFirst({
    where: {
      organization_id: ids.organization,
      branch_id: ids.branch,
      action: 'EXPORT',
      target_type: 'AttendanceSessionExport',
    },
  });
  assert(exportAudit, 'Attendance export was not audited');

  // A-05: policy-controlled, permissioned, idempotent manager manual record.
  const manualPolicy = await updatePolicy(
    ids.ownerUser,
    ids.organization,
    ids.branch,
    {
      member_id: ids.unrelatedMember,
      allow_manual_entry: true,
    },
    policyManagementPermissions,
  );
  const manualKey = `accept-manual-record-${ulid()}`;
  const manualRecord = await createManualSession(
    ids.managerUser,
    ids.organization,
    ids.branch,
    {
      member_id: ids.unrelatedMember,
      clock_in_at: '2026-09-26T08:00:00.000Z',
      clock_out_at: '2026-09-26T16:00:00.000Z',
      policy_version: manualPolicy.version,
      reason: 'Member forgot to punch at the front desk',
      idempotency_key: manualKey,
    },
    new Set(['ATTENDANCE_CREATE_ALL']),
  );
  const manualReplay = await createManualSession(
    ids.managerUser,
    ids.organization,
    ids.branch,
    {
      member_id: ids.unrelatedMember,
      clock_in_at: '2026-09-26T08:00:00.000Z',
      clock_out_at: '2026-09-26T16:00:00.000Z',
      policy_version: manualPolicy.version,
      reason: 'Member forgot to punch at the front desk',
      idempotency_key: manualKey,
    },
    new Set(['ATTENDANCE_CREATE_ALL']),
  );
  assert(manualRecord.source === 'ADMIN', 'Manual record source was not ADMIN');
  assert(manualRecord.derived_status === 'MANUAL', 'Manual record status was not MANUAL');
  assert(manualRecord.id === manualReplay.id, 'Manual record replay was not idempotent');
  await expectRejected(
    () =>
      createManualSession(
        ids.subjectUser,
        ids.organization,
        ids.branch,
        {
          member_id: ids.unrelatedMember,
          clock_in_at: '2026-09-26T08:00:00.000Z',
          reason: 'Unauthorized manual record',
          idempotency_key: `accept-manual-unauthorized-${ulid()}`,
        },
        new Set(['ATTENDANCE_CREATE_SELF']),
      ),
    'Unauthorized manual record',
  );

  // O-01/O-02: deduplicated operational notifications and safe failure notice.
  await prisma.attendanceSession.create({
    data: {
      id: ids.oldSession,
      organization_id: ids.organization,
      branch_id: ids.branch,
      member_id: ids.subjectMember,
      policy_version: directPolicy.version,
      policy_snapshot: { max_open_session_hours: 1 },
      branch_timezone: 'UTC',
      state: 'OPEN',
      source: 'SELF',
      clock_in_at: new Date(Date.now() - 2 * 60 * 60 * 1000),
      clock_in_timezone: 'UTC',
    },
  });
  await reviewOpenAttendanceSessions();
  await reviewOpenAttendanceSessions();
  const missingClockOutNotifications = await prisma.notification.count({
    where: {
      dedupe_key: `attendance-missing-clock-out:${ids.oldSession}:${new Date().toISOString().slice(0, 10)}`,
    },
  });
  assert(missingClockOutNotifications === 1, 'Missing-clock-out notification was not deduplicated');
  const failureKey = `accept-notification-failure-${ulid()}`;
  await expectRejected(
    () =>
      clockIn(ids.childUser, ids.organization, ids.branch, {
        idempotency_key: failureKey,
        policy_version: evidencePolicy.version,
        timezone: 'UTC',
      }),
    'Evidence failure notification punch',
  );
  const failureNotification = await waitForNotification(`attendance-failure:${failureKey}`);
  assert(failureNotification, 'Evidence failure notification was not created');
  assert(
    !failureNotification.body.includes('database') &&
      !failureNotification.body.includes('password'),
    'Evidence failure notification leaked internal error details',
  );

  assert(childSession.state === 'CLOSED', 'Child staging session was not closed');
  console.log('Attendance acceptance check passed', {
    policy_scopes: ['BRANCH_DEFAULT', 'ROLE', 'MEMBER'],
    stale_policy: 'validated and corrected by policy version',
    qr: 'server-derived action and idempotent replay',
    scope: 'manager subtree and self isolation',
    export: 'audited',
    manual: 'permissioned, policy-controlled, and idempotent',
    notifications: 'deduplicated and sanitized',
  });
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      await cleanup();
    } finally {
      await prisma.$disconnect();
    }
  });
