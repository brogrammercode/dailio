import { createHash, randomBytes } from 'node:crypto';

import type { Prisma } from '@prisma/client';
import { ulid } from 'ulid';

import { ConflictError, ForbiddenError, NotFoundError, UnprocessableError } from '../../lib/errors';
import { prisma } from '../../lib/prisma';
import * as attendanceService from '../attendance/attendance.service';
import type { QrPunchInput } from '../attendance/attendance.schema';

import type {
  CreateDirectSubscriptionDraftInput,
  CreateSubscriptionDraftInput,
  JoinInviteRequestInput,
} from './invites.schema';

const INVITE_PREFIX = 'dailio://invite?token=';

const inviteTransactionOptions = {
  maxWait: 10_000,
  timeout: 15_000,
} as const;

export function createOpaqueInviteToken() {
  return randomBytes(32).toString('base64url');
}

export function hashInviteToken(token: string) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function qrPayload(token: string) {
  return `${INVITE_PREFIX}${encodeURIComponent(token)}`;
}

type InviteResponseInput = {
  id: string;
  purpose: string;
  organization: { id: string; name: string };
  branch: {
    id: string;
    name: string;
    city: string | null;
    state: string | null;
    timezone: string;
  };
  plan: {
    id: string;
    name: string;
    duration_days: number;
    amount_minor_unit: number;
    joining_fee_minor: number;
    currency: string;
    discount_percent: number;
    is_active: boolean;
  } | null;
  expires_at: Date | null;
  revoked_at: Date | null;
};

function inviteResponse(invite: InviteResponseInput, rawToken?: string) {
  return {
    id: invite.id,
    purpose: invite.purpose,
    organization: { id: invite.organization.id, name: invite.organization.name },
    branch: {
      id: invite.branch.id,
      name: invite.branch.name,
      city: invite.branch.city,
      state: invite.branch.state,
      timezone: invite.branch.timezone,
    },
    plan: invite.plan
      ? {
          id: invite.plan.id,
          name: invite.plan.name,
          duration_days: invite.plan.duration_days,
          amount_minor_unit: invite.plan.amount_minor_unit,
          joining_fee_minor: invite.plan.joining_fee_minor,
          currency: invite.plan.currency,
          discount_percent: invite.plan.discount_percent,
          is_active: invite.plan.is_active,
        }
      : null,
    expires_at: invite.expires_at,
    revoked_at: invite.revoked_at,
    active: !invite.revoked_at,
    ...(rawToken ? { token: rawToken, qr_payload: qrPayload(rawToken) } : {}),
  };
}

const inviteInclude = {
  organization: { select: { id: true, name: true } },
  branch: {
    select: { id: true, name: true, city: true, state: true, timezone: true, status: true },
  },
  plan: {
    select: {
      id: true,
      name: true,
      duration_days: true,
      amount_minor_unit: true,
      joining_fee_minor: true,
      currency: true,
      discount_percent: true,
      is_active: true,
    },
  },
} satisfies Prisma.InviteTokenInclude;

async function createInvite(
  actorId: string,
  organizationId: string,
  branchId: string,
  purpose: 'BRANCH_JOIN' | 'PLAN_PURCHASE',
  planId: string | null,
) {
  const rawToken = createOpaqueInviteToken();
  const invite = await prisma.$transaction(async (tx) => {
    const branch = await tx.branch.findFirst({
      where: { id: branchId, organization_id: organizationId, status: 'ACTIVE' },
    });
    if (!branch) throw new NotFoundError('Branch');

    if (planId) {
      const plan = await tx.plan.findFirst({
        where: {
          id: planId,
          organization_id: organizationId,
          is_active: true,
          OR: [{ branch_id: branchId }, { branch_id: null }],
        },
      });
      if (!plan) throw new NotFoundError('Active plan');
    }

    await tx.inviteToken.updateMany({
      where: {
        organization_id: organizationId,
        branch_id: branchId,
        purpose,
        ...(planId ? { plan_id: planId } : { plan_id: null }),
        revoked_at: null,
      },
      data: { revoked_at: new Date() },
    });

    const created = await tx.inviteToken.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        plan_id: planId,
        purpose,
        token_hash: hashInviteToken(rawToken),
        expires_at: null,
        created_by: actorId,
      },
      include: inviteInclude,
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorId,
        action: 'CREATE',
        target_type: 'InviteToken',
        target_id: created.id,
        after_state: { purpose, permanent: true, plan_id: planId },
      },
    });
    return created;
  }, inviteTransactionOptions);
  return inviteResponse(invite, rawToken);
}

export function createBranchInvite(actorId: string, organizationId: string, branchId: string) {
  return createInvite(actorId, organizationId, branchId, 'BRANCH_JOIN', null);
}

export function createPlanInvite(
  actorId: string,
  organizationId: string,
  branchId: string,
  planId: string,
) {
  return createInvite(actorId, organizationId, branchId, 'PLAN_PURCHASE', planId);
}

async function findActiveInvite(rawToken: string) {
  const invite = await prisma.inviteToken.findUnique({
    where: { token_hash: hashInviteToken(rawToken) },
    include: inviteInclude,
  });
  if (!invite || invite.revoked_at || (invite.expires_at && invite.expires_at <= new Date())) {
    throw new NotFoundError('Invite');
  }
  if (invite.branch.status !== 'ACTIVE') throw new ConflictError('Branch is not available');
  if (invite.purpose === 'PLAN_PURCHASE' && (!invite.plan || !invite.plan.is_active)) {
    throw new ConflictError('This subscription plan is no longer active');
  }
  return invite;
}

export async function resolveInvite(userId: string, rawToken: string) {
  const invite = await findActiveInvite(rawToken);
  const member = await prisma.member.findFirst({
    where: {
      user_id: userId,
      organization_id: invite.organization_id,
      branch_id: invite.branch_id,
    },
    include: { shift: true },
  });
  const pending = await prisma.joinRequest.findFirst({
    where: {
      user_id: userId,
      organization_id: invite.organization_id,
      branch_id: invite.branch_id,
      status: 'PENDING',
    },
    select: { id: true, created_at: true },
  });
  const activeSession =
    member?.status === 'ACTIVE'
      ? await prisma.attendanceSession.findFirst({
          where: {
            organization_id: invite.organization_id,
            branch_id: invite.branch_id,
            member_id: member.id,
            state: 'OPEN',
          },
          select: { id: true, clock_in_at: true, policy_version: true, policy_snapshot: true },
        })
      : null;
  const policy =
    member?.status === 'ACTIVE'
      ? await attendanceService.getEffectivePolicyForMember(
          invite.organization_id,
          invite.branch_id,
          member.id,
        )
      : null;
  const actionPolicy = (activeSession?.policy_snapshot ?? policy) as {
    version?: number;
    source_scope?: string;
    effective_from?: Date | string | null;
    selfie_on_clock_in?: boolean;
    selfie_on_clock_out?: boolean;
    location_on_clock_in?: boolean;
    location_on_clock_out?: boolean;
    geofence_enabled?: boolean;
    late_grace_minutes?: number;
    shift_enforcement_enabled?: boolean;
    punch_required?: boolean;
  } | null;
  return {
    ...inviteResponse(invite),
    joinability:
      member?.status === 'ACTIVE'
        ? 'ALREADY_MEMBER'
        : pending
          ? 'ALREADY_PENDING'
          : member
            ? 'MEMBERSHIP_INACTIVE'
            : 'JOINABLE',
    existing_request_id: pending?.id ?? null,
    membership_id: member?.id ?? null,
    attendance_action:
      member?.status !== 'ACTIVE'
        ? null
        : activeSession
          ? 'CLOCK_OUT'
          : actionPolicy?.punch_required !== false
            ? 'CLOCK_IN'
            : 'ATTENDANCE_DISABLED',
    attendance_available:
      member?.status === 'ACTIVE' &&
      (activeSession !== null || actionPolicy?.punch_required !== false),
    active_session_id: activeSession?.id ?? null,
    attendance_policy: actionPolicy
      ? {
          version: actionPolicy.version,
          source_scope: actionPolicy.source_scope,
          effective_from: actionPolicy.effective_from,
          selfie_required: actionPolicy.selfie_on_clock_in || actionPolicy.selfie_on_clock_out,
          selfie_on_clock_in: actionPolicy.selfie_on_clock_in,
          selfie_on_clock_out: actionPolicy.selfie_on_clock_out,
          location_required:
            actionPolicy.location_on_clock_in ||
            actionPolicy.location_on_clock_out ||
            actionPolicy.geofence_enabled,
          location_on_clock_in: actionPolicy.location_on_clock_in,
          location_on_clock_out: actionPolicy.location_on_clock_out,
          geofence_enabled: actionPolicy.geofence_enabled,
          late_grace_minutes: actionPolicy.late_grace_minutes,
          shift_enforcement_enabled: actionPolicy.shift_enforcement_enabled,
          punch_required: actionPolicy.punch_required !== false,
          shift: member?.shift
            ? {
                name: member?.shift?.name,
                start_time: member?.shift?.start_time,
                end_time: member?.shift?.end_time,
                is_overnight: member?.shift?.is_overnight,
              }
            : null,
        }
      : null,
  };
}

export async function punchAttendanceFromInvite(
  userId: string,
  rawToken: string,
  idempotencyKey: string,
  data: QrPunchInput,
) {
  const invite = await findActiveInvite(rawToken);
  if (invite.purpose !== 'BRANCH_JOIN') {
    throw new ConflictError('This QR code is not a branch gate QR');
  }

  const member = await prisma.member.findFirst({
    where: {
      user_id: userId,
      organization_id: invite.organization_id,
      branch_id: invite.branch_id,
      status: 'ACTIVE',
    },
  });
  if (!member)
    throw new ForbiddenError('An active branch membership is required to punch attendance');

  // Return a prior QR result before resolving the next action or appending a
  // second audit event. The member scope is part of this lookup so an
  // idempotency key cannot disclose or replay another member's session.
  const prior = await prisma.attendanceSession.findFirst({
    where: {
      organization_id: invite.organization_id,
      branch_id: invite.branch_id,
      member_id: member.id,
      OR: [{ idempotency_key_in: idempotencyKey }, { idempotency_key_out: idempotencyKey }],
    },
    include: { evidence: true },
  });
  if (prior) return prior;

  const active = await prisma.attendanceSession.findFirst({
    where: {
      organization_id: invite.organization_id,
      branch_id: invite.branch_id,
      member_id: member.id,
      state: 'OPEN',
    },
  });
  const punchData = {
    ...data,
    idempotency_key: idempotencyKey,
  };
  const session = active
    ? await attendanceService.clockOut(
        userId,
        invite.organization_id,
        invite.branch_id,
        { ...punchData, session_id: active.id },
        new Set<string>(),
        'QR_GATE',
      )
    : await attendanceService.clockIn(
        userId,
        invite.organization_id,
        invite.branch_id,
        punchData,
        'QR_GATE',
      );

  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id: invite.organization_id,
      branch_id: invite.branch_id,
      actor_id: userId,
      action: 'CREATE',
      target_type: 'AttendanceQrPunch',
      target_id: session.id,
      after_state: { source: 'QR_GATE', action: active ? 'CLOCK_OUT' : 'CLOCK_IN' },
    },
  });
  return session;
}

export async function submitJoinRequestFromInvite(
  userId: string,
  rawToken: string,
  idempotencyKey: string,
  data: JoinInviteRequestInput,
) {
  const invite = await findActiveInvite(rawToken);
  if (invite.purpose !== 'BRANCH_JOIN')
    throw new ConflictError('This QR code is for a subscription plan');

  const existing = await prisma.joinRequest.findUnique({
    where: { idempotency_key: idempotencyKey },
  });
  if (existing) {
    if (existing.user_id !== userId || existing.branch_id !== invite.branch_id) {
      throw new ConflictError('Idempotency key is already used for another request');
    }
    return existing;
  }

  try {
    return await prisma.joinRequest.create({
      data: {
        id: ulid(),
        user_id: userId,
        branch_id: invite.branch_id,
        organization_id: invite.organization_id,
        status: 'PENDING',
        message: data.message,
        idempotency_key: idempotencyKey,
      },
    });
  } catch (error) {
    const code = (error as { code?: string })?.code;
    if (code === 'P2002') {
      const existingPending = await prisma.joinRequest.findFirst({
        where: { user_id: userId, branch_id: invite.branch_id, status: 'PENDING' },
      });
      if (existingPending) return existingPending;
    }
    throw error;
  }
}

export async function createSubscriptionDraftFromInvite(
  userId: string,
  rawToken: string,
  idempotencyKey: string,
  data: CreateSubscriptionDraftInput,
) {
  const invite = await findActiveInvite(rawToken);
  if (invite.purpose !== 'PLAN_PURCHASE' || !invite.plan) {
    throw new ConflictError('This QR code is not a subscription plan invite');
  }
  const startDate = new Date(data.start_date);
  if (Number.isNaN(startDate.valueOf()))
    throw new UnprocessableError('Subscription start date is invalid');
  const plan = invite.plan;

  return prisma.$transaction(
    async (tx) => {
      const member = await tx.member.findFirst({
        where: {
          user_id: userId,
          organization_id: invite.organization_id,
          branch_id: invite.branch_id,
          status: 'ACTIVE',
        },
      });
      if (!member) throw new ForbiddenError('An active membership in this branch is required');

      const existing = await tx.subscription.findUnique({
        where: { idempotency_key: idempotencyKey },
      });
      if (existing) {
        if (existing.member_id !== member.id || existing.branch_id !== invite.branch_id) {
          throw new ConflictError('Idempotency key is already used for another subscription');
        }
        return existing;
      }

      const endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + plan.duration_days);
      const discount = Math.round(
        ((plan.amount_minor_unit + plan.joining_fee_minor) * plan.discount_percent) / 100,
      );
      const overlap = await tx.subscription.findFirst({
        where: {
          organization_id: invite.organization_id,
          branch_id: invite.branch_id,
          member_id: member.id,
          status: { in: ['DRAFT', 'UPCOMING', 'ACTIVE', 'PAUSED'] },
          start_date: { lte: endDate },
          end_date: { gte: startDate },
        },
      });
      if (overlap) throw new ConflictError('Member already has an overlapping subscription');

      const subscriptionId = ulid();
      const subscription = await tx.subscription.create({
        data: {
          id: subscriptionId,
          organization_id: invite.organization_id,
          branch_id: invite.branch_id,
          member_id: member.id,
          plan_id: plan.id,
          plan_snapshot: plan as Prisma.InputJsonValue,
          status: 'DRAFT',
          start_date: startDate,
          end_date: endDate,
          agreed_amount_minor: plan.amount_minor_unit,
          discount_minor: discount,
          currency: plan.currency,
          created_by: userId,
          due_date: endDate,
          idempotency_key: idempotencyKey,
        },
      });

      const charge = plan.amount_minor_unit + plan.joining_fee_minor;
      await tx.ledgerEntry.create({
        data: {
          id: ulid(),
          organization_id: invite.organization_id,
          branch_id: invite.branch_id,
          member_id: member.id,
          subscription_id: subscription.id,
          category: 'SUBSCRIPTION_CHARGE',
          amount_minor_unit: charge,
          currency: plan.currency,
          description: `Subscription charge: ${plan.name}`,
          created_by: userId,
          idempotency_key: `subscription-charge:${subscription.id}`,
        },
      });
      if (discount > 0) {
        await tx.ledgerEntry.create({
          data: {
            id: ulid(),
            organization_id: invite.organization_id,
            branch_id: invite.branch_id,
            member_id: member.id,
            subscription_id: subscription.id,
            category: 'DISCOUNT_CREDIT',
            amount_minor_unit: -discount,
            currency: plan.currency,
            description: `Discount: ${plan.name}`,
            created_by: userId,
            idempotency_key: `subscription-discount:${subscription.id}`,
          },
        });
      }
      await tx.member.update({
        where: { id: member.id },
        data: { subscription_id: subscription.id },
      });
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: invite.organization_id,
          branch_id: invite.branch_id,
          actor_id: userId,
          action: 'CREATE',
          target_type: 'Subscription',
          target_id: subscription.id,
          after_state: { status: 'DRAFT', plan_id: plan.id, source: 'PLAN_PURCHASE_INVITE' },
        },
      });
      return subscription;
    },
    {
      isolationLevel: 'Serializable',
      maxWait: 10_000,
      timeout: 30_000,
    },
  );
}

export async function createDirectSubscriptionDraft(
  userId: string,
  organizationId: string,
  branchId: string,
  planId: string,
  idempotencyKey: string,
  data: CreateDirectSubscriptionDraftInput,
) {
  const startDate = new Date(data.start_date);
  if (Number.isNaN(startDate.valueOf()))
    throw new UnprocessableError('Subscription start date is invalid');

  return prisma.$transaction(
    async (tx) => {
      const member = await tx.member.findFirst({
        where: {
          user_id: userId,
          organization_id: organizationId,
          branch_id: branchId,
          status: 'ACTIVE',
        },
      });
      if (!member) throw new ForbiddenError('An active membership in this branch is required');

      const existing = await tx.subscription.findUnique({
        where: { idempotency_key: idempotencyKey },
      });
      if (existing) {
        if (
          existing.organization_id !== organizationId ||
          existing.branch_id !== branchId ||
          existing.member_id !== member.id
        ) {
          throw new ConflictError('Idempotency key is already used for another subscription');
        }
        const existingPlan = await tx.plan.findUnique({ where: { id: existing.plan_id } });
        return {
          subscription: existing,
          plan: existingPlan,
          total_minor_unit: existingPlan
            ? existingPlan.amount_minor_unit +
              existingPlan.joining_fee_minor -
              Math.round(
                ((existingPlan.amount_minor_unit + existingPlan.joining_fee_minor) *
                  existingPlan.discount_percent) /
                  100,
              )
            : existing.agreed_amount_minor - existing.discount_minor,
        };
      }

      const plan = await tx.plan.findFirst({
        where: {
          id: planId,
          organization_id: organizationId,
          is_active: true,
          OR: [{ branch_id: branchId }, { branch_id: null }],
        },
      });
      if (!plan) throw new NotFoundError('Active plan');

      const endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + plan.duration_days);
      const discount = Math.round(
        ((plan.amount_minor_unit + plan.joining_fee_minor) * plan.discount_percent) / 100,
      );
      const overlap = await tx.subscription.findFirst({
        where: {
          organization_id: organizationId,
          branch_id: branchId,
          member_id: member.id,
          status: { in: ['DRAFT', 'UPCOMING', 'ACTIVE', 'PAUSED'] },
          start_date: { lte: endDate },
          end_date: { gte: startDate },
        },
      });
      if (overlap) throw new ConflictError('Member already has an overlapping subscription');

      const subscription = await tx.subscription.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          member_id: member.id,
          plan_id: plan.id,
          plan_snapshot: plan as Prisma.InputJsonValue,
          status: 'DRAFT',
          start_date: startDate,
          end_date: endDate,
          agreed_amount_minor: plan.amount_minor_unit,
          discount_minor: discount,
          currency: plan.currency,
          created_by: userId,
          due_date: endDate,
          idempotency_key: idempotencyKey,
        },
      });
      const charge = plan.amount_minor_unit + plan.joining_fee_minor;
      await tx.ledgerEntry.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          member_id: member.id,
          subscription_id: subscription.id,
          category: 'SUBSCRIPTION_CHARGE',
          amount_minor_unit: charge,
          currency: plan.currency,
          description: `Subscription charge: ${plan.name}`,
          created_by: userId,
          idempotency_key: `subscription-charge:${subscription.id}`,
        },
      });
      if (discount > 0) {
        await tx.ledgerEntry.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            member_id: member.id,
            subscription_id: subscription.id,
            category: 'DISCOUNT_CREDIT',
            amount_minor_unit: -discount,
            currency: plan.currency,
            description: `Discount: ${plan.name}`,
            created_by: userId,
            idempotency_key: `subscription-discount:${subscription.id}`,
          },
        });
      }
      await tx.member.update({
        where: { id: member.id },
        data: { subscription_id: subscription.id },
      });
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          actor_id: userId,
          action: 'CREATE',
          target_type: 'Subscription',
          target_id: subscription.id,
          after_state: { status: 'DRAFT', plan_id: plan.id, source: 'MEMBER_PLAN_PURCHASE' },
        },
      });
      return { subscription, plan, total_minor_unit: charge - discount };
    },
    {
      isolationLevel: 'Serializable',
      maxWait: 10_000,
      timeout: 30_000,
    },
  );
}

export async function revokeInvite(
  actorId: string,
  organizationId: string,
  branchId: string,
  inviteId: string,
) {
  const invite = await prisma.inviteToken.findFirst({
    where: { id: inviteId, organization_id: organizationId, branch_id: branchId },
  });
  if (!invite) throw new NotFoundError('Invite');
  if (invite.revoked_at) return invite;
  const updated = await prisma.inviteToken.update({
    where: { id: invite.id },
    data: { revoked_at: new Date() },
  });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id: organizationId,
      branch_id: branchId,
      actor_id: actorId,
      action: 'ARCHIVE',
      target_type: 'InviteToken',
      target_id: invite.id,
      after_state: { revoked_at: updated.revoked_at },
    },
  });
  return updated;
}
