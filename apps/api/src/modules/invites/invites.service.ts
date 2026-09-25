import { createHash, randomBytes } from 'node:crypto';
import { ulid } from 'ulid';

import type { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { ConflictError, ForbiddenError, NotFoundError, UnprocessableError } from '../../lib/errors';
import type {
  CreateInviteInput,
  CreateSubscriptionDraftInput,
  JoinInviteRequestInput,
} from './invites.schema';

const INVITE_PREFIX = 'dailio://invite?token=';

export function createOpaqueInviteToken() {
  return randomBytes(32).toString('base64url');
}

export function hashInviteToken(token: string) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function qrPayload(token: string) {
  return `${INVITE_PREFIX}${encodeURIComponent(token)}`;
}

function inviteResponse(invite: any, rawToken?: string) {
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
    active: !invite.revoked_at && invite.expires_at > new Date(),
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
  data: CreateInviteInput,
) {
  const rawToken = createOpaqueInviteToken();
  const expiresAt = new Date(Date.now() + data.expires_in_hours * 60 * 60 * 1000);
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
        expires_at: expiresAt,
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
        after_state: { purpose, expires_at: expiresAt, plan_id: planId },
      },
    });
    return created;
  });
  return inviteResponse(invite, rawToken);
}

export function createBranchInvite(
  actorId: string,
  organizationId: string,
  branchId: string,
  data: CreateInviteInput,
) {
  return createInvite(actorId, organizationId, branchId, 'BRANCH_JOIN', null, data);
}

export function createPlanInvite(
  actorId: string,
  organizationId: string,
  branchId: string,
  planId: string,
  data: CreateInviteInput,
) {
  return createInvite(actorId, organizationId, branchId, 'PLAN_PURCHASE', planId, data);
}

async function findActiveInvite(rawToken: string) {
  const invite = await prisma.inviteToken.findUnique({
    where: { token_hash: hashInviteToken(rawToken) },
    include: inviteInclude,
  });
  if (!invite || invite.revoked_at || invite.expires_at <= new Date()) {
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
    select: { id: true, status: true },
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
  };
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
  } catch (error: any) {
    if (error?.code === 'P2002') {
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
    { isolationLevel: 'Serializable' },
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
