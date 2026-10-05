import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  financialAdjustment: {
    findUnique: vi.fn(),
    findFirst: vi.fn(),
    findMany: vi.fn(),
    count: vi.fn(),
    create: vi.fn(),
  },
  subscription: { findFirst: vi.fn() },
  ledgerEntry: { findMany: vi.fn(), findFirst: vi.fn(), create: vi.fn() },
  auditLog: { create: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock('../../lib/prisma', () => ({ prisma: mocks }));

import {
  createSettlementWaiver,
  listSettlementWaivers,
  reverseSettlementWaiver,
} from './payments.service';
import { SettlementWaiverSchema } from './payments.schema';

describe('negotiated settlement waiver', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.$transaction.mockImplementation(async (fn: (tx: unknown) => Promise<unknown>) =>
      fn(mocks),
    );
    mocks.financialAdjustment.findUnique.mockResolvedValue(null);
    mocks.financialAdjustment.findFirst.mockResolvedValue(null);
    mocks.financialAdjustment.findMany.mockResolvedValue([]);
    mocks.financialAdjustment.count.mockResolvedValue(0);
    mocks.subscription.findFirst.mockResolvedValue({
      id: 'sub-1',
      member_id: 'member-1',
      currency: 'INR',
      status: 'ACTIVE',
    });
    mocks.ledgerEntry.findMany.mockResolvedValue([
      { amount_minor_unit: 250000, allocations: [] },
      { amount_minor_unit: -220000, allocations: [] },
    ]);
    mocks.ledgerEntry.findFirst.mockResolvedValue(null);
    mocks.ledgerEntry.create.mockResolvedValue({ id: 'ledger-1' });
    mocks.financialAdjustment.create.mockImplementation(
      async ({ data }: { data: unknown }) => data,
    );
  });

  it('reverses a waiver with a new debit and audit reason without editing the original credit', async () => {
    mocks.financialAdjustment.findFirst.mockResolvedValue({
      id: 'waiver-1',
      ledger_entry_id: 'credit-1',
      member_id: 'member-1',
      amount_minor_unit: 30000,
      currency: 'INR',
    });
    const entry = await reverseSettlementWaiver(
      'owner',
      'org',
      'branch',
      'sub-1',
      'waiver-1',
      'reverse-key',
      'Correction after review',
    );
    expect(entry).toMatchObject({ id: 'ledger-1' });
    expect(mocks.ledgerEntry.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        category: 'VOID_REVERSAL',
        amount_minor_unit: 30000,
        reversed_by_id: 'credit-1',
        idempotency_key: 'settlement-waiver-reversal:reverse-key',
      }),
    });
    expect(mocks.auditLog.create).toHaveBeenCalledOnce();
  });

  it('does not expose another tenant waiver through the history endpoint', async () => {
    mocks.subscription.findFirst.mockResolvedValue(null);
    await expect(
      listSettlementWaivers('org', 'branch', 'sub-1', 'member-1', new Set(['PAYMENT_READ_SELF']), {
        page: 1,
        limit: 20,
      }),
    ).rejects.toThrow('not found');
    expect(mocks.financialAdjustment.findMany).not.toHaveBeenCalled();
  });

  it('does not reverse another tenant waiver', async () => {
    await expect(
      reverseSettlementWaiver(
        'owner',
        'org',
        'branch',
        'sub-1',
        'foreign-waiver',
        'key',
        'Correction after review',
      ),
    ).rejects.toThrow('not found');
    expect(mocks.ledgerEntry.create).not.toHaveBeenCalled();
  });

  it('rejects a second reversal with a different key', async () => {
    mocks.financialAdjustment.findFirst.mockResolvedValue({
      id: 'waiver-1',
      ledger_entry_id: 'credit-1',
      member_id: 'member-1',
      amount_minor_unit: 30000,
      currency: 'INR',
    });
    mocks.ledgerEntry.findFirst.mockResolvedValue({
      id: 'prior-reversal',
      idempotency_key: 'other-key',
      description: 'Waiver reversal: Other correction',
      created_by: 'owner',
    });
    await expect(
      reverseSettlementWaiver(
        'owner',
        'org',
        'branch',
        'sub-1',
        'waiver-1',
        'new-key',
        'Correction after review',
      ),
    ).rejects.toThrow('already been reversed');
    expect(mocks.ledgerEntry.create).not.toHaveBeenCalled();
  });

  it('rejects missing reason and nonpositive money at the boundary', () => {
    expect(() =>
      SettlementWaiverSchema.parse({ amount_minor_unit: 30000, reason: 'short' }),
    ).toThrow();
    expect(() =>
      SettlementWaiverSchema.parse({ amount_minor_unit: 0, reason: 'Negotiated final settlement' }),
    ).toThrow();
    expect(() => SettlementWaiverSchema.parse({
      amount_minor_unit: 2_147_483_648, reason: 'Negotiated final settlement',
    })).toThrow();
  });

  it('cannot waive more than the server-derived due', async () => {
    await expect(
      createSettlementWaiver('owner', 'org', 'branch', 'sub-1', 'key', {
        amount_minor_unit: 30001,
        reason: 'Negotiated final settlement',
      }),
    ).rejects.toThrow('exceeds');
    expect(mocks.ledgerEntry.create).not.toHaveBeenCalled();
  });

  it('cannot use a subscription from another tenant', async () => {
    mocks.subscription.findFirst.mockResolvedValue(null);
    await expect(
      createSettlementWaiver('owner', 'org', 'branch', 'sub-1', 'key', {
        amount_minor_unit: 30000,
        reason: 'Negotiated final settlement',
      }),
    ).rejects.toThrow('not found');
    expect(mocks.ledgerEntry.create).not.toHaveBeenCalled();
  });

  it('posts a separate credit and audit event without changing the charge', async () => {
    const waiver = await createSettlementWaiver('owner', 'org', 'branch', 'sub-1', 'key', {
      amount_minor_unit: 30000,
      reason: 'Negotiated final settlement',
    });
    expect(mocks.ledgerEntry.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        category: 'SETTLEMENT_WAIVER',
        amount_minor_unit: -30000,
        subscription_id: 'sub-1',
      }),
    });
    expect(waiver).toMatchObject({ amount_minor_unit: 30000, ledger_entry_id: 'ledger-1' });
    expect(mocks.auditLog.create).toHaveBeenCalledOnce();
  });

  it('does not replay a waiver key with changed amount or context', async () => {
    mocks.financialAdjustment.findUnique.mockResolvedValue({
      organization_id: 'org',
      branch_id: 'branch',
      subscription_id: 'sub-1',
      amount_minor_unit: 20000,
      reason: 'Negotiated final settlement',
    });
    await expect(
      createSettlementWaiver('owner', 'org', 'branch', 'sub-1', 'key', {
        amount_minor_unit: 30000,
        reason: 'Negotiated final settlement',
      }),
    ).rejects.toThrow('already used');
    expect(mocks.ledgerEntry.create).not.toHaveBeenCalled();
  });

  it('replays an identical concurrent request without double-posting', async () => {
    mocks.$transaction.mockRejectedValueOnce(Object.assign(new Error('unique'), { code: 'P2002' }));
    mocks.financialAdjustment.findUnique.mockResolvedValue({
      id: 'waiver-1',
      organization_id: 'org',
      branch_id: 'branch',
      subscription_id: 'sub-1',
      amount_minor_unit: 30000,
      reason: 'Negotiated final settlement',
      approved_by: 'owner',
    });
    await expect(
      createSettlementWaiver('owner', 'org', 'branch', 'sub-1', 'key', {
        amount_minor_unit: 30000,
        reason: 'Negotiated final settlement',
      }),
    ).resolves.toMatchObject({ id: 'waiver-1' });
    expect(mocks.ledgerEntry.create).not.toHaveBeenCalled();
  });
});
