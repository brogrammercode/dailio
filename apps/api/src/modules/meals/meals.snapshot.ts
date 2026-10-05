import type { Prisma } from '@prisma/client';

export async function snapshotPlanWithMeals(
  tx: Prisma.TransactionClient,
  plan: {
    id: string;
    created_at?: Date;
    updated_at?: Date;
    metadata?: Prisma.JsonValue;
    [key: string]: unknown;
  },
  organizationId: string,
  branchId: string,
): Promise<Prisma.InputJsonValue> {
  const entitlements = await tx.planMealEntitlement.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      plan_id: plan.id,
      is_active: true,
    },
    select: { meal_slot_id: true, max_servings_per_day: true },
  });
  return {
    ...plan,
    ...(plan.created_at ? { created_at: plan.created_at.toISOString() } : {}),
    ...(plan.updated_at ? { updated_at: plan.updated_at.toISOString() } : {}),
    metadata: (plan.metadata ?? null) as Prisma.InputJsonValue,
    meal_entitlements: entitlements,
  } as Prisma.InputJsonValue;
}

export function servingLimitFromSnapshot(snapshot: Prisma.JsonValue, slotId: string): number {
  if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) return 0;
  const entitlements = snapshot.meal_entitlements;
  if (!Array.isArray(entitlements)) return 0;
  const entitlement = entitlements.find(
    (item) =>
      item && typeof item === 'object' && !Array.isArray(item) && item.meal_slot_id === slotId,
  );
  if (!entitlement || typeof entitlement !== 'object' || Array.isArray(entitlement)) return 0;
  const limit = entitlement.max_servings_per_day;
  return typeof limit === 'number' && Number.isInteger(limit) && limit > 0 && limit <= 10
    ? limit
    : 0;
}
