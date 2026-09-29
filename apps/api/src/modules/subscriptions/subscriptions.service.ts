import type { Prisma } from '@prisma/client';
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { AppError, ConflictError, NotFoundError, UnprocessableError } from '../../lib/errors';
import { notify } from '../notifications/notifications.service';

import type {
  AssignSubscriptionInput,
  CancelSubscriptionInput,
  RenewSubscriptionInput,
  SubscriptionTransitionInput,
  UpdateSubscriptionInput,
} from './subscriptions.schema';

async function notifySubscriptionMember(
  organization_id: string,
  branch_id: string,
  member_id: string,
  subscription_id: string,
  type: string,
  title: string,
  body: string,
  dedupeKey: string,
) {
  try {
    const member = await prisma.member.findFirst({
      where: { id: member_id, organization_id, branch_id },
      select: { user_id: true },
    });
    if (!member) return;
    await notify({
      type,
      organizationId: organization_id,
      branchId: branch_id,
      entityType: 'Subscription',
      entityId: subscription_id,
      recipientUserIds: [member.user_id],
      title,
      body,
      data: { organization_id, branch_id, entity_id: subscription_id },
      dedupeKey,
    });
  } catch {
    // Notification delivery must not undo a committed subscription transition.
  }
}

export function calculateSubscriptionEndDate(startDate: Date, durationDays: number) {
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + durationDays);
  return endDate;
}

export async function assignSubscription(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  member_id: string,
  idempotency_key: string,
  data: AssignSubscriptionInput,
) {
  const existing = await prisma.subscription.findUnique({ where: { idempotency_key } });
  if (existing) {
    if (
      existing.organization_id !== organization_id ||
      existing.branch_id !== branch_id ||
      existing.member_id !== member_id
    ) {
      throw new ConflictError('Idempotency key is already used for another subscription');
    }
    return existing;
  }
  const assigned = await prisma.$transaction(
    async (tx) => {
      // 1. Verify Member
      const member = await tx.member.findUnique({
        where: { id: member_id },
      });
      if (!member || member.organization_id !== organization_id || member.branch_id !== branch_id) {
        throw new NotFoundError('Member');
      }

      // 2. Verify Plan
      const plan = await tx.plan.findUnique({
        where: { id: data.plan_id },
      });
      if (
        !plan ||
        plan.organization_id !== organization_id ||
        (plan.branch_id !== null && plan.branch_id !== branch_id)
      ) {
        throw new NotFoundError('Plan');
      }
      if (!plan.is_active) {
        throw new AppError(400, 'BAD_REQUEST', 'Cannot assign an inactive plan.');
      }

      // 3. Calculate Dates & Amounts
      const startDate = new Date(data.start_date);
      if (Number.isNaN(startDate.valueOf()))
        throw new UnprocessableError('Subscription start date is invalid');
      const endDate = calculateSubscriptionEndDate(startDate, plan.duration_days);
      const dueDate = calculateSubscriptionEndDate(startDate, plan.grace_days);

      const agreedAmount = data.agreed_amount_minor ?? plan.amount_minor_unit;
      const discount = data.discount_minor ?? 0;
      if (agreedAmount !== plan.amount_minor_unit) {
        throw new UnprocessableError('Subscription price must match the active plan price');
      }
      if (discount >= agreedAmount + plan.joining_fee_minor) {
        throw new UnprocessableError('Discount cannot consume the full subscription amount');
      }

      const overlap = await tx.subscription.findFirst({
        where: {
          organization_id,
          branch_id,
          member_id,
          status: { in: ['DRAFT', 'UPCOMING', 'ACTIVE', 'PAUSED'] },
          start_date: { lte: endDate },
          end_date: { gte: startDate },
        },
      });
      if (overlap) throw new ConflictError('Member already has an overlapping subscription');

      const subscriptionId = ulid();

      // 4. Create Subscription
      const subscription = await tx.subscription.create({
        data: {
          id: subscriptionId,
          organization_id,
          branch_id,
          member_id,
          plan_id: plan.id,
          plan_snapshot: plan as unknown as Prisma.InputJsonValue,
          status: 'ACTIVE',
          start_date: startDate,
          end_date: endDate,
          agreed_amount_minor: agreedAmount,
          discount_minor: discount,
          currency: plan.currency,
          created_by: actor_id,
          idempotency_key,
          due_date: dueDate,
        },
      });

      // 5. Create Ledger Entries
      // 5a. Subscription Charge (Debit)
      await tx.ledgerEntry.create({
        data: {
          id: ulid(),
          organization_id,
          branch_id,
          member_id,
          subscription_id: subscriptionId,
          category: 'SUBSCRIPTION_CHARGE',
          amount_minor_unit: agreedAmount, // Owed by member
          currency: plan.currency,
          description: `Subscription Charge: ${plan.name}`,
          created_by: actor_id,
        },
      });

      // 5b. Joining Fee (Debit) if applicable
      if (plan.joining_fee_minor > 0) {
        await tx.ledgerEntry.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            member_id,
            subscription_id: subscriptionId,
            category: 'JOINING_FEE',
            amount_minor_unit: plan.joining_fee_minor,
            currency: plan.currency,
            description: `Joining Fee: ${plan.name}`,
            created_by: actor_id,
          },
        });
      }

      // 5c. Discount (Credit) if applicable
      if (discount > 0) {
        await tx.ledgerEntry.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            member_id,
            subscription_id: subscriptionId,
            category: 'DISCOUNT_CREDIT',
            amount_minor_unit: -discount, // Credit to member reduces balance
            currency: plan.currency,
            description: `Discount: ${plan.name}`,
            created_by: actor_id,
          },
        });
      }

      // 6. Update Member's active subscription ID
      await tx.member.update({
        where: { id: member_id },
        data: { subscription_id: subscriptionId, updated_at: new Date() },
      });

      // 7. Audit Log
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id,
          branch_id,
          actor_id,
          action: 'ASSIGN',
          target_type: 'Subscription',
          target_id: subscriptionId,
          after_state: subscription as unknown as Prisma.InputJsonValue,
        },
      });

      return subscription;
    },
    { isolationLevel: 'Serializable' },
  );

  await notifySubscriptionMember(
    organization_id,
    branch_id,
    member_id,
    assigned.id,
    'SUBSCRIPTION_ASSIGNED',
    'Subscription activated',
    'A subscription has been assigned to your account.',
    `subscription:${assigned.id}:assigned`,
  );
  return assigned;
}

export async function listSubscriptions(
  organization_id: string,
  branch_id: string,
  member_id?: string,
  canReadAll = false,
) {
  return await prisma.subscription.findMany({
    where: { organization_id, branch_id, ...(canReadAll ? {} : { member_id }) },
    include: {
      member: {
        include: { user: true },
      },
      plan: true,
    },
    orderBy: { created_at: 'desc' },
  });
}

export async function getSubscriptionDetail(
  organization_id: string,
  branch_id: string,
  subscription_id: string,
  viewer_member_id?: string,
  canReadAll = false,
) {
  const subscription = await prisma.subscription.findUnique({
    where: { id: subscription_id },
    include: {
      member: { include: { user: true } },
      plan: true,
      ledger_entries: {
        include: { allocations: { include: { payment_attempt: { include: { receipt: true } } } } },
        orderBy: { created_at: 'desc' },
      },
      payment_requests: {
        include: { evidence: true, payment_attempt: { include: { receipt: true } } },
        orderBy: { created_at: 'desc' },
      },
    },
  });

  if (
    !subscription ||
    subscription.organization_id !== organization_id ||
    subscription.branch_id !== branch_id
  ) {
    throw new NotFoundError('Subscription');
  }
  if (!canReadAll && subscription.member_id !== viewer_member_id)
    throw new NotFoundError('Subscription');

  return subscription;
}

export async function updateSubscription(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  subscription_id: string,
  data: UpdateSubscriptionInput,
) {
  const updated = await prisma.$transaction(async (tx) => {
    const subscription = await tx.subscription.findUnique({
      where: { id: subscription_id },
    });

    if (
      !subscription ||
      subscription.organization_id !== organization_id ||
      subscription.branch_id !== branch_id
    ) {
      throw new NotFoundError('Subscription');
    }

    const updated = await tx.subscription.update({
      where: { id: subscription_id },
      data: {
        end_date: data.end_date ? new Date(data.end_date) : undefined,
        updated_at: new Date(),
      },
    });

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'Subscription',
        target_id: subscription_id,
        before_state: subscription as unknown as Prisma.InputJsonValue,
        after_state: updated as unknown as Prisma.InputJsonValue,
      },
    });

    return updated;
  });
  await notifySubscriptionMember(
    organization_id,
    branch_id,
    updated.member_id,
    updated.id,
    'SUBSCRIPTION_UPDATED',
    'Subscription updated',
    'Your subscription coverage details have been updated.',
    `subscription:${updated.id}:updated:${updated.updated_at.toISOString()}`,
  );
  return updated;
}

export async function cancelSubscription(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  subscription_id: string,
  data: CancelSubscriptionInput,
) {
  const updated = await prisma.$transaction(async (tx) => {
    const subscription = await tx.subscription.findFirst({
      where: { id: subscription_id, organization_id, branch_id },
    });
    if (!subscription) throw new NotFoundError('Subscription');
    if (['CANCELLED', 'EXPIRED'].includes(subscription.status))
      throw new ConflictError('Subscription is already closed');
    const updated = await tx.subscription.update({
      where: { id: subscription.id },
      data: {
        status: 'CANCELLED',
        cancelled_at: new Date(),
        cancelled_by: actor_id,
        cancel_reason: data.reason,
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'CANCEL',
        target_type: 'Subscription',
        target_id: subscription.id,
        reason: data.reason,
        before_state: subscription as unknown as Prisma.InputJsonValue,
        after_state: updated as unknown as Prisma.InputJsonValue,
      },
    });
    return updated;
  });
  await notifySubscriptionMember(
    organization_id,
    branch_id,
    updated.member_id,
    updated.id,
    'SUBSCRIPTION_CANCELLED',
    'Subscription cancelled',
    data.reason
      ? `Your subscription was cancelled: ${data.reason}`
      : 'Your subscription was cancelled.',
    `subscription:${updated.id}:cancelled:${updated.updated_at.toISOString()}`,
  );
  return updated;
}

async function transitionSubscription(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  subscription_id: string,
  targetStatus: 'PAUSED' | 'ACTIVE',
  data: SubscriptionTransitionInput,
) {
  const updated = await prisma.$transaction(async (tx) => {
    const subscription = await tx.subscription.findFirst({
      where: { id: subscription_id, organization_id, branch_id },
    });
    if (!subscription) throw new NotFoundError('Subscription');
    const allowed =
      targetStatus === 'PAUSED'
        ? subscription.status === 'ACTIVE'
        : subscription.status === 'PAUSED';
    if (!allowed)
      throw new ConflictError(
        `Subscription cannot transition from ${subscription.status} to ${targetStatus}`,
      );
    const updated = await tx.subscription.update({
      where: { id: subscription.id },
      data:
        targetStatus === 'PAUSED'
          ? { status: 'PAUSED', paused_at: new Date(), paused_by: actor_id }
          : { status: 'ACTIVE', paused_at: null, paused_by: null },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: targetStatus === 'PAUSED' ? 'PAUSE' : 'RESUME',
        target_type: 'Subscription',
        target_id: subscription.id,
        reason: data.reason,
        before_state: subscription as unknown as Prisma.InputJsonValue,
        after_state: updated as unknown as Prisma.InputJsonValue,
      },
    });
    return updated;
  });
  await notifySubscriptionMember(
    organization_id,
    branch_id,
    updated.member_id,
    updated.id,
    targetStatus === 'PAUSED' ? 'SUBSCRIPTION_PAUSED' : 'SUBSCRIPTION_RESUMED',
    targetStatus === 'PAUSED' ? 'Subscription paused' : 'Subscription resumed',
    targetStatus === 'PAUSED'
      ? data.reason
        ? `Your subscription was paused: ${data.reason}`
        : 'Your subscription was paused.'
      : 'Your subscription is active again.',
    `subscription:${updated.id}:${targetStatus.toLowerCase()}:${updated.updated_at.toISOString()}`,
  );
  return updated;
}

export function pauseSubscription(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  subscription_id: string,
  data: SubscriptionTransitionInput,
) {
  return transitionSubscription(
    actor_id,
    organization_id,
    branch_id,
    subscription_id,
    'PAUSED',
    data,
  );
}

export function resumeSubscription(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  subscription_id: string,
  data: SubscriptionTransitionInput,
) {
  return transitionSubscription(
    actor_id,
    organization_id,
    branch_id,
    subscription_id,
    'ACTIVE',
    data,
  );
}

export async function renewSubscription(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  subscription_id: string,
  idempotency_key: string,
  data: RenewSubscriptionInput,
) {
  const source = await prisma.subscription.findFirst({
    where: { id: subscription_id, organization_id, branch_id },
    include: { plan: true },
  });
  if (!source) throw new NotFoundError('Subscription');
  if (source.status === 'CANCELLED')
    throw new ConflictError('Cancelled subscriptions cannot be renewed');
  const startDate = new Date(data.start_date);
  if (startDate <= source.end_date)
    throw new ConflictError('Renewal must start after the existing coverage ends');
  const renewed = await assignSubscription(
    actor_id,
    organization_id,
    branch_id,
    source.member_id,
    idempotency_key,
    { plan_id: source.plan_id, start_date: data.start_date },
  );
  const updatedRenewal = await prisma.$transaction(async (tx) => {
    const updated = await tx.subscription.update({
      where: { id: renewed.id },
      data: { renewed_from_id: source.id },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'RENEW',
        target_type: 'Subscription',
        target_id: renewed.id,
        after_state: updated as unknown as Prisma.InputJsonValue,
        reason: `Renewed from ${source.id}`,
      },
    });
    return updated;
  });

  await notifySubscriptionMember(
    organization_id,
    branch_id,
    source.member_id,
    updatedRenewal.id,
    'SUBSCRIPTION_RENEWED',
    'Subscription renewed',
    'Your subscription has been renewed successfully.',
    `subscription:${updatedRenewal.id}:renewed`,
  );
  return updatedRenewal;
}
