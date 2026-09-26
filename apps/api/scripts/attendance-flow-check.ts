/* eslint-disable no-console */
import { ulid } from 'ulid';

import { prisma } from '../src/lib/prisma';
import {
  clockIn,
  correctSession,
  getPolicy,
  getSessionDetail,
  updatePolicy,
} from '../src/modules/attendance/attendance.service';
import {
  createOpaqueInviteToken,
  hashInviteToken,
  punchAttendanceFromInvite,
} from '../src/modules/invites/invites.service';

if (process.env.RUN_ATTENDANCE_FLOW_CHECK !== 'true') {
  throw new Error(
    'Refusing to run. Set RUN_ATTENDANCE_FLOW_CHECK=true against a disposable staging database.',
  );
}

const ids = {
  organization: `att_flow_org_${ulid()}`,
  branch: `att_flow_branch_${ulid()}`,
  user: `att_flow_user_${ulid()}`,
  member: `att_flow_member_${ulid()}`,
  role: `att_flow_role_${ulid()}`,
  roleAssignment: `att_flow_role_assignment_${ulid()}`,
  branchPolicy: `att_flow_branch_policy_${ulid()}`,
  memberPolicy: `att_flow_member_policy_${ulid()}`,
  invite: `att_flow_invite_${ulid()}`,
};

async function cleanup() {
  await prisma.inviteToken.deleteMany({ where: { id: ids.invite } });
  await prisma.auditLog.deleteMany({ where: { organization_id: ids.organization } });
  await prisma.attendanceCorrection.deleteMany({ where: { organization_id: ids.organization } });
  await prisma.attendanceSession.deleteMany({ where: { organization_id: ids.organization } });
  await prisma.attendancePolicy.deleteMany({ where: { organization_id: ids.organization } });
  await prisma.memberRoleAssignment.deleteMany({ where: { id: ids.roleAssignment } });
  await prisma.role.deleteMany({ where: { id: ids.role } });
  await prisma.member.deleteMany({ where: { id: ids.member } });
  await prisma.branch.deleteMany({ where: { id: ids.branch } });
  await prisma.organization.deleteMany({ where: { id: ids.organization } });
  await prisma.user.deleteMany({ where: { id: ids.user } });
}

async function main() {
  await prisma.organization.create({
    data: {
      id: ids.organization,
      name: `Attendance flow ${ulid()}`,
      slug: `attendance-flow-${ulid().toLowerCase()}`,
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
      name: 'Attendance Flow Branch',
      timezone: 'UTC',
      status: 'ACTIVE',
    },
  });
  await prisma.user.create({
    data: {
      id: ids.user,
      name: 'Attendance Flow Test User',
      email: `${ulid().toLowerCase()}@invalid.test`,
      status: 'ACTIVE',
    },
  });
  await prisma.member.create({
    data: {
      id: ids.member,
      user_id: ids.user,
      organization_id: ids.organization,
      branch_id: ids.branch,
      status: 'ACTIVE',
    },
  });
  await prisma.role.create({
    data: {
      id: ids.role,
      organization_id: ids.organization,
      branch_id: ids.branch,
      name: 'Attendance Flow Coach',
      permissions: [],
    },
  });
  await prisma.memberRoleAssignment.create({
    data: {
      id: ids.roleAssignment,
      organization_id: ids.organization,
      branch_id: ids.branch,
      member_id: ids.member,
      role_id: ids.role,
      priority: 10,
      effective_from: new Date(Date.now() - 60_000),
    },
  });

  await updatePolicy(
    ids.user,
    ids.organization,
    ids.branch,
    {
      punch_required: true,
      late_grace_minutes: 10,
    },
    new Set(['ATTENDANCE_POLICY_MANAGE']),
  );
  await updatePolicy(
    ids.user,
    ids.organization,
    ids.branch,
    {
      role_id: ids.role,
      punch_required: true,
      late_grace_minutes: 5,
    },
    new Set(['ATTENDANCE_POLICY_MANAGE']),
  );
  const resolvedRole = (await getPolicy(
    ids.organization,
    ids.branch,
    ids.user,
    new Set(['ATTENDANCE_READ_SELF']),
  )) as Record<string, unknown>;
  if (resolvedRole.source_scope !== 'ROLE' || resolvedRole.resolved_role_id !== ids.role) {
    throw new Error('Role policy was not resolved before the direct-member override');
  }
  await updatePolicy(
    ids.user,
    ids.organization,
    ids.branch,
    {
      member_id: ids.member,
      punch_required: true,
      selfie_on_clock_out: false,
      location_on_clock_out: false,
    },
    new Set(['ATTENDANCE_POLICY_MANAGE']),
  );

  const resolved = (await getPolicy(
    ids.organization,
    ids.branch,
    ids.user,
    new Set(['ATTENDANCE_READ_SELF']),
  )) as Record<string, unknown>;
  if (resolved.resolved_member_id !== ids.member || resolved.source_scope !== 'MEMBER') {
    throw new Error('Member policy was not resolved with direct-member precedence');
  }

  const manualSession = await clockIn(ids.user, ids.organization, ids.branch, {
    idempotency_key: `flow-manual-${ulid()}`,
    policy_version: Number(resolved.version),
    timezone: 'UTC',
  });
  if (manualSession.state !== 'OPEN' || manualSession.policy_version !== resolved.version) {
    throw new Error('Manual clock-in did not create an open policy snapshot');
  }

  const gateToken = createOpaqueInviteToken();
  await prisma.inviteToken.create({
    data: {
      id: ids.invite,
      organization_id: ids.organization,
      branch_id: ids.branch,
      purpose: 'BRANCH_JOIN',
      token_hash: hashInviteToken(gateToken),
      expires_at: null,
      created_by: ids.user,
    },
  });
  const qrClosed = await punchAttendanceFromInvite(ids.user, gateToken, `flow-qr-${ulid()}`, {
    token: gateToken,
    timezone: 'UTC',
  });
  if (qrClosed.id !== manualSession.id || qrClosed.state !== 'CLOSED') {
    throw new Error('Permanent gate QR did not derive clock-out for the open session');
  }

  const detailBeforeCorrection = await getSessionDetail(
    ids.user,
    ids.organization,
    ids.branch,
    manualSession.id,
    new Set(['ATTENDANCE_READ_SELF']),
  );
  const hasTimelineEvent = (timeline: unknown, type: string) =>
    Array.isArray(timeline) &&
    timeline.some(
      (event) =>
        typeof event === 'object' && event !== null && 'type' in event && event.type === type,
    );
  if (!hasTimelineEvent(detailBeforeCorrection.timeline, 'CLOCK_OUT_CONFIRMED')) {
    throw new Error('Attendance detail timeline is missing the QR clock-out event');
  }

  const correctionInput = {
    clock_in_at: new Date(Date.now() - 60_000).toISOString(),
    clock_out_at: new Date().toISOString(),
    correction_reason: 'Staging flow verification correction',
  };
  const correctionResults = await Promise.allSettled([
    correctSession(
      ids.user,
      ids.organization,
      ids.branch,
      manualSession.id,
      correctionInput,
      new Set(['ATTENDANCE_UPDATE']),
    ),
    correctSession(
      ids.user,
      ids.organization,
      ids.branch,
      manualSession.id,
      correctionInput,
      new Set(['ATTENDANCE_UPDATE']),
    ),
  ]);
  const corrected = correctionResults.find(
    (result): result is PromiseFulfilledResult<Awaited<ReturnType<typeof correctSession>>> =>
      result.status === 'fulfilled',
  )?.value;
  const rejectedCorrections = correctionResults.filter((result) => result.status === 'rejected');
  if (!corrected || rejectedCorrections.length !== 1) {
    throw new Error(
      'Concurrent attendance corrections did not produce one winner and one conflict',
    );
  }
  const correctionRows = await prisma.attendanceCorrection.findMany({
    where: { session_id: manualSession.id },
  });
  if (correctionRows.length !== 1 || correctionRows[0].version !== 1) {
    throw new Error('Concurrent attendance corrections created an invalid correction history');
  }
  const detailAfterCorrection = await getSessionDetail(
    ids.user,
    ids.organization,
    ids.branch,
    manualSession.id,
    new Set(['ATTENDANCE_READ_SELF']),
  );
  if (
    corrected.state !== 'CORRECTED' ||
    !hasTimelineEvent(detailAfterCorrection.timeline, 'CORRECTION_APPLIED')
  ) {
    throw new Error('Attendance correction was not preserved in the server timeline');
  }

  console.log('Attendance flow check passed', {
    session_id: manualSession.id,
    resolved_policy_scope: resolved.source_scope,
    qr_source: qrClosed.clock_out_source,
    correction_state: corrected.state,
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
