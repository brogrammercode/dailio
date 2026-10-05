import { Prisma } from '@prisma/client';
import { ulid } from 'ulid';

import { ConflictError, ForbiddenError, NotFoundError, UnprocessableError } from '../../lib/errors';
import { prisma } from '../../lib/prisma';
import { findBranchRecipientUserIds, notify } from '../notifications/notifications.service';

import { servingLimitFromSnapshot } from './meals.snapshot';
import type {
  MealEntitlementInput,
  MealServeInput,
  MealServingQuery,
  MealSlotInput,
} from './meals.schema';

async function notifyMealEvent(input: Parameters<typeof notify>[0]) {
  try {
    await notify(input);
  } catch {
    // Notification delivery is auxiliary and must never undo a meal mutation.
  }
}

async function mealManagerRecipients(organizationId: string, branchId: string) {
  try {
    return await findBranchRecipientUserIds(organizationId, branchId, 'MEAL_MANAGE');
  } catch {
    return [];
  }
}

export function mealLocalClock(now: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const get = (key: string) => parts.find((part) => part.type === key)?.value ?? '00';
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    time: `${get('hour')}:${get('minute')}`,
  };
}

export function mealWindow(now: Date, timezone: string, start: string, end: string) {
  const local = mealLocalClock(now, timezone);
  const overnight = end < start;
  const isOpen = overnight
    ? local.time >= start || local.time < end
    : local.time >= start && local.time < end;
  let date = local.date;
  if (overnight && local.time < end) {
    const previous = new Date(`${date}T00:00:00.000Z`);
    previous.setUTCDate(previous.getUTCDate() - 1);
    date = previous.toISOString().slice(0, 10);
  }
  return { isOpen, date };
}

export async function listMealSlots(organizationId: string, branchId: string) {
  return prisma.mealSlot.findMany({
    where: { organization_id: organizationId, branch_id: branchId },
    orderBy: [{ starts_at_local: 'asc' }, { code: 'asc' }],
  });
}

export async function searchMealMembers(organizationId: string, branchId: string, query: string) {
  return prisma.member.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      status: 'ACTIVE',
      ...(query
        ? {
            OR: [
              { user: { name: { contains: query, mode: 'insensitive' } } },
              { member_number: { contains: query, mode: 'insensitive' } },
            ],
          }
        : {}),
    },
    select: { id: true, member_number: true, user: { select: { name: true, avatar_url: true } } },
    orderBy: { created_at: 'asc' },
    take: 30,
  });
}

export async function upsertMealSlot(
  actorId: string,
  organizationId: string,
  branchId: string,
  slotId: string | null,
  input: MealSlotInput,
) {
  try {
    const slot = await prisma.$transaction(async (tx) => {
      if (slotId) {
        const existing = await tx.mealSlot.findFirst({
          where: { id: slotId, organization_id: organizationId, branch_id: branchId },
        });
        if (!existing) throw new NotFoundError('Meal slot');
      }
      const slot = slotId
        ? await tx.mealSlot.update({ where: { id: slotId }, data: input })
        : await tx.mealSlot.create({
            data: { id: ulid(), organization_id: organizationId, branch_id: branchId, ...input },
          });
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          actor_id: actorId,
          action: slotId ? 'UPDATE' : 'CREATE',
          target_type: 'MealSlot',
          target_id: slot.id,
          after_state: {
            code: slot.code,
            name: slot.name,
            starts_at_local: slot.starts_at_local,
            ends_at_local: slot.ends_at_local,
            is_active: slot.is_active,
          },
        },
      });
      return slot;
    });
    await notifyMealEvent({
      type: slotId ? 'MEAL_SLOT_UPDATED' : 'MEAL_SLOT_CREATED',
      organizationId,
      branchId,
      actorUserId: actorId,
      entityType: 'MealSlot',
      entityId: slot.id,
      recipientUserIds: await mealManagerRecipients(organizationId, branchId),
      title: slotId ? 'Meal slot updated' : 'Meal slot created',
      body: `${slot.name} is ${slot.is_active ? 'active' : 'inactive'} for this branch.`,
      data: { organization_id: organizationId, branch_id: branchId, entity_id: slot.id },
      dedupeKey: `meal-slot:${slot.id}:${slot.updated_at.toISOString()}`,
    });
    return slot;
  } catch (error) {
    if ((error as { code?: string }).code === 'P2002')
      throw new ConflictError('A meal slot with this code already exists in this branch');
    throw error;
  }
}

export async function listEntitlements(organizationId: string, branchId: string, planId: string) {
  const plan = await prisma.plan.findFirst({
    where: {
      id: planId,
      organization_id: organizationId,
      OR: [{ branch_id: branchId }, { branch_id: null }],
    },
  });
  if (!plan) throw new NotFoundError('Plan');
  return prisma.planMealEntitlement.findMany({
    where: { organization_id: organizationId, branch_id: branchId, plan_id: planId },
    include: { meal_slot: { select: { name: true, code: true, is_active: true } } },
    orderBy: { created_at: 'asc' },
  });
}

export async function setEntitlement(
  actorId: string,
  organizationId: string,
  branchId: string,
  planId: string,
  input: MealEntitlementInput & { is_active: boolean },
) {
  const entitlement = await prisma.$transaction(async (tx) => {
    const [plan, slot] = await Promise.all([
      tx.plan.findFirst({
        where: {
          id: planId,
          organization_id: organizationId,
          OR: [{ branch_id: branchId }, { branch_id: null }],
        },
      }),
      tx.mealSlot.findFirst({
        where: { id: input.meal_slot_id, organization_id: organizationId, branch_id: branchId },
      }),
    ]);
    if (!plan) throw new NotFoundError('Plan');
    if (!slot) throw new NotFoundError('Meal slot');
    const entitlement = await tx.planMealEntitlement.upsert({
      where: {
        organization_id_branch_id_plan_id_meal_slot_id: {
          organization_id: organizationId,
          branch_id: branchId,
          plan_id: planId,
          meal_slot_id: slot.id,
        },
      },
      create: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        plan_id: planId,
        meal_slot_id: slot.id,
        max_servings_per_day: input.max_servings_per_day,
        is_active: input.is_active,
      },
      update: { max_servings_per_day: input.max_servings_per_day, is_active: input.is_active },
    });
    // Meal access is an operational entitlement, not a financial plan term.
    // Keep price/dates immutable while syncing the meal portion for
    // subscriptions that can still be used.
    const mealEntitlements = await tx.planMealEntitlement.findMany({
      where: {
        organization_id: organizationId,
        branch_id: branchId,
        plan_id: planId,
        is_active: true,
      },
      select: { meal_slot_id: true, max_servings_per_day: true },
    });
    const subscriptions = await tx.subscription.findMany({
      where: {
        organization_id: organizationId,
        branch_id: branchId,
        plan_id: planId,
        status: { in: ['DRAFT', 'UPCOMING', 'ACTIVE', 'PAUSED'] },
      },
      select: { id: true, plan_snapshot: true },
    });
    for (const subscription of subscriptions) {
      const snapshot =
        subscription.plan_snapshot &&
        typeof subscription.plan_snapshot === 'object' &&
        !Array.isArray(subscription.plan_snapshot)
          ? subscription.plan_snapshot
          : {};
      await tx.subscription.update({
        where: { id: subscription.id },
        data: {
          plan_snapshot: {
            ...(snapshot as Prisma.JsonObject),
            meal_entitlements: mealEntitlements,
          } as Prisma.InputJsonValue,
        },
      });
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          actor_id: actorId,
          action: 'UPDATE',
          target_type: 'Subscription',
          target_id: subscription.id,
          before_state: {
            meal_entitlements:
              (snapshot as Prisma.JsonObject).meal_entitlements ?? null,
          },
          after_state: { meal_entitlements: mealEntitlements },
          reason: 'Meal entitlement configuration synchronized',
          source: 'API',
        },
      });
    }
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorId,
        action: 'UPDATE',
        target_type: 'PlanMealEntitlement',
        target_id: entitlement.id,
        after_state: {
          plan_id: planId,
          meal_slot_id: slot.id,
          max_servings_per_day: input.max_servings_per_day,
          is_active: input.is_active,
          synchronized_subscription_ids: subscriptions.map((subscription) => subscription.id),
        },
      },
    });
    return { ...entitlement, synchronized_subscription_count: subscriptions.length };
  });
  await notifyMealEvent({
    type: 'MEAL_ENTITLEMENT_UPDATED',
    organizationId,
    branchId,
    actorUserId: actorId,
    entityType: 'PlanMealEntitlement',
    entityId: entitlement.id,
    recipientUserIds: await mealManagerRecipients(organizationId, branchId),
    title: 'Meal entitlement updated',
    body: `A plan meal entitlement was ${entitlement.is_active ? 'enabled' : 'disabled'}.`,
    data: { organization_id: organizationId, branch_id: branchId, entity_id: entitlement.id },
    dedupeKey: `meal-entitlement:${entitlement.id}:${entitlement.updated_at.toISOString()}`,
  });
  return entitlement;
}

async function resolveMealEligibility(
  tx: Prisma.TransactionClient,
  organizationId: string,
  branchId: string,
  memberId: string,
  slotId: string,
  now: Date,
) {
  const [member, slot, branch] = await Promise.all([
    tx.member.findFirst({
      where: {
        id: memberId,
        organization_id: organizationId,
        branch_id: branchId,
        status: 'ACTIVE',
      },
    }),
    tx.mealSlot.findFirst({
      where: { id: slotId, organization_id: organizationId, branch_id: branchId, is_active: true },
    }),
    tx.branch.findFirst({
      where: { id: branchId, organization_id: organizationId, status: 'ACTIVE' },
      select: { timezone: true },
    }),
  ]);
  if (!member) throw new NotFoundError('Active member');
  if (!slot || !branch) throw new NotFoundError('Active meal slot');
  const window = mealWindow(now, branch.timezone, slot.starts_at_local, slot.ends_at_local);
  const subscriptions = await tx.subscription.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      member_id: memberId,
      status: 'ACTIVE',
    },
    orderBy: { start_date: 'desc' },
  });
  const subscription = subscriptions.find(
    (item) =>
      item.start_date.toISOString().slice(0, 10) <= window.date &&
      item.end_date.toISOString().slice(0, 10) > window.date &&
      servingLimitFromSnapshot(item.plan_snapshot, slotId) > 0,
  );
  const limit = subscription ? servingLimitFromSnapshot(subscription.plan_snapshot, slotId) : 0;
  const date = new Date(`${window.date}T00:00:00.000Z`);
  const served = await tx.mealServing.count({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      member_id: memberId,
      meal_slot_id: slotId,
      local_date: date,
      status: 'CONFIRMED',
    },
  });
  return { member, slot, subscription, limit, served, date, window };
}

export async function getMealEligibility(
  organizationId: string,
  branchId: string,
  memberId: string,
  slotId: string,
) {
  return prisma.$transaction(async (tx) => {
    const result = await resolveMealEligibility(
      tx,
      organizationId,
      branchId,
      memberId,
      slotId,
      new Date(),
    );
    return {
      meal_slot_id: slotId,
      member_id: memberId,
      local_date: result.window.date,
      window_open: result.window.isOpen,
      entitled: result.limit > 0,
      max_servings_per_day: result.limit,
      served_count: result.served,
      remaining: Math.max(result.limit - result.served, 0),
      eligible: result.window.isOpen && result.limit > result.served,
    };
  });
}

export async function serveMeal(
  actorId: string,
  organizationId: string,
  branchId: string,
  idempotencyKey: string,
  input: MealServeInput,
) {
  let serving;
  try {
    serving = await prisma.$transaction(
      async (tx) => {
        const existing = await tx.mealServing.findUnique({
          where: { idempotency_key: idempotencyKey },
        });
        if (existing) {
          if (
            existing.organization_id !== organizationId ||
            existing.branch_id !== branchId ||
            existing.member_id !== input.member_id ||
            existing.meal_slot_id !== input.meal_slot_id ||
            existing.served_by !== actorId
          )
            throw new ConflictError('Idempotency key was already used for another meal');
          return existing;
        }
        const result = await resolveMealEligibility(
          tx,
          organizationId,
          branchId,
          input.member_id,
          input.meal_slot_id,
          new Date(),
        );
        if (!result.window.isOpen) throw new ConflictError('This meal slot is not open now');
        if (!result.subscription)
          throw new ForbiddenError('No active subscription includes this meal');
        if (result.served >= result.limit)
          throw new ConflictError('Daily meal entitlement is already used');
        const used = await tx.mealServing.findMany({
          where: {
            organization_id: organizationId,
            branch_id: branchId,
            member_id: input.member_id,
            meal_slot_id: input.meal_slot_id,
            local_date: result.date,
            status: 'CONFIRMED',
          },
          select: { serving_number: true },
        });
        const usedNumbers = new Set(used.map((item) => item.serving_number));
        let servingNumber = 1;
        while (usedNumbers.has(servingNumber)) servingNumber++;
        const serving = await tx.mealServing.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            member_id: input.member_id,
            subscription_id: result.subscription.id,
            meal_slot_id: input.meal_slot_id,
            local_date: result.date,
            serving_number: servingNumber,
            served_by: actorId,
            idempotency_key: idempotencyKey,
          },
        });
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            actor_id: actorId,
            action: 'SERVE',
            target_type: 'MealServing',
            target_id: serving.id,
            after_state: {
              member_id: input.member_id,
              meal_slot_id: input.meal_slot_id,
              local_date: result.window.date,
              serving_number: servingNumber,
            },
          },
        });
        return serving;
      },
      { isolationLevel: 'Serializable', maxWait: 10_000, timeout: 30_000 },
    );
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code !== 'P2002' && code !== 'P2034') throw error;
    const prior = await prisma.mealServing.findUnique({
      where: { idempotency_key: idempotencyKey },
    });
    if (prior) {
      if (
        prior.organization_id !== organizationId ||
        prior.branch_id !== branchId ||
        prior.member_id !== input.member_id ||
        prior.meal_slot_id !== input.meal_slot_id ||
        prior.served_by !== actorId
      )
        throw new ConflictError('Idempotency key was already used for another meal');
      serving = prior;
    } else {
      throw new ConflictError('Meal serving changed concurrently. Refresh and try again');
    }
  }
  let details = null;
  try {
    details = await prisma.mealServing.findFirst({
      where: { id: serving.id, organization_id: organizationId, branch_id: branchId },
      select: {
        id: true,
        local_date: true,
        member: { select: { user_id: true } },
        meal_slot: { select: { name: true } },
      },
    });
  } catch {
    // Notification enrichment is best effort.
  }
  if (details) {
    await notifyMealEvent({
      type: 'MEAL_SERVING_CONFIRMED',
      organizationId,
      branchId,
      actorUserId: actorId,
      entityType: 'MealServing',
      entityId: details.id,
      recipientUserIds: [details.member.user_id],
      title: 'Meal attendance recorded',
      body: `${details.meal_slot.name} attendance was recorded for ${details.local_date.toISOString().slice(0, 10)}.`,
      data: {
        organization_id: organizationId,
        branch_id: branchId,
        entity_id: details.id,
      },
      dedupeKey: `meal-serving:${details.id}:confirmed`,
    });
  }
  return serving;
}

export async function voidMeal(
  actorId: string,
  organizationId: string,
  branchId: string,
  servingId: string,
  reason: string,
) {
  let updated;
  try {
    updated = await prisma.$transaction(
      async (tx) => {
        const serving = await tx.mealServing.findFirst({
          where: {
            id: servingId,
            organization_id: organizationId,
            branch_id: branchId,
          },
        });
        if (!serving) throw new NotFoundError('Meal serving');
        if (serving.status === 'VOID') {
          if (serving.voided_by === actorId && serving.void_reason === reason) return serving;
          throw new ConflictError('Meal serving is already void');
        }
        const updated = await tx.mealServing.update({
          where: { id: serving.id },
          data: {
            status: 'VOID',
            voided_at: new Date(),
            voided_by: actorId,
            void_reason: reason,
          },
        });
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            actor_id: actorId,
            action: 'VOID',
            target_type: 'MealServing',
            target_id: serving.id,
            reason,
            before_state: { status: serving.status },
            after_state: { status: 'VOID' },
          },
        });
        return updated;
      },
      { isolationLevel: 'Serializable' },
    );
  } catch (error) {
    if ((error as { code?: string }).code === 'P2034')
      throw new ConflictError('Meal serving changed concurrently. Refresh and try again');
    throw error;
  }
  let details = null;
  try {
    details = await prisma.mealServing.findFirst({
      where: { id: updated.id, organization_id: organizationId, branch_id: branchId },
      select: {
        id: true,
        member: { select: { user_id: true } },
        meal_slot: { select: { name: true } },
      },
    });
  } catch {
    // Notification enrichment is best effort.
  }
  if (details) {
    await notifyMealEvent({
      type: 'MEAL_SERVING_VOIDED',
      organizationId,
      branchId,
      actorUserId: actorId,
      entityType: 'MealServing',
      entityId: details.id,
      recipientUserIds: [details.member.user_id],
      title: 'Meal attendance updated',
      body: `${details.meal_slot.name} attendance was voided.`,
      data: {
        organization_id: organizationId,
        branch_id: branchId,
        entity_id: details.id,
      },
      dedupeKey: `meal-serving:${details.id}:voided`,
    });
  }
  return updated;
}

export async function listMealServings(
  organizationId: string,
  branchId: string,
  actorMemberId: string,
  permissions: Set<string>,
  query: MealServingQuery,
) {
  const canReadAll = permissions.has('ALL') || permissions.has('MEAL_READ_BRANCH');
  if (!canReadAll && query.member_id && query.member_id !== actorMemberId)
    throw new ForbiddenError('Meal serving scope is not permitted');
  if (query.from && query.to && query.from > query.to)
    throw new UnprocessableError('Meal date range is invalid');
  if (query.from && query.to && Date.parse(query.to) - Date.parse(query.from) > 90 * 86_400_000)
    throw new UnprocessableError('Meal date range may not exceed 90 days');
  const where: Prisma.MealServingWhereInput = {
    organization_id: organizationId,
    branch_id: branchId,
    ...(canReadAll && !query.member_id ? {} : { member_id: query.member_id ?? actorMemberId }),
    ...(query.from || query.to
      ? {
          local_date: {
            ...(query.from ? { gte: new Date(`${query.from}T00:00:00.000Z`) } : {}),
            ...(query.to ? { lte: new Date(`${query.to}T00:00:00.000Z`) } : {}),
          },
        }
      : {}),
  };
  const [data, total] = await Promise.all([
    prisma.mealServing.findMany({
      where,
      include: {
        meal_slot: { select: { code: true, name: true } },
        member: { select: { user: { select: { name: true } }, member_number: true } },
      },
      orderBy: [{ served_at: 'desc' }, { id: 'desc' }],
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.mealServing.count({ where }),
  ]);
  return { data, meta: { total, page: query.page, limit: query.limit } };
}

export async function getMealSummary(
  organizationId: string,
  branchId: string,
  actorMemberId: string,
  permissions: Set<string>,
  query: MealServingQuery,
) {
  const canReadAll = permissions.has('ALL') || permissions.has('MEAL_READ_BRANCH');
  if (!canReadAll && query.member_id && query.member_id !== actorMemberId)
    throw new ForbiddenError('Meal serving scope is not permitted');
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, organization_id: organizationId },
    select: { timezone: true },
  });
  if (!branch) throw new NotFoundError('Branch');
  const today = mealLocalClock(new Date(), branch.timezone).date;
  const fromDefault = new Date(`${today}T00:00:00.000Z`);
  fromDefault.setUTCDate(fromDefault.getUTCDate() - 29);
  const from = query.from ?? fromDefault.toISOString().slice(0, 10);
  const to = query.to ?? today;
  if (from > to || Date.parse(to) - Date.parse(from) > 90 * 86_400_000)
    throw new UnprocessableError('Meal summary range must be 90 days or less');
  const rows = await prisma.mealServing.groupBy({
    by: ['meal_slot_id'],
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      member_id: canReadAll ? (query.member_id ?? undefined) : actorMemberId,
      status: 'CONFIRMED',
      local_date: { gte: new Date(`${from}T00:00:00.000Z`), lte: new Date(`${to}T00:00:00.000Z`) },
    },
    _count: { _all: true },
  });
  const slots = await prisma.mealSlot.findMany({
    where: { organization_id: organizationId, branch_id: branchId },
    select: { id: true, name: true, code: true },
  });
  const counts = new Map(rows.map((row) => [row.meal_slot_id, row._count._all]));
  return {
    from,
    to,
    member_id: canReadAll ? (query.member_id ?? null) : actorMemberId,
    total: rows.reduce((sum, row) => sum + row._count._all, 0),
    slots: slots.map((slot) => ({
      meal_slot_id: slot.id,
      name: slot.name,
      code: slot.code,
      count: counts.get(slot.id) ?? 0,
    })),
  };
}
