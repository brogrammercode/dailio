/* eslint-disable no-console */
import { ulid } from 'ulid';

import { prisma } from '../src/lib/prisma';
import { clockIn, clockOut } from '../src/modules/attendance/attendance.service';
import {
  createOpaqueInviteToken,
  hashInviteToken,
  punchAttendanceFromInvite,
} from '../src/modules/invites/invites.service';

if (process.env.RUN_ATTENDANCE_CONCURRENCY_CHECK !== 'true') {
  throw new Error(
    'Refusing to run. Set RUN_ATTENDANCE_CONCURRENCY_CHECK=true against a disposable staging database.',
  );
}

const ids = {
  organization: `att_test_org_${ulid()}`,
  branch: `att_test_branch_${ulid()}`,
  siblingBranch: `att_test_sibling_branch_${ulid()}`,
  user: `att_test_user_${ulid()}`,
  member: `att_test_member_${ulid()}`,
  siblingMember: `att_test_sibling_member_${ulid()}`,
  policy: `att_test_policy_${ulid()}`,
  invite: `att_test_invite_${ulid()}`,
  foreignOrganization: `att_test_foreign_org_${ulid()}`,
  foreignBranch: `att_test_foreign_branch_${ulid()}`,
  foreignUser: `att_test_foreign_user_${ulid()}`,
  foreignMember: `att_test_foreign_member_${ulid()}`,
  foreignInvite: `att_test_foreign_invite_${ulid()}`,
};

const context = {
  organizationId: ids.organization,
  branchId: ids.branch,
  userId: ids.user,
  memberId: ids.member,
};

async function cleanup() {
  await prisma.inviteToken.deleteMany({ where: { id: ids.invite } });
  await prisma.inviteToken.deleteMany({ where: { id: ids.foreignInvite } });
  await prisma.auditLog.deleteMany({ where: { organization_id: ids.organization } });
  await prisma.auditLog.deleteMany({ where: { organization_id: ids.foreignOrganization } });
  await prisma.attendanceSession.deleteMany({ where: { organization_id: ids.organization } });
  await prisma.attendanceSession.deleteMany({
    where: { organization_id: ids.foreignOrganization },
  });
  await prisma.attendancePolicy.deleteMany({ where: { organization_id: ids.organization } });
  await prisma.attendancePolicy.deleteMany({ where: { organization_id: ids.foreignOrganization } });
  await prisma.member.deleteMany({ where: { id: ids.foreignMember } });
  await prisma.member.deleteMany({ where: { id: ids.siblingMember } });
  await prisma.member.deleteMany({ where: { id: ids.member } });
  await prisma.branch.deleteMany({ where: { id: ids.foreignBranch } });
  await prisma.organization.deleteMany({ where: { id: ids.foreignOrganization } });
  await prisma.user.deleteMany({ where: { id: ids.foreignUser } });
  await prisma.branch.deleteMany({ where: { id: ids.siblingBranch } });
  await prisma.branch.deleteMany({ where: { id: ids.branch } });
  await prisma.organization.deleteMany({ where: { id: ids.organization } });
  await prisma.user.deleteMany({ where: { id: ids.user } });
}

async function main() {
  await prisma.organization.create({
    data: {
      id: ids.organization,
      name: `Attendance concurrency ${ulid()}`,
      slug: `attendance-concurrency-${ulid().toLowerCase()}`,
      status: 'ACTIVE',
      type: 'GYM',
      timezone: 'UTC',
      currency: 'INR',
    },
  });
  await prisma.branch.create({
    data: {
      id: ids.branch,
      organization_id: ids.organization,
      name: 'Concurrency Test Branch',
      timezone: 'UTC',
      status: 'ACTIVE',
    },
  });
  await prisma.branch.create({
    data: {
      id: ids.siblingBranch,
      organization_id: ids.organization,
      name: 'Sibling Test Branch',
      timezone: 'UTC',
      status: 'ACTIVE',
    },
  });
  await prisma.user.create({
    data: {
      id: ids.user,
      name: 'Attendance Concurrency Test User',
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
  await prisma.member.create({
    data: {
      id: ids.siblingMember,
      user_id: ids.user,
      organization_id: ids.organization,
      branch_id: ids.siblingBranch,
      status: 'ACTIVE',
    },
  });
  await prisma.attendancePolicy.create({
    data: {
      id: ids.policy,
      organization_id: ids.organization,
      branch_id: ids.branch,
      effective_from: new Date(Date.now() - 60_000),
      punch_required: true,
    },
  });
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

  await prisma.organization.create({
    data: {
      id: ids.foreignOrganization,
      name: `Foreign attendance concurrency ${ulid()}`,
      slug: `foreign-attendance-concurrency-${ulid().toLowerCase()}`,
      status: 'ACTIVE',
      type: 'GYM',
      timezone: 'UTC',
      currency: 'INR',
    },
  });
  await prisma.branch.create({
    data: {
      id: ids.foreignBranch,
      organization_id: ids.foreignOrganization,
      name: 'Foreign Test Branch',
      timezone: 'UTC',
      status: 'ACTIVE',
    },
  });
  await prisma.user.create({
    data: {
      id: ids.foreignUser,
      name: 'Foreign Attendance Concurrency User',
      email: `${ulid().toLowerCase()}@invalid.test`,
      status: 'ACTIVE',
    },
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
  const foreignGateToken = createOpaqueInviteToken();
  await prisma.inviteToken.create({
    data: {
      id: ids.foreignInvite,
      organization_id: ids.foreignOrganization,
      branch_id: ids.foreignBranch,
      purpose: 'BRANCH_JOIN',
      token_hash: hashInviteToken(foreignGateToken),
      expires_at: null,
      created_by: ids.foreignUser,
    },
  });

  const duplicateKey = `concurrency-in-${ulid()}`;
  const duplicateResults = await Promise.allSettled([
    clockIn(context.userId, context.organizationId, context.branchId, {
      idempotency_key: duplicateKey,
      timezone: 'UTC',
    }),
    clockIn(context.userId, context.organizationId, context.branchId, {
      idempotency_key: duplicateKey,
      timezone: 'UTC',
    }),
  ]);
  const openSessions = await prisma.attendanceSession.findMany({
    where: { organization_id: ids.organization, branch_id: ids.branch },
  });
  if (openSessions.length !== 1 || openSessions[0].state !== 'OPEN') {
    throw new Error(`Expected exactly one open session, found ${openSessions.length}`);
  }
  if (!duplicateResults.some((result) => result.status === 'fulfilled')) {
    throw new Error('Both duplicate clock-in requests failed');
  }
  const differentManualKey = await clockIn(
    context.userId,
    context.organizationId,
    context.branchId,
    { idempotency_key: `concurrency-different-in-${ulid()}`, timezone: 'UTC' },
  ).catch((error: unknown) => error);
  if (!(differentManualKey instanceof Error)) {
    throw new Error('A different-key manual clock-in bypassed the open-session guard');
  }

  await clockOut(
    context.userId,
    context.organizationId,
    context.branchId,
    {
      session_id: openSessions[0].id,
      idempotency_key: `concurrency-close-${ulid()}`,
      timezone: 'UTC',
    },
    new Set(),
  );

  const qrKey = `concurrency-qr-${ulid()}`;
  const qrResults = await Promise.allSettled([
    punchAttendanceFromInvite(context.userId, gateToken, qrKey, {
      token: gateToken,
      timezone: 'UTC',
    }),
    punchAttendanceFromInvite(context.userId, gateToken, qrKey, {
      token: gateToken,
      timezone: 'UTC',
    }),
  ]);
  const qrSessions = await prisma.attendanceSession.findMany({
    where: {
      organization_id: ids.organization,
      branch_id: ids.branch,
      source: 'QR_GATE',
      state: 'OPEN',
    },
  });
  if (qrSessions.length !== 1 || qrSessions[0].source !== 'QR_GATE') {
    throw new Error(`Expected exactly one open QR session, found ${qrSessions.length}`);
  }
  if (!qrResults.some((result) => result.status === 'fulfilled')) {
    throw new Error('Both concurrent QR punch requests failed');
  }
  const sessionId = qrSessions[0].id;
  const outKey = `concurrency-out-${ulid()}`;
  const clockOutResults = await Promise.allSettled([
    clockOut(
      context.userId,
      context.organizationId,
      context.branchId,
      { session_id: sessionId, idempotency_key: outKey, timezone: 'UTC' },
      new Set(),
    ),
    clockOut(
      context.userId,
      context.organizationId,
      context.branchId,
      { session_id: sessionId, idempotency_key: outKey, timezone: 'UTC' },
      new Set(),
    ),
  ]);
  const closed = await prisma.attendanceSession.findUnique({ where: { id: sessionId } });
  if (!closed || closed.state !== 'CLOSED' || !closed.clock_out_at) {
    throw new Error('Concurrent clock-out did not leave one closed session');
  }
  if (!clockOutResults.some((result) => result.status === 'fulfilled')) {
    throw new Error('Both concurrent clock-out requests failed');
  }

  const siblingSession = await clockIn(context.userId, context.organizationId, ids.siblingBranch, {
    idempotency_key: `cross-branch-${ulid()}`,
    timezone: 'UTC',
  });
  const foreignSession = await clockIn(
    ids.foreignUser,
    ids.foreignOrganization,
    ids.foreignBranch,
    { idempotency_key: `cross-tenant-${ulid()}`, timezone: 'UTC' },
  );
  const crossBranchAttempt = await clockOut(
    context.userId,
    context.organizationId,
    context.branchId,
    {
      session_id: siblingSession.id,
      idempotency_key: `cross-branch-out-${ulid()}`,
      timezone: 'UTC',
    },
    new Set(),
  ).catch((error: unknown) => error);
  const crossTenantAttempt = await clockOut(
    context.userId,
    context.organizationId,
    context.branchId,
    {
      session_id: foreignSession.id,
      idempotency_key: `cross-tenant-out-${ulid()}`,
      timezone: 'UTC',
    },
    new Set(),
  ).catch((error: unknown) => error);
  const crossTenantQrAttempt = await punchAttendanceFromInvite(
    context.userId,
    foreignGateToken,
    `cross-tenant-qr-${ulid()}`,
    { token: foreignGateToken, timezone: 'UTC' },
  ).catch((error: unknown) => error);
  if (
    !(crossBranchAttempt instanceof Error) ||
    !(crossTenantAttempt instanceof Error) ||
    !(crossTenantQrAttempt instanceof Error)
  ) {
    throw new Error('A cross-branch or cross-tenant identifier was accepted');
  }

  console.log('Attendance concurrency check passed', {
    session_id: sessionId,
    clock_in_results: duplicateResults.map((result) => result.status),
    qr_results: qrResults.map((result) => result.status),
    clock_out_results: clockOutResults.map((result) => result.status),
    isolation_checks: 'cross-branch and cross-tenant rejected',
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
