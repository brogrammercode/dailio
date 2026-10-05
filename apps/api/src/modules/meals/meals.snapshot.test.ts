import type { Prisma } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';

import { snapshotPlanWithMeals } from './meals.snapshot';

describe('subscription meal entitlement snapshot', () => {
  it('stores branch-specific active limits alongside commercial plan terms', async () => {
    const findMany = vi
      .fn()
      .mockResolvedValue([{ meal_slot_id: 'lunch', max_servings_per_day: 2 }]);
    const tx = { planMealEntitlement: { findMany } } as unknown as Prisma.TransactionClient;
    const snapshot = await snapshotPlanWithMeals(
      tx,
      {
        id: 'plan-1',
        amount_minor_unit: 150000,
        created_at: new Date('2026-10-01T00:00:00Z'),
        updated_at: new Date('2026-10-02T00:00:00Z'),
        metadata: null,
      },
      'org-1',
      'branch-1',
    );
    expect(findMany).toHaveBeenCalledWith({
      where: {
        organization_id: 'org-1',
        branch_id: 'branch-1',
        plan_id: 'plan-1',
        is_active: true,
      },
      select: { meal_slot_id: true, max_servings_per_day: true },
    });
    expect(snapshot).toMatchObject({
      amount_minor_unit: 150000,
      meal_entitlements: [{ meal_slot_id: 'lunch', max_servings_per_day: 2 }],
    });
  });
});
