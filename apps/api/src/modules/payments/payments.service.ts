import type { MemberStatus, Prisma, PaymentRequestStatus } from '@prisma/client';
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ConflictError, ForbiddenError, NotFoundError, UnprocessableError } from '../../lib/errors';
import { cloudinary, getUploadSignature } from '../../lib/cloudinary';

import type {
  CreatePaymentRequestInput,
  FeeQuery,
  PaymentCorrectionInput,
  PaymentRequestPeriod,
  ReviewPaymentRequestInput,
} from './payments.schema';

type DbClient = Prisma.TransactionClient | typeof prisma;

export function calculateOutstandingBalance(entries: Array<{ amount_minor_unit: number }>) {
  return Math.max(
    entries.reduce((sum, entry) => sum + entry.amount_minor_unit, 0),
    0,
  );
}

export type FeeStatus =
  'PAID' | 'REQUESTED' | 'PENDING' | 'PARTIALLY_PAID' | 'EXPIRING_SOON' | 'EXPIRED';

export function deriveFeeStatus(input: {
  hasPendingRequest: boolean;
  hasSubscription: boolean;
  remainingDays: number | null;
  balanceMinorUnit: number;
  hasConfirmedPayment: boolean;
  warningDays: number;
}): FeeStatus {
  if (input.hasPendingRequest) return 'REQUESTED';
  if (!input.hasSubscription) return 'PENDING';
  if (input.remainingDays !== null && input.remainingDays < 0) return 'EXPIRED';
  if (input.balanceMinorUnit > 0) return input.hasConfirmedPayment ? 'PARTIALLY_PAID' : 'PENDING';
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

  return prisma.$transaction(
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
  return prisma.$transaction(
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
}

export async function correctPayment(
  actorId: string,
  organizationId: string,
  branchId: string,
  paymentAttemptId: string,
  action: 'refund' | 'void',
  data: PaymentCorrectionInput,
) {
  return prisma.$transaction(
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
  return {
    url: cloudinary.utils.private_download_url(evidence.storage_key, extension, {
      resource_type: resourceType,
      type: 'authenticated',
      expires_at: Math.floor(Date.now() / 1000) + 300,
      attachment: false,
    }),
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
    include: {
      user: true,
      role: { select: { name: true } },
      subscriptions: { include: { plan: true }, orderBy: { end_date: 'desc' } },
      ledger_entries: {
        include: { allocations: { include: { payment_attempt: true } } },
        orderBy: { created_at: 'asc' },
      },
      payment_requests: {
        include: { payment_attempt: { include: { receipt: true } } },
        orderBy: { created_at: 'desc' },
      },
    },
    orderBy: { created_at: 'desc' },
  });

  const warningDays = 7;
  const cards = members
    .map((member) => {
      const subscriptions = member.subscriptions.filter(
        (subscription) =>
          subscription.start_date <= end &&
          subscription.end_date >= start &&
          subscription.status !== 'CANCELLED',
      );
      const subscription =
        subscriptions[0] ?? member.subscriptions.find((item) => item.status !== 'CANCELLED');
      const relevantEntries = member.ledger_entries.filter(
        (entry) =>
          !subscription || !entry.subscription_id || entry.subscription_id === subscription.id,
      );
      const totalDue = relevantEntries.reduce((sum, entry) => sum + entry.amount_minor_unit, 0);
      const balance = Math.max(totalDue, 0);
      const pendingRequest = member.payment_requests.find(
        (request) =>
          ['REQUESTED', 'NEEDS_INFORMATION'].includes(request.status) &&
          (!subscription || request.subscription_id === subscription.id),
      );
      const latestApprovedRequest = member.payment_requests.find(
        (request) =>
          request.status === 'APPROVED' &&
          request.payment_attempt?.status === 'SUCCESS' &&
          (!subscription || request.subscription_id === subscription.id),
      );
      const paidAmount = relevantEntries.reduce(
        (sum, entry) =>
          sum +
          entry.allocations
            .filter((allocation) => allocation.payment_attempt.status === 'SUCCESS')
            .reduce((entrySum, allocation) => entrySum + allocation.allocated_amount, 0),
        0,
      );
      const endDate = subscription?.end_date;
      const remainingDays = endDate ? branchLocalRemainingDays(endDate, branchTimezone) : null;
      const status = deriveFeeStatus({
        hasPendingRequest: Boolean(pendingRequest),
        hasSubscription: Boolean(subscription),
        remainingDays,
        balanceMinorUnit: balance,
        hasConfirmedPayment: member.ledger_entries.some((entry) =>
          entry.allocations.some((allocation) => allocation.payment_attempt.status === 'SUCCESS'),
        ),
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

  const skip = (query.page - 1) * query.limit;
  return {
    data: cards.slice(skip, skip + query.limit),
    meta: { total: cards.length, page: query.page, limit: query.limit },
    period: { from: start, to: end },
  };
}
