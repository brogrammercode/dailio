import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  mealServing: {
    findUnique: vi.fn(),
    findMany: vi.fn(),
    count: vi.fn(),
    groupBy: vi.fn(),
    create: vi.fn(),
  },
  member: { findFirst: vi.fn() },
  mealSlot: { findFirst: vi.fn(), findMany: vi.fn() },
  branch: { findFirst: vi.fn() },
  subscription: { findMany: vi.fn() },
  auditLog: { create: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock('../../lib/prisma', () => ({ prisma: mocks }));

import { mealWindow, serveMeal, listMealServings, getMealSummary } from './meals.service';
import { servingLimitFromSnapshot } from './meals.snapshot';
import { MealSlotInputSchema, MealEntitlementInputSchema } from './meals.schema';

describe('meal policy', () => {
  it('uses the branch local day, including overnight meal windows', () => {
    expect(mealWindow(new Date('2026-10-02T19:00:00Z'), 'Asia/Kolkata', '22:00', '02:00')).toEqual({
      isOpen: true,
      date: '2026-10-02',
    });
    expect(mealWindow(new Date('2026-10-03T02:00:00Z'), 'Asia/Kolkata', '22:00', '02:00')).toEqual({
      isOpen: false,
      date: '2026-10-03',
    });
  });

  it('only accepts valid snapshotted entitlements, not current plan changes', () => {
    const snapshot = {
      meal_entitlements: [{ meal_slot_id: 'breakfast', max_servings_per_day: 2 }],
    };
    expect(servingLimitFromSnapshot(snapshot, 'breakfast')).toBe(2);
    expect(servingLimitFromSnapshot(snapshot, 'dinner')).toBe(0);
    expect(servingLimitFromSnapshot({}, 'breakfast')).toBe(0);
  });

  it('validates slot times and daily limits', () => {
    expect(() =>
      MealSlotInputSchema.parse({
        code: 'breakfast',
        name: 'Breakfast',
        starts_at_local: '25:00',
        ends_at_local: '10:00',
      }),
    ).toThrow();
    expect(() =>
      MealEntitlementInputSchema.parse({ meal_slot_id: 'slot', max_servings_per_day: 11 }),
    ).toThrow();
  });
});

describe('meal serving isolation and idempotency', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-02T12:00:00Z'));
    vi.clearAllMocks();
    mocks.$transaction.mockImplementation(async (fn: (tx: unknown) => Promise<unknown>) =>
      fn(mocks),
    );
    mocks.mealServing.findUnique.mockResolvedValue(null);
    mocks.mealServing.findMany.mockResolvedValue([]);
    mocks.mealServing.count.mockResolvedValue(0);
    mocks.mealServing.groupBy.mockResolvedValue([{ meal_slot_id: 'slot-1', _count: { _all: 3 } }]);
    mocks.mealSlot.findMany.mockResolvedValue([
      { id: 'slot-1', name: 'Breakfast', code: 'breakfast' },
    ]);
    mocks.member.findFirst.mockResolvedValue({ id: 'member-1' });
    mocks.mealSlot.findFirst.mockResolvedValue({
      id: 'slot-1',
      starts_at_local: '00:00',
      ends_at_local: '23:59',
    });
    mocks.branch.findFirst.mockResolvedValue({ timezone: 'Asia/Kolkata' });
    mocks.subscription.findMany.mockResolvedValue([
      {
        id: 'sub-1',
        start_date: new Date('2020-01-01T00:00:00Z'),
        end_date: new Date('2030-01-01T00:00:00Z'),
        plan_snapshot: { meal_entitlements: [{ meal_slot_id: 'slot-1', max_servings_per_day: 1 }] },
      },
    ]);
    mocks.mealServing.create.mockImplementation(async ({ data }: { data: unknown }) => data);
  });
  afterEach(() => vi.useRealTimers());

  it('summarizes confirmed meals only within the authorized member scope', async () => {
    const result = await getMealSummary('org', 'branch', 'member-1', new Set(['MEAL_READ_SELF']), {
      page: 1,
      limit: 30,
    });
    expect(result).toMatchObject({
      total: 3,
      member_id: 'member-1',
      slots: [{ name: 'Breakfast', count: 3 }],
    });
    expect(mocks.mealServing.groupBy).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organization_id: 'org',
          branch_id: 'branch',
          member_id: 'member-1',
          status: 'CONFIRMED',
        }),
      }),
    );
    await expect(
      getMealSummary('org', 'branch', 'member-1', new Set(['MEAL_READ_SELF']), {
        member_id: 'other-member',
        page: 1,
        limit: 30,
      }),
    ).rejects.toThrow('scope');
  });

  it('does not replay an idempotency key from another tenant', async () => {
    mocks.mealServing.findUnique.mockResolvedValue({
      organization_id: 'other-org',
      branch_id: 'other-branch',
      member_id: 'member-1',
      meal_slot_id: 'slot-1',
    });
    await expect(
      serveMeal('staff', 'org', 'branch', 'key', { member_id: 'member-1', meal_slot_id: 'slot-1' }),
    ).rejects.toThrow('another meal');
    expect(mocks.mealServing.create).not.toHaveBeenCalled();
  });

  it('rejects a member outside the active branch', async () => {
    mocks.member.findFirst.mockResolvedValue(null);
    await expect(
      serveMeal('staff', 'org', 'branch', 'key', {
        member_id: 'other-member',
        meal_slot_id: 'slot-1',
      }),
    ).rejects.toThrow('not found');
    expect(mocks.mealServing.create).not.toHaveBeenCalled();
  });

  it('rejects a second serving beyond the snapshotted daily limit', async () => {
    mocks.mealServing.count.mockResolvedValue(1);
    await expect(
      serveMeal('staff', 'org', 'branch', 'key', { member_id: 'member-1', meal_slot_id: 'slot-1' }),
    ).rejects.toThrow('already used');
    expect(mocks.mealServing.create).not.toHaveBeenCalled();
  });

  it('records a confirmed serving and audit event once', async () => {
    const result = await serveMeal('staff', 'org', 'branch', 'key', {
      member_id: 'member-1',
      meal_slot_id: 'slot-1',
    });
    expect(result).toMatchObject({
      organization_id: 'org',
      branch_id: 'branch',
      member_id: 'member-1',
      subscription_id: 'sub-1',
      serving_number: 1,
      idempotency_key: 'key',
    });
    expect(mocks.auditLog.create).toHaveBeenCalledOnce();
  });

  it('returns the original serving when a concurrent retry uses the same key', async () => {
    mocks.$transaction.mockRejectedValueOnce(Object.assign(new Error('unique'), { code: 'P2002' }));
    mocks.mealServing.findUnique.mockResolvedValue({
      id: 'served-1',
      organization_id: 'org',
      branch_id: 'branch',
      member_id: 'member-1',
      meal_slot_id: 'slot-1',
      served_by: 'staff',
    });
    await expect(
      serveMeal('staff', 'org', 'branch', 'key', { member_id: 'member-1', meal_slot_id: 'slot-1' }),
    ).resolves.toMatchObject({ id: 'served-1' });
    expect(mocks.mealServing.create).not.toHaveBeenCalled();
  });

  it('enforces self-only history without branch permission', async () => {
    await expect(
      listMealServings('org', 'branch', 'member-1', new Set(['MEAL_READ_SELF']), {
        member_id: 'member-2',
        page: 1,
        limit: 30,
      }),
    ).rejects.toThrow('scope is not permitted');
    expect(mocks.mealServing.findMany).not.toHaveBeenCalled();
  });
});
