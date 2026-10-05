import { Prisma } from '@prisma/client';
import { ulid } from 'ulid';

export const DEFAULT_MEAL_SLOTS = [
  { code: 'breakfast', name: 'Breakfast', starts_at_local: '07:00', ends_at_local: '10:00' },
  { code: 'lunch', name: 'Lunch', starts_at_local: '12:00', ends_at_local: '15:00' },
  { code: 'dinner', name: 'Dinner', starts_at_local: '19:00', ends_at_local: '22:00' },
] as const;

/**
 * Provision the initial meal windows for a food-service branch. This is
 * idempotent so organization-type changes and new-branch creation are safe
 * to retry.
 */
export async function ensureDefaultMealSlots(
  tx: Prisma.TransactionClient,
  organizationId: string,
  branchId: string,
) {
  await tx.mealSlot.createMany({
    data: DEFAULT_MEAL_SLOTS.map((slot) => ({
      id: ulid(),
      organization_id: organizationId,
      branch_id: branchId,
      ...slot,
    })),
    skipDuplicates: true,
  });
}
