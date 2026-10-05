import { Prisma, type MemberStatus, type PaymentRequestStatus } from '@prisma/client';
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { findBranchRecipientUserIds, notify } from '../notifications/notifications.service';
import { ConflictError, ForbiddenError, NotFoundError, UnprocessableError } from '../../lib/errors';
import { cloudinary, getUploadSignature } from '../../lib/cloudinary';

import type {
  CreatePaymentRequestInput,
  FeeQuery,
  PaymentCorrectionInput,
  PaymentRequestPeriod,
  ReviewPaymentRequestInput,
  UpdatePaymentRequestInput,
  SettlementWaiverInput,
} from './payments.schema';

type DbClient = Prisma.TransactionClient | typeof prisma;

export function calculateOutstandingBalance(entries: Array<{ amount_minor_unit: number }>) {
  return Math.max(
    entries.reduce((sum, entry) => sum + entry.amount_minor_unit, 0),
    0,
  );
}

export type FeeStatus =
  'PAID' | 'SETTLED' | 'REQUESTED' | 'PENDING' | 'PARTIALLY_PAID' | 'EXPIRING_SOON' | 'EXPIRED';

/** Operational fee directory order: act before expiry, then expired, then healthy coverage. */
export function feeStatusPriority(status: FeeStatus, remainingDays?: number | null) {
  if (remainingDays != null && remainingDays >= 0 && remainingDays <= 7) return 0;
  if (status === 'EXPIRING_SOON') return 0;
  if (remainingDays != null && remainingDays < 0) return 1;
  if (status === 'EXPIRED') return 1;
  return 2;
}

export function deriveFeeStatus(input: {
  hasPendingRequest: boolean;
  hasSubscription: boolean;
  remainingDays: number | null;
  balanceMinorUnit: number;
  hasConfirmedPayment: boolean;
  waivedMinorUnit?: number;
  warningDays: number;
}): FeeStatus {
  if (input.hasPendingRequest) return 'REQUESTED';
  if (!input.hasSubscription) return 'PENDING';
  if (input.remainingDays !== null && input.remainingDays < 0) return 'EXPIRED';
  if (input.balanceMinorUnit > 0) return input.hasConfirmedPayment ? 'PARTIALLY_PAID' : 'PENDING';
  if ((input.waivedMinorUnit ?? 0) > 0) return 'SETTLED';
  if (input.remainingDays !== null && input.remainingDays <= input.warningDays)
    return 'EXPIRING_SOON';
  return 'PAID';
}

export function createPaymentEvidenceUploadSignature(organizationId: string, filename: string) {
  const safeName = filename.replace(/[^a-zA-Z0-9_-]/g, '-').slice(0, 80) || 'evidence';
  const folder = `organizations/${organizationId}/payment-evidence`;
  const publicId = `${safeName}-${ulid()}`;
  return {
    ...getUploadSignature(folder, publicId, 'authenticated'),
    storage_key: `${folder}/${publicId}`,
  };
}

function monthBounds(offset: number) {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + offset, 1));
  const end = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + offset + 1, 0, 23, 59, 59, 999),
  );
  return { start, end };
}

function branchLocalDate(value: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const get = (type: string) => parts.find((part) => part.type === type)?.value ?? '00';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function branchLocalRemainingDays(endDate: Date, timezone: string) {
  const end = branchLocalDate(endDate, timezone);
  const today = branchLocalDate(new Date(), timezone);
  const endUtc = Date.parse(`${end}T00:00:00.000Z`);
  const todayUtc = Date.parse(`${today}T00:00:00.000Z`);
  return Math.ceil((endUtc - todayUtc) / 86_400_000);
}

function shiftLocalDate(value: string, days: number) {
  const date = new Date(`${value}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function localDateStartUtc(localDate: string, timezone: string) {
  const naive = new Date(`${localDate}T00:00:00.000Z`);
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(naive);
  const get = (type: string) => Number(parts.find((part) => part.type === type)?.value ?? 0);
  const displayedAsUtc = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    get('hour'),
    get('minute'),
    get('second'),
  );
  const offsetMs = displayedAsUtc - naive.getTime();
  return new Date(naive.getTime() - offsetMs);
}

function paymentPeriodBounds(period: PaymentRequestPeriod, timezone: string) {
  const today = branchLocalDate(new Date(), timezone);
  let start = today;
  let end = shiftLocalDate(today, 1);
  if (period === 'yesterday') {
    start = shiftLocalDate(today, -1);
  } else if (period === 'this_week') {
    const weekday = new Date(`${today}T00:00:00.000Z`).getUTCDay();
    const sinceMonday = (weekday + 6) % 7;
    start = shiftLocalDate(today, -sinceMonday);
    end = shiftLocalDate(start, 7);
  } else if (period === 'this_month') {
    start = `${today.slice(0, 7)}-01`;
    const nextMonth = new Date(`${today.slice(0, 7)}-01T00:00:00.000Z`);
    nextMonth.setUTCMonth(nextMonth.getUTCMonth() + 1);
    end = nextMonth.toISOString().slice(0, 10);
  } else if (period === 'this_year') {
    start = `${today.slice(0, 4)}-01-01`;
    end = `${String(Number(today.slice(0, 4)) + 1)}-01-01`;
  }
  return { start: localDateStartUtc(start, timezone), end: localDateStartUtc(end, timezone) };
}

export function getPeriod(query: FeeQuery) {
  if (query.period === 'custom') {
    if (!query.from || !query.to)
      throw new UnprocessableError('from and to are required for a custom fee period');
    const start = new Date(`${query.from}T00:00:00.000Z`);
    const end = new Date(`${query.to}T23:59:59.999Z`);
    if (Number.isNaN(start.valueOf()) || Number.isNaN(end.valueOf()) || start > end) {
      throw new UnprocessableError('Fee period is invalid');
    }
    return { start, end };
  }
  return monthBounds(query.period === 'last_month' ? -1 : 0);
}

async function getMemberBalance(
  db: DbClient,
  organizationId: string,
  branchId: string,
  memberId: string,
  subscriptionId?: string,
) {
  const entries = await db.ledgerEntry.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      member_id: memberId,
      ...(subscriptionId ? { subscription_id: subscriptionId } : {}),
    },
    include: {
      allocations: { include: { payment_attempt: true } },
    },
    orderBy: { created_at: 'asc' },
  });

  const confirmedPayments = entries.reduce(
    (sum, entry) =>
      sum +
      entry.allocations
        .filter((allocation) => allocation.payment_attempt.status === 'SUCCESS')
        .reduce((entrySum, allocation) => entrySum + allocation.allocated_amount, 0),
    0,
  );
  return { entries, balance: calculateOutstandingBalance(entries), confirmedPayments };
}

export async function createPaymentRequest(
  actorId: string,
  organizationId: string,
  branchId: string,
  idempotencyKey: string,
  data: CreatePaymentRequestInput,
) {
  const actorMember = await prisma.member.findFirst({
    where: {
      user_id: actorId,
      organization_id: organizationId,
      branch_id: branchId,
      status: 'ACTIVE',
    },
    select: { id: true },
  });
  if (!actorMember)
    throw new ForbiddenError('Only an active branch member can submit a payment request');
  const existing = await prisma.paymentRequest.findUnique({
    where: { idempotency_key: idempotencyKey },
  });
  if (existing) {
    if (
      existing.organization_id !== organizationId ||
      existing.branch_id !== branchId ||
      existing.member_id !== actorMember.id
    ) {
      throw new ConflictError('Idempotency key is already used in another tenant context');
    }
    return existing;
  }

  const created = await prisma.$transaction(
    async (tx) => {
      const member = await tx.member.findFirst({
        where: {
          user_id: actorId,
          organization_id: organizationId,
          branch_id: branchId,
          status: 'ACTIVE',
        },
      });
      if (!member)
        throw new ForbiddenError('Only an active branch member can submit a payment request');

      const subscription = await tx.subscription.findFirst({
        where: {
          id: data.subscription_id,
          organization_id: organizationId,
          branch_id: branchId,
          member_id: member.id,
          status: { in: ['DRAFT', 'UPCOMING', 'ACTIVE', 'PAUSED', 'EXPIRED'] },
        },
        include: { plan: true },
      });
      if (!subscription) throw new NotFoundError('Subscription');
      if (subscription.currency !== data.currency)
        throw new UnprocessableError('Payment currency does not match the subscription');
      if (data.method !== 'GATEWAY' && data.evidence.length === 0 && !data.reference) {
        throw new UnprocessableError('Payment evidence or a payment reference is required');
      }
      for (const evidence of data.evidence) {
        if (!/^(image\/(jpeg|png|webp)|application\/pdf)$/i.test(evidence.content_type)) {
          throw new UnprocessableError('Payment evidence must be a JPEG, PNG, WebP, or PDF file');
        }
        if (!evidence.storage_key.startsWith(`organizations/${organizationId}/payment-evidence/`)) {
          throw new UnprocessableError(
            'Payment evidence must use a private organization storage key',
          );
        }
      }

      const { balance } = await getMemberBalance(
        tx,
        organizationId,
        branchId,
        member.id,
        subscription.id,
      );
      if (data.amount_minor_unit > balance)
        throw new UnprocessableError('Payment exceeds the outstanding subscription balance');

      const request = await tx.paymentRequest.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          member_id: member.id,
          subscription_id: subscription.id,
          amount_minor_unit: data.amount_minor_unit,
          currency: data.currency,
          method: data.method,
          reference: data.reference,
          note: data.note,
          idempotency_key: idempotencyKey,
          evidence: data.evidence.length
            ? {
                create: data.evidence.map((item) => ({
                  id: ulid(),
                  organization_id: organizationId,
                  branch_id: branchId,
                  uploaded_by: actorId,
                  ...item,
                })),
              }
            : undefined,
        },
        include: { evidence: true, subscription: { include: { plan: true } } },
      });

      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          actor_id: actorId,
          action: 'CREATE',
          target_type: 'PaymentRequest',
          target_id: request.id,
          after_state: { status: request.status, amount_minor_unit: request.amount_minor_unit },
        },
      });
      return request;
    },
    {
      isolationLevel: 'Serializable',
      maxWait: 10_000,
      timeout: 30_000,
    },
  );

  try {
    const reviewerUserIds = await findBranchRecipientUserIds(
      organizationId,
      branchId,
      'PAYMENT_REQUEST_REVIEW',
    );
    await notify({
      type: 'PAYMENT_REQUEST_SUBMITTED',
      organizationId,
      branchId,
      entityType: 'PaymentRequest',
      entityId: created.id,
      recipientUserIds: [...new Set([actorId, ...reviewerUserIds])],
      title: 'Payment request submitted',
      body: reviewerUserIds.length
        ? 'A payment request is ready for branch review.'
        : 'Your payment evidence has been submitted for branch review.',
      data: { organization_id: organizationId, branch_id: branchId, entity_id: created.id },
      dedupeKey: `payment-request:${created.id}:submitted`,
    });
  } catch {
    // Notification delivery must not undo a committed payment request.
  }
  return created;
}

export async function updatePaymentRequest(
  actorId: string,
  organizationId: string,
  branchId: string,
  requestId: string,
  data: UpdatePaymentRequestInput,
) {
  const existing = await prisma.paymentRequest.findFirst({
    where: { id: requestId, organization_id: organizationId, branch_id: branchId },
    include: {
      member: { select: { user_id: true } },
      evidence: { select: { id: true } },
    },
  });
  if (!existing) throw new NotFoundError('Payment request');
  if (existing.member.user_id !== actorId)
    throw new ForbiddenError('Only the submitting member can edit this payment request');
  if (!['REQUESTED', 'NEEDS_INFORMATION'].includes(existing.status)) {
    throw new ConflictError('Only pending payment requests can be edited');
  }

  const evidence = data.evidence ?? [];
  for (const item of evidence) {
    if (!/^(image\/(jpeg|png|webp)|application\/pdf)$/i.test(item.content_type)) {
      throw new UnprocessableError('Payment evidence must be a JPEG, PNG, WebP, or PDF file');
    }
    if (!item.storage_key.startsWith(`organizations/${organizationId}/payment-evidence/`)) {
      throw new UnprocessableError('Payment evidence must use a private organization storage key');
    }
  }

  const nextAmount = data.amount_minor_unit ?? existing.amount_minor_unit;
  const nextMethod = data.method ?? existing.method;
  const nextReference = data.reference === undefined ? existing.reference : data.reference;
  const hasEvidence =
    data.evidence === undefined ? existing.evidence.length > 0 : evidence.length > 0;
  if (nextMethod !== 'GATEWAY' && !hasEvidence && !nextReference) {
    throw new UnprocessableError('Payment evidence or a payment reference is required');
  }

  const updated = await prisma.$transaction(
    async (tx) => {
      const current = await tx.paymentRequest.findFirst({
        where: {
          id: requestId,
          organization_id: organizationId,
          branch_id: branchId,
          member: { user_id: actorId },
          status: { in: ['REQUESTED', 'NEEDS_INFORMATION'] },
        },
        select: { id: true, member_id: true, subscription_id: true, status: true },
      });
      if (!current) throw new ConflictError('Payment request is no longer editable');

      const { balance } = await getMemberBalance(
        tx,
        organizationId,
        branchId,
        current.member_id,
        current.subscription_id ?? undefined,
      );
      if (nextAmount > balance)
        throw new UnprocessableError('Payment exceeds the outstanding subscription balance');

      const request = await tx.paymentRequest.update({
        where: { id: requestId },
        data: {
          amount_minor_unit: data.amount_minor_unit,
          method: data.method,
          reference: data.reference === undefined ? undefined : data.reference,
          note: data.note === undefined ? undefined : data.note,
          evidence: data.evidence
            ? {
                deleteMany: {},
                create: evidence.map((item) => ({
                  id: ulid(),
                  organization_id: organizationId,
                  branch_id: branchId,
                  uploaded_by: actorId,
                  ...item,
                })),
              }
            : undefined,
        },
        include: { evidence: true, subscription: { include: { plan: true } } },
      });

      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          actor_id: actorId,
          action: 'UPDATE',
          target_type: 'PaymentRequest',
          target_id: request.id,
          after_state: {
            status: request.status,
            amount_minor_unit: request.amount_minor_unit,
            evidence_count: request.evidence.length,
          },
        },
      });
      return request;
    },
    { isolationLevel: 'Serializable', maxWait: 10_000, timeout: 30_000 },
  );

  try {
    const reviewerUserIds = await findBranchRecipientUserIds(
      organizationId,
      branchId,
      'PAYMENT_REQUEST_REVIEW',
    );
    await notify({
      type: 'PAYMENT_REQUEST_SUBMITTED',
      organizationId,
      branchId,
      actorUserId: actorId,
      entityType: 'PaymentRequest',
      entityId: updated.id,
      recipientUserIds: reviewerUserIds,
      title: 'Payment request updated',
      body: 'A member updated payment details for branch review.',
      data: { organization_id: organizationId, branch_id: branchId, entity_id: updated.id },
      dedupeKey: `payment-request:${updated.id}:updated:${updated.updated_at.toISOString()}`,
    });
  } catch {
    // Delivery must not undo the committed payment request update.
  }
  return updated;
}

export async function listPaymentRequests(
  organizationId: string,
  branchId: string,
  permissions: Set<string>,
  memberId?: string,
  status?: PaymentRequestStatus,
  period?: PaymentRequestPeriod,
) {
  const canReadAll =
    permissions.has('ALL') ||
    permissions.has('PAYMENT_READ_ALL') ||
    permissions.has('PAYMENT_REQUEST_REVIEW');
  if (!canReadAll && !memberId) throw new ForbiddenError('Payment request scope is required');
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, organization_id: organizationId },
    select: { timezone: true },
  });
  const bounds = period ? paymentPeriodBounds(period, branch?.timezone ?? 'UTC') : null;
  return prisma.paymentRequest.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      ...(canReadAll ? {} : { member_id: memberId }),
      ...(status ? { status } : {}),
      ...(bounds ? { created_at: { gte: bounds.start, lt: bounds.end } } : {}),
    },
    select: {
      id: true,
      organization_id: true,
      branch_id: true,
      member_id: true,
      subscription_id: true,
      amount_minor_unit: true,
      currency: true,
      method: true,
      reference: true,
      note: true,
      status: true,
      rejection_reason: true,
      created_at: true,
      member: {
        select: {
          id: true,
          user: { select: { id: true, name: true, email: true, phone: true, avatar_url: true } },
          role: { select: { id: true, name: true, system_key: true } },
        },
      },
      subscription: {
        select: {
          id: true,
          status: true,
          start_date: true,
          end_date: true,
          agreed_amount_minor: true,
          currency: true,
          plan: { select: { id: true, name: true } },
        },
      },
      evidence: {
        select: {
          id: true,
          payment_request_id: true,
          organization_id: true,
          branch_id: true,
          uploaded_by: true,
          storage_key: true,
          content_type: true,
          size_bytes: true,
          reference: true,
          note: true,
          created_at: true,
        },
      },
      payment_attempt: {
        select: {
          id: true,
          organization_id: true,
          branch_id: true,
          member_id: true,
          amount: true,
          currency: true,
          method: true,
          status: true,
          posted_at: true,
          receipt: { select: { id: true, receipt_number: true, issued_at: true, metadata: true } },
        },
      },
    },
    orderBy: { created_at: 'desc' },
  });
}

export async function getPaymentRequest(
  organizationId: string,
  branchId: string,
  requestId: string,
  permissions: Set<string>,
  memberId?: string,
) {
  const canReadAll =
    permissions.has('ALL') ||
    permissions.has('PAYMENT_READ_ALL') ||
    permissions.has('PAYMENT_REQUEST_REVIEW');
  const request = await prisma.paymentRequest.findFirst({
    where: {
      id: requestId,
      organization_id: organizationId,
      branch_id: branchId,
      ...(canReadAll ? {} : { member_id: memberId }),
    },
    include: {
      member: {
        include: {
          user: true,
          role: { select: { name: true } },
        },
      },
      subscription: { include: { plan: true } },
      evidence: true,
      payment_attempt: { include: { receipt: true } },
    },
  });
  if (!request) throw new NotFoundError('Payment request');
  return request;
}

export async function reviewPaymentRequest(
  reviewerId: string,
  organizationId: string,
  branchId: string,
  requestId: string,
  action: 'approve' | 'reject' | 'needs_information',
  data: ReviewPaymentRequestInput,
) {
  const reviewed = await prisma.$transaction(
    async (tx) => {
      const request = await tx.paymentRequest.findFirst({
        where: { id: requestId, organization_id: organizationId, branch_id: branchId },
        include: { subscription: true },
      });
      if (!request) throw new NotFoundError('Payment request');
      if (!['REQUESTED', 'NEEDS_INFORMATION'].includes(request.status)) {
        throw new ConflictError(`Payment request is already ${request.status.toLowerCase()}`);
      }
      if (action !== 'approve') {
        const status = action === 'reject' ? 'REJECTED' : 'NEEDS_INFORMATION';
        const updated = await tx.paymentRequest.update({
          where: { id: request.id },
          data: {
            status,
            rejection_reason: data.reason,
            reviewer_id: reviewerId,
            reviewed_at: new Date(),
          },
        });
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            actor_id: reviewerId,
            action: action === 'reject' ? 'REJECT' : 'UPDATE',
            target_type: 'PaymentRequest',
            target_id: request.id,
            reason: data.reason,
            after_state: { status },
          },
        });
        return updated;
      }

      const { entries, balance } = await getMemberBalance(
        tx,
        organizationId,
        branchId,
        request.member_id,
        request.subscription_id ?? undefined,
      );
      if (request.amount_minor_unit > balance)
        throw new UnprocessableError('Payment request exceeds the current outstanding balance');

      const payment = await tx.paymentAttempt.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          member_id: request.member_id,
          amount: request.amount_minor_unit,
          currency: request.currency,
          method: request.method,
          status: 'SUCCESS',
          posted_by: reviewerId,
          posted_at: new Date(),
          idempotency_key: `payment-request:${request.id}`,
        },
      });

      let remaining = request.amount_minor_unit;
      for (const entry of entries.filter((item) => item.amount_minor_unit > 0)) {
        const allocated = entry.allocations
          .filter((allocation) => allocation.payment_attempt.status === 'SUCCESS')
          .reduce((sum, allocation) => sum + allocation.allocated_amount, 0);
        const available = Math.max(entry.amount_minor_unit - allocated, 0);
        if (!available || remaining <= 0) continue;
        const amount = Math.min(available, remaining);
        await tx.paymentAllocation.create({
          data: {
            id: ulid(),
            payment_attempt_id: payment.id,
            ledger_entry_id: entry.id,
            allocated_amount: amount,
          },
        });
        remaining -= amount;
      }
      if (remaining > 0)
        throw new UnprocessableError('Unable to allocate the full payment to outstanding charges');

      await tx.ledgerEntry.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          member_id: request.member_id,
          subscription_id: request.subscription_id,
          category: 'PAYMENT',
          amount_minor_unit: -request.amount_minor_unit,
          currency: request.currency,
          description: `Payment for request ${request.id}`,
          created_by: reviewerId,
          idempotency_key: `payment-ledger:${request.id}`,
        },
      });
      const receipt = await tx.receipt.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          payment_attempt_id: payment.id,
          receipt_number: `REC-${new Date().getUTCFullYear()}-${request.id.slice(-8)}`,
        },
      });
      const updated = await tx.paymentRequest.update({
        where: { id: request.id },
        data: {
          status: 'APPROVED',
          reviewer_id: reviewerId,
          reviewed_at: new Date(),
          payment_attempt_id: payment.id,
        },
        include: { evidence: true, payment_attempt: { include: { receipt: true } } },
      });
      if (request.subscription && ['DRAFT', 'UPCOMING'].includes(request.subscription.status)) {
        await tx.subscription.update({
          where: { id: request.subscription.id },
          data: { status: 'ACTIVE' },
        });
      }
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          actor_id: reviewerId,
          action: 'PAYMENT_POST',
          target_type: 'PaymentRequest',
          target_id: request.id,
          after_state: { status: updated.status, payment_id: payment.id, receipt_id: receipt.id },
        },
      });
      return updated;
    },
    {
      isolationLevel: 'Serializable',
      maxWait: 10_000,
      timeout: 30_000,
    },
  );

  try {
    const member = await prisma.member.findFirst({
      where: {
        id: reviewed.member_id,
        organization_id: organizationId,
        branch_id: branchId,
      },
      select: { user_id: true },
    });
    if (member) {
      const isApproved = reviewed.status === 'APPROVED';
      const isRejected = reviewed.status === 'REJECTED';
      await notify({
        type: isApproved
          ? 'PAYMENT_REQUEST_APPROVED'
          : isRejected
            ? 'PAYMENT_REQUEST_REJECTED'
            : 'PAYMENT_EVIDENCE_NEEDS_INFORMATION',
        organizationId,
        branchId,
        entityType: 'PaymentRequest',
        entityId: reviewed.id,
        recipientUserIds: [member.user_id],
        title: isApproved
          ? 'Payment approved'
          : isRejected
            ? 'Payment request rejected'
            : 'Payment information needed',
        body: isApproved
          ? 'Your payment has been approved and your receipt is available.'
          : isRejected
            ? (data.reason ?? 'Your payment request was rejected.')
            : (data.reason ?? 'Please provide updated payment information.'),
        data: { organization_id: organizationId, branch_id: branchId, entity_id: reviewed.id },
        dedupeKey: `payment-request:${reviewed.id}:${reviewed.status.toLowerCase()}`,
      });
      if (isApproved && reviewed.payment_attempt_id) {
        await notify({
          type: 'PAYMENT_POSTED',
          organizationId,
          branchId,
          entityType: 'PaymentAttempt',
          entityId: reviewed.payment_attempt_id,
          recipientUserIds: [member.user_id],
          title: 'Payment posted',
          body: 'Your payment has been posted to the branch ledger.',
          data: {
            organization_id: organizationId,
            branch_id: branchId,
            entity_id: reviewed.payment_attempt_id,
          },
          dedupeKey: `payment:${reviewed.payment_attempt_id}:posted`,
        });
        await notify({
          type: 'RECEIPT_GENERATED',
          organizationId,
          branchId,
          entityType: 'PaymentAttempt',
          entityId: reviewed.payment_attempt_id,
          recipientUserIds: [member.user_id],
          title: 'Official receipt ready',
          body: 'Your official payment receipt is ready to view in Dailio.',
          data: {
            organization_id: organizationId,
            branch_id: branchId,
            entity_id: reviewed.payment_attempt_id,
          },
          dedupeKey: `payment:${reviewed.payment_attempt_id}:receipt`,
        });
      }
    }
  } catch {
    // Notification delivery must not undo a committed payment review.
  }
  return reviewed;
}

export async function correctPayment(
  actorId: string,
  organizationId: string,
  branchId: string,
  paymentAttemptId: string,
  action: 'refund' | 'void',
  data: PaymentCorrectionInput,
) {
  const corrected = await prisma.$transaction(
    async (tx) => {
      const payment = await tx.paymentAttempt.findFirst({
        where: {
          id: paymentAttemptId,
          organization_id: organizationId,
          branch_id: branchId,
        },
      });
      if (!payment) throw new NotFoundError('Payment');
      if (!payment.member_id) throw new UnprocessableError('Payment has no member');

      const idempotencyKey = `payment-correction:${action}:${payment.id}`;
      const existing = await tx.ledgerEntry.findUnique({
        where: { idempotency_key: idempotencyKey },
      });
      if (existing) return existing;
      if (payment.status !== 'SUCCESS')
        throw new ConflictError('Payment is already corrected or not confirmed');

      const entry = await tx.ledgerEntry.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          member_id: payment.member_id,
          category: action === 'refund' ? 'REFUND' : 'VOID_REVERSAL',
          amount_minor_unit: payment.amount,
          currency: payment.currency,
          description: `${action === 'refund' ? 'Refund' : 'Void reversal'} for payment ${payment.id}`,
          created_by: actorId,
          idempotency_key: idempotencyKey,
        },
      });
      await tx.paymentAttempt.update({
        where: { id: payment.id },
        data: { status: 'CANCELLED', updated_at: new Date() },
      });
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id: organizationId,
          branch_id: branchId,
          actor_id: actorId,
          action: action === 'refund' ? 'REFUND' : 'VOID',
          target_type: 'PaymentAttempt',
          target_id: payment.id,
          reason: data.reason,
          after_state: { correction_ledger_entry_id: entry.id },
        },
      });
      return entry;
    },
    {
      isolationLevel: 'Serializable',
      maxWait: 10_000,
      timeout: 30_000,
    },
  );
  try {
    const payment = await prisma.paymentAttempt.findFirst({
      where: { id: paymentAttemptId, organization_id: organizationId, branch_id: branchId },
      select: { member: { select: { user_id: true } } },
    });
    if (payment?.member?.user_id) {
      await notify({
        type: action === 'refund' ? 'PAYMENT_REFUNDED' : 'PAYMENT_VOIDED',
        organizationId,
        branchId,
        entityType: 'PaymentAttempt',
        entityId: paymentAttemptId,
        recipientUserIds: [payment.member.user_id],
        title: action === 'refund' ? 'Payment refunded' : 'Payment voided',
        body:
          action === 'refund'
            ? `Your payment was refunded: ${data.reason}`
            : `Your payment was voided: ${data.reason}`,
        data: { organization_id: organizationId, branch_id: branchId, entity_id: paymentAttemptId },
        dedupeKey: `payment:${paymentAttemptId}:${action}`,
      });
    }
  } catch {
    // Notification delivery must not undo a committed payment correction.
  }
  return corrected;
}

/** A concession is a credit, never a fake payment or a change to the agreed plan price. */
export async function createSettlementWaiver(
  actorId: string,
  organizationId: string,
  branchId: string,
  subscriptionId: string,
  idempotencyKey: string,
  data: SettlementWaiverInput,
) {
  let waiver;
  try {
    waiver = await prisma.$transaction(
      async (tx) => {
        const existing = await tx.financialAdjustment.findUnique({
          where: { idempotency_key: idempotencyKey },
        });
        if (existing) {
          if (
            existing.organization_id !== organizationId ||
            existing.branch_id !== branchId ||
            existing.subscription_id !== subscriptionId ||
            existing.amount_minor_unit !== data.amount_minor_unit ||
            existing.reason !== data.reason ||
            existing.approved_by !== actorId
          )
            throw new ConflictError('Idempotency key was already used for another waiver');
          return existing;
        }
        const subscription = await tx.subscription.findFirst({
          where: { id: subscriptionId, organization_id: organizationId, branch_id: branchId },
        });
        if (!subscription) throw new NotFoundError('Subscription');
        if (subscription.status === 'CANCELLED')
          throw new ConflictError('A cancelled subscription cannot receive a waiver');
        const { balance } = await getMemberBalance(
          tx,
          organizationId,
          branchId,
          subscription.member_id,
          subscriptionId,
        );
        if (data.amount_minor_unit > balance)
          throw new UnprocessableError('Waiver exceeds the outstanding subscription balance');
        const ledgerEntry = await tx.ledgerEntry.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            member_id: subscription.member_id,
            subscription_id: subscriptionId,
            category: 'SETTLEMENT_WAIVER',
            amount_minor_unit: -data.amount_minor_unit,
            currency: subscription.currency,
            description: 'Owner-approved settlement waiver',
            created_by: actorId,
            idempotency_key: `settlement-waiver:${idempotencyKey}`,
          },
        });
        const adjustment = await tx.financialAdjustment.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            member_id: subscription.member_id,
            subscription_id: subscriptionId,
            ledger_entry_id: ledgerEntry.id,
            amount_minor_unit: data.amount_minor_unit,
            currency: subscription.currency,
            reason: data.reason,
            approved_by: actorId,
            idempotency_key: idempotencyKey,
          },
        });
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            actor_id: actorId,
            action: 'SETTLEMENT_WAIVER',
            target_type: 'Subscription',
            target_id: subscriptionId,
            reason: data.reason,
            after_state: {
              adjustment_id: adjustment.id,
              amount_minor_unit: data.amount_minor_unit,
              balance_minor_unit: balance - data.amount_minor_unit,
            },
          },
        });
        return adjustment;
      },
      { isolationLevel: 'Serializable', maxWait: 10_000, timeout: 30_000 },
    );
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code !== 'P2002' && code !== 'P2034') throw error;
    const prior = await prisma.financialAdjustment.findUnique({
      where: { idempotency_key: idempotencyKey },
    });
    if (prior) {
      if (
        prior.organization_id !== organizationId ||
        prior.branch_id !== branchId ||
        prior.subscription_id !== subscriptionId ||
        prior.amount_minor_unit !== data.amount_minor_unit ||
        prior.reason !== data.reason ||
        prior.approved_by !== actorId
      )
        throw new ConflictError('Idempotency key was already used for another waiver');
      return prior;
    }
    throw new ConflictError('Subscription balance changed concurrently. Refresh and try again');
  }
  try {
    const subscription = await prisma.subscription.findFirst({
      where: { id: subscriptionId, organization_id: organizationId, branch_id: branchId },
      select: { member: { select: { user_id: true } } },
    });
    if (subscription?.member?.user_id) {
      await notify({
        type: 'SETTLEMENT_WAIVER_APPLIED',
        organizationId,
        branchId,
        actorUserId: actorId,
        entityType: 'Subscription',
        entityId: subscriptionId,
        recipientUserIds: [subscription.member.user_id],
        title: 'Subscription balance updated',
        body: 'An approved settlement concession was applied to your subscription balance.',
        data: {
          organization_id: organizationId,
          branch_id: branchId,
          entity_id: subscriptionId,
          adjustment_id: waiver.id,
        },
        dedupeKey: `settlement-waiver:${waiver.id}:applied`,
      });
    }
  } catch {
    // Notification delivery must not undo a committed financial correction.
  }
  return waiver;
}

export async function listSettlementWaivers(
  organizationId: string,
  branchId: string,
  subscriptionId: string,
  viewerMemberId: string,
  permissions: Set<string>,
  query: { page: number; limit: number },
) {
  const canReadAll =
    permissions.has('ALL') ||
    permissions.has('PAYMENT_READ_ALL') ||
    permissions.has('PAYMENT_WAIVE');
  const subscription = await prisma.subscription.findFirst({
    where: {
      id: subscriptionId,
      organization_id: organizationId,
      branch_id: branchId,
      ...(canReadAll ? {} : { member_id: viewerMemberId }),
    },
    select: { id: true },
  });
  if (!subscription) throw new NotFoundError('Subscription');
  const where = {
    organization_id: organizationId,
    branch_id: branchId,
    subscription_id: subscriptionId,
  };
  const [adjustments, total] = await Promise.all([
    prisma.financialAdjustment.findMany({
      where,
      orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    prisma.financialAdjustment.count({ where }),
  ]);
  if (adjustments.length === 0)
    return { data: [], meta: { page: query.page, limit: query.limit, total } };
  const reversals = await prisma.ledgerEntry.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      reversed_by_id: { in: adjustments.map((item) => item.ledger_entry_id) },
      category: 'VOID_REVERSAL',
    },
    select: { id: true, reversed_by_id: true, created_at: true },
  });
  const reversed = new Map(reversals.map((item) => [item.reversed_by_id, item]));
  const data = adjustments.map((item) => ({
    id: item.id,
    amount_minor_unit: item.amount_minor_unit,
    currency: item.currency,
    reason: item.reason,
    approved_by: item.approved_by,
    created_at: item.created_at,
    reversal_id: reversed.get(item.ledger_entry_id)?.id ?? null,
    reversed_at: reversed.get(item.ledger_entry_id)?.created_at ?? null,
  }));
  return { data, meta: { page: query.page, limit: query.limit, total } };
}

export async function reverseSettlementWaiver(
  actorId: string,
  organizationId: string,
  branchId: string,
  subscriptionId: string,
  waiverId: string,
  idempotencyKey: string,
  reason: string,
) {
  const reversalKey = `settlement-waiver-reversal:${idempotencyKey}`;
  const description = `Waiver reversal: ${reason}`;
  let reversal;
  try {
    reversal = await prisma.$transaction(
      async (tx) => {
        const waiver = await tx.financialAdjustment.findFirst({
          where: {
            id: waiverId,
            organization_id: organizationId,
            branch_id: branchId,
            subscription_id: subscriptionId,
          },
        });
        if (!waiver) throw new NotFoundError('Settlement waiver');
        const existing = await tx.ledgerEntry.findFirst({
          where: {
            reversed_by_id: waiver.ledger_entry_id,
            organization_id: organizationId,
            branch_id: branchId,
            category: 'VOID_REVERSAL',
          },
        });
        if (existing) {
          if (
            existing.idempotency_key !== reversalKey ||
            existing.description !== description ||
            existing.created_by !== actorId
          )
            throw new ConflictError('This waiver has already been reversed');
          return existing;
        }
        const entry = await tx.ledgerEntry.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            member_id: waiver.member_id,
            subscription_id: subscriptionId,
            category: 'VOID_REVERSAL',
            amount_minor_unit: waiver.amount_minor_unit,
            currency: waiver.currency,
            description,
            created_by: actorId,
            reversed_by_id: waiver.ledger_entry_id,
            idempotency_key: reversalKey,
          },
        });
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id: organizationId,
            branch_id: branchId,
            actor_id: actorId,
            action: 'VOID',
            target_type: 'FinancialAdjustment',
            target_id: waiver.id,
            reason,
            after_state: {
              reversal_ledger_entry_id: entry.id,
              amount_minor_unit: waiver.amount_minor_unit,
            },
          },
        });
        return entry;
      },
      { isolationLevel: 'Serializable', maxWait: 10_000, timeout: 30_000 },
    );
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code !== 'P2002' && code !== 'P2034') throw error;
    const waiver = await prisma.financialAdjustment.findFirst({
      where: {
        id: waiverId,
        organization_id: organizationId,
        branch_id: branchId,
        subscription_id: subscriptionId,
      },
    });
    if (!waiver) throw new NotFoundError('Settlement waiver');
    const prior = await prisma.ledgerEntry.findFirst({
      where: {
        reversed_by_id: waiver.ledger_entry_id,
        organization_id: organizationId,
        branch_id: branchId,
        category: 'VOID_REVERSAL',
      },
    });
    if (
      prior &&
      prior.idempotency_key === reversalKey &&
      prior.description === description &&
      prior.created_by === actorId
    ) {
      reversal = prior;
    } else {
      throw new ConflictError('Waiver reversal changed concurrently. Refresh and try again');
    }
  }
  try {
    const subscription = await prisma.subscription.findFirst({
      where: { id: subscriptionId, organization_id: organizationId, branch_id: branchId },
      select: { member: { select: { user_id: true } } },
    });
    if (subscription?.member?.user_id) {
      await notify({
        type: 'SETTLEMENT_WAIVER_REVERSED',
        organizationId,
        branchId,
        actorUserId: actorId,
        entityType: 'Subscription',
        entityId: subscriptionId,
        recipientUserIds: [subscription.member.user_id],
        title: 'Subscription balance updated',
        body: 'A settlement concession was reversed and returned to your outstanding balance.',
        data: {
          organization_id: organizationId,
          branch_id: branchId,
          entity_id: subscriptionId,
          reversal_id: reversal.id,
        },
        dedupeKey: `settlement-waiver:${waiverId}:reversed`,
      });
    }
  } catch {
    // Notification delivery must not undo a committed financial correction.
  }
  return reversal;
}

export async function getReceipt(
  organizationId: string,
  branchId: string,
  paymentAttemptId: string,
  permissions: Set<string>,
  viewerMemberId?: string,
) {
  const payment = await prisma.paymentAttempt.findFirst({
    where: {
      id: paymentAttemptId,
      organization_id: organizationId,
      branch_id: branchId,
      status: { in: ['SUCCESS', 'CANCELLED'] },
    },
    include: { receipt: true, member: { include: { user: true } } },
  });
  if (!payment?.receipt) throw new NotFoundError('Receipt');
  const canReadAll =
    permissions.has('ALL') ||
    permissions.has('PAYMENT_READ_ALL') ||
    permissions.has('PAYMENT_REQUEST_REVIEW');
  if (!canReadAll && payment.member_id !== viewerMemberId)
    throw new ForbiddenError('You cannot access this receipt');
  return {
    receipt: payment.receipt,
    payment: {
      id: payment.id,
      amount_minor_unit: payment.amount,
      currency: payment.currency,
      method: payment.method,
      posted_at: payment.posted_at,
    },
    member: payment.member ? { id: payment.member.id, name: payment.member.user.name } : null,
  };
}

export async function getEvidenceDownloadUrl(
  organizationId: string,
  branchId: string,
  requestId: string,
  evidenceId: string,
  permissions: Set<string>,
  viewerMemberId?: string,
) {
  const request = await prisma.paymentRequest.findFirst({
    where: { id: requestId, organization_id: organizationId, branch_id: branchId },
    include: { evidence: { where: { id: evidenceId } } },
  });
  if (!request || request.evidence.length === 0) throw new NotFoundError('Payment evidence');
  const canReadAll =
    permissions.has('ALL') ||
    permissions.has('PAYMENT_EVIDENCE_READ') ||
    permissions.has('PAYMENT_REQUEST_REVIEW');
  if (!canReadAll && request.member_id !== viewerMemberId)
    throw new ForbiddenError('You cannot access this payment evidence');
  const evidence = request.evidence[0];
  const resourceType = evidence.content_type === 'application/pdf' ? 'raw' : 'image';
  const extension =
    evidence.content_type === 'application/pdf' ? 'pdf' : evidence.content_type.split('/')[1];
  const url =
    resourceType === 'image'
      ? cloudinary.url(evidence.storage_key, {
          resource_type: 'image',
          type: 'authenticated',
          format: extension,
          secure: true,
          sign_url: true,
        })
      : cloudinary.utils.private_download_url(evidence.storage_key, extension, {
          resource_type: resourceType,
          type: 'authenticated',
          expires_at: Math.floor(Date.now() / 1000) + 300,
          attachment: false,
        });
  return {
    url,
    expires_at: new Date(Date.now() + 300_000),
    content_type: evidence.content_type,
  };
}

export async function listFees(
  organizationId: string,
  branchId: string,
  permissions: Set<string>,
  query: FeeQuery,
  currentMemberId: string,
) {
  const { start, end } = getPeriod(query);
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, organization_id: organizationId },
    select: { timezone: true },
  });
  const branchTimezone = branch?.timezone ?? 'UTC';
  const canReadAll =
    permissions.has('ALL') ||
    permissions.has('PAYMENT_READ_ALL') ||
    permissions.has('SUBSCRIPTION_READ_ALL');
  if (query.member_id && !canReadAll && query.member_id !== currentMemberId)
    throw new ForbiddenError('Fee scope is not permitted');
  const statuses: MemberStatus[] = ['ACTIVE', 'SUSPENDED', 'INACTIVE'];
  const where: Prisma.MemberWhereInput = {
    organization_id: organizationId,
    branch_id: branchId,
    status: { in: statuses },
    ...(canReadAll ? (query.member_id ? { id: query.member_id } : {}) : { id: currentMemberId }),
  };
  const members = await prisma.member.findMany({
    where,
    select: {
      id: true,
      member_number: true,
      user: { select: { name: true, avatar_url: true } },
      role: { select: { name: true } },
      subscriptions: {
        where: { status: { not: 'CANCELLED' } },
        select: {
          id: true,
          status: true,
          plan: { select: { name: true } },
          start_date: true,
          end_date: true,
          agreed_amount_minor: true,
          currency: true,
        },
        orderBy: [{ start_date: 'desc' }, { created_at: 'desc' }],
      },
    },
    orderBy: { created_at: 'desc' },
  });

  if (members.length === 0) {
    return {
      data: [],
      meta: { total: 0, page: query.page, limit: query.limit },
      period: { from: start, to: end },
    };
  }

  const memberIds = members.map((member) => member.id);
  const [ledgerTotals, paymentRequests] = await Promise.all([
    // Aggregate ledger/allocation data in Postgres instead of loading every
    // ledger row and payment-attempt relation into Node for every member.
    prisma.$queryRaw<
      Array<{
        member_id: string;
        subscription_id: string | null;
        total_due: number;
        charged_amount: number;
        paid_amount: number;
        waived_amount: number;
        has_confirmed_payment: boolean;
      }>
    >(Prisma.sql`
      WITH scoped_entries AS (
        SELECT id, member_id, subscription_id, amount_minor_unit, category, reversed_by_id
        FROM ledger_entries
        WHERE organization_id = ${organizationId}
          AND branch_id = ${branchId}
          AND member_id IN (${Prisma.join(memberIds)})
      ), confirmed_allocations AS (
        SELECT allocation.ledger_entry_id,
          SUM(allocation.allocated_amount)::int AS paid_amount
        FROM payment_allocations allocation
        JOIN payment_attempts pa ON pa.id = allocation.payment_attempt_id
          AND pa.organization_id = ${organizationId}
          AND pa.branch_id = ${branchId}
          AND pa.status = 'SUCCESS'
        WHERE allocation.ledger_entry_id IN (SELECT id FROM scoped_entries)
        GROUP BY allocation.ledger_entry_id
      )
      SELECT le.member_id, le.subscription_id,
        COALESCE(SUM(le.amount_minor_unit), 0)::int AS total_due,
        COALESCE(SUM(CASE WHEN le.category IN ('SUBSCRIPTION_CHARGE', 'JOINING_FEE', 'FINE', 'MANUAL_DEBIT') THEN le.amount_minor_unit ELSE 0 END), 0)::int AS charged_amount,
        COALESCE(SUM(a.paid_amount), 0)::int AS paid_amount,
        COALESCE(SUM(CASE
          WHEN le.category = 'SETTLEMENT_WAIVER' THEN -le.amount_minor_unit
          WHEN le.category = 'VOID_REVERSAL' AND original.category = 'SETTLEMENT_WAIVER' THEN -le.amount_minor_unit
          ELSE 0 END), 0)::int AS waived_amount,
        COALESCE(BOOL_OR(a.paid_amount > 0), false) AS has_confirmed_payment
      FROM scoped_entries le
      LEFT JOIN confirmed_allocations a ON a.ledger_entry_id = le.id
      LEFT JOIN scoped_entries original ON original.id = le.reversed_by_id
      GROUP BY le.member_id, le.subscription_id
    `),
    prisma.paymentRequest.findMany({
      where: {
        organization_id: organizationId,
        branch_id: branchId,
        member_id: { in: memberIds },
        status: { in: ['REQUESTED', 'NEEDS_INFORMATION', 'APPROVED'] },
      },
      select: {
        id: true,
        member_id: true,
        subscription_id: true,
        status: true,
        method: true,
        created_at: true,
        payment_attempt: {
          select: {
            status: true,
            posted_at: true,
            receipt: { select: { receipt_number: true } },
          },
        },
      },
      orderBy: { created_at: 'desc' },
    }),
  ]);

  const ledgerByMember = new Map<string, typeof ledgerTotals>();
  for (const row of ledgerTotals) {
    const rows = ledgerByMember.get(row.member_id) ?? [];
    rows.push(row);
    ledgerByMember.set(row.member_id, rows);
  }
  const requestsByMember = new Map<string, typeof paymentRequests>();
  for (const request of paymentRequests) {
    const requests = requestsByMember.get(request.member_id) ?? [];
    requests.push(request);
    requestsByMember.set(request.member_id, requests);
  }

  const warningDays = 7;
  const cards = members
    .map((member) => {
      // The fee directory is a current-status view, not a periodized ledger.
      // Keep exactly one card per member and always use the latest subscription,
      // including an expired one when it is the member's latest record.
      const subscription = member.subscriptions[0];
      const memberLedger = ledgerByMember.get(member.id) ?? [];
      const relevantEntries = memberLedger.filter(
        (entry) =>
          !subscription || !entry.subscription_id || entry.subscription_id === subscription.id,
      );
      const totalDue = relevantEntries.reduce((sum, entry) => sum + entry.total_due, 0);
      const balance = Math.max(totalDue, 0);
      const memberRequests = requestsByMember.get(member.id) ?? [];
      const pendingRequest = memberRequests.find(
        (request) =>
          ['REQUESTED', 'NEEDS_INFORMATION'].includes(request.status) &&
          (!subscription || request.subscription_id === subscription.id),
      );
      const latestApprovedRequest = memberRequests.find(
        (request) =>
          request.status === 'APPROVED' &&
          request.payment_attempt?.status === 'SUCCESS' &&
          (!subscription || request.subscription_id === subscription.id),
      );
      const paidAmount = relevantEntries.reduce((sum, entry) => sum + entry.paid_amount, 0);
      const waivedAmount = relevantEntries.reduce((sum, entry) => sum + entry.waived_amount, 0);
      const chargedAmount = relevantEntries.reduce((sum, entry) => sum + entry.charged_amount, 0);
      const endDate = subscription?.end_date;
      const remainingDays = endDate ? branchLocalRemainingDays(endDate, branchTimezone) : null;
      const status = deriveFeeStatus({
        hasPendingRequest: Boolean(pendingRequest),
        hasSubscription: Boolean(subscription),
        remainingDays,
        balanceMinorUnit: balance,
        hasConfirmedPayment: memberLedger.some((entry) => entry.has_confirmed_payment),
        waivedMinorUnit: waivedAmount,
        warningDays,
      });
      return {
        member: {
          id: member.id,
          name: member.user.name,
          member_number: member.member_number,
          avatar_url: member.user.avatar_url,
          role_name: member.role?.name ?? null,
        },
        subscription: subscription
          ? {
              id: subscription.id,
              status: subscription.status,
              plan_name: subscription.plan.name,
              start_date: subscription.start_date,
              end_date: subscription.end_date,
              amount_minor_unit: subscription.agreed_amount_minor,
              currency: subscription.currency,
            }
          : null,
        status,
        balance_minor_unit: balance,
        paid_amount_minor_unit: paidAmount,
        waived_amount_minor_unit: waivedAmount,
        charged_amount_minor_unit: chargedAmount,
        currency: subscription?.currency ?? 'INR',
        remaining_days: remainingDays,
        pending_request_id: pendingRequest?.id ?? null,
        payment_date: latestApprovedRequest?.payment_attempt?.posted_at ?? null,
        payment_method: latestApprovedRequest?.method ?? null,
        receipt_number: latestApprovedRequest?.payment_attempt?.receipt?.receipt_number ?? null,
        evidence_status: pendingRequest
          ? pendingRequest.status
          : latestApprovedRequest
            ? 'CONFIRMED'
            : 'MISSING',
        paid_earlier_covering_period: Boolean(
          subscription && subscription.start_date < start && subscription.end_date >= start,
        ),
        urgency_action:
          remainingDays !== null && remainingDays <= warningDays
            ? 'RENEW_OR_COLLECT'
            : balance > 0
              ? 'COLLECT_PAYMENT'
              : null,
        period: { from: start, to: end },
      };
    })
    .filter((card) => !query.status || card.status === query.status);

  cards.sort((left, right) => {
    const priority =
      feeStatusPriority(left.status, left.remaining_days) -
      feeStatusPriority(right.status, right.remaining_days);
    if (priority !== 0) return priority;
    if (left.status === 'EXPIRING_SOON' && right.status === 'EXPIRING_SOON') {
      const days =
        (left.remaining_days ?? Number.MAX_SAFE_INTEGER) -
        (right.remaining_days ?? Number.MAX_SAFE_INTEGER);
      if (days !== 0) return days;
    }
    if (left.status === 'EXPIRED' && right.status === 'EXPIRED') {
      const days = (left.remaining_days ?? 0) - (right.remaining_days ?? 0);
      if (days !== 0) return days;
    }
    return left.member.name.localeCompare(right.member.name);
  });

  const skip = (query.page - 1) * query.limit;
  return {
    data: cards.slice(skip, skip + query.limit),
    meta: { total: cards.length, page: query.page, limit: query.limit },
    period: { from: start, to: end },
  };
}
