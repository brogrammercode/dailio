import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../lib/errors';
import { findBranchRecipientUserIds, notify } from '../notifications/notifications.service';

import type { CreateLeaveRequestInput, LeaveActionInput } from './leave.schema';

function dateOnly(value: string) {
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) throw new ValidationError('Invalid leave date');
  return date;
}

function assertDateRange(input: CreateLeaveRequestInput) {
  const start = dateOnly(input.start_date);
  const end = dateOnly(input.end_date);
  if (end < start) throw new ValidationError('Leave end date must be on or after start date');
  return { start, end };
}

function canReadAll(permissions: Set<string>) {
  return (
    permissions.has('ALL') || permissions.has('LEAVE_READ_ALL') || permissions.has('LEAVE_MANAGE')
  );
}

export async function listLeaveRequests(
  organizationId: string,
  branchId: string,
  memberId: string,
  permissions: Set<string>,
) {
  return prisma.leaveRequest.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      ...(canReadAll(permissions) ? {} : { member_id: memberId }),
    },
    include: {
      member: {
        include: { user: { select: { id: true, name: true, avatar_url: true } }, role: true },
      },
    },
    orderBy: [{ start_date: 'desc' }, { created_at: 'desc' }],
  });
}

export async function createLeaveRequest(
  organizationId: string,
  branchId: string,
  memberId: string,
  input: CreateLeaveRequestInput,
  actorUserId: string,
  headerIdempotencyKey?: string,
) {
  const { start, end } = assertDateRange(input);
  const idempotencyKey = input.idempotency_key ?? headerIdempotencyKey;
  if (idempotencyKey) {
    const existing = await prisma.leaveRequest.findUnique({
      where: { idempotency_key: idempotencyKey },
    });
    if (existing) {
      if (
        existing.organization_id !== organizationId ||
        existing.branch_id !== branchId ||
        existing.member_id !== memberId
      ) {
        throw new ConflictError('Idempotency key belongs to another leave request');
      }
      return existing;
    }
  }
  const overlap = await prisma.leaveRequest.findFirst({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      member_id: memberId,
      status: { in: ['PENDING', 'APPROVED'] },
      start_date: { lte: end },
      end_date: { gte: start },
    },
  });
  if (overlap) throw new ConflictError('An active leave request already overlaps these dates');
  const created = await prisma.$transaction(async (tx) => {
    const request = await tx.leaveRequest.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        member_id: memberId,
        start_date: start,
        end_date: end,
        reason: input.reason,
        idempotency_key: idempotencyKey,
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'CREATE',
        target_type: 'LeaveRequest',
        target_id: request.id,
        after_state: {
          start_date: input.start_date,
          end_date: input.end_date,
          status: request.status,
        },
      },
    });
    return request;
  });
  const reviewers = await findBranchRecipientUserIds(organizationId, branchId, 'LEAVE_MANAGE');
  await notify({
    type: 'LEAVE_SUBMITTED',
    organizationId,
    branchId,
    actorUserId,
    entityType: 'LeaveRequest',
    entityId: created.id,
    recipientUserIds: [...new Set([...reviewers, actorUserId])],
    title: 'Leave request submitted',
    body: `Leave requested from ${input.start_date} to ${input.end_date}.`,
    data: { organization_id: organizationId, branch_id: branchId, entity_id: created.id },
    dedupeKey: `leave:${created.id}:submitted`,
  });
  return created;
}

async function getScopedRequest(organizationId: string, branchId: string, requestId: string) {
  const request = await prisma.leaveRequest.findFirst({
    where: { id: requestId, organization_id: organizationId, branch_id: branchId },
    include: { member: { select: { user_id: true } } },
  });
  if (!request) throw new NotFoundError('Leave request');
  return request;
}

export async function decideLeaveRequest(
  organizationId: string,
  branchId: string,
  requestId: string,
  status: 'APPROVED' | 'REJECTED',
  input: LeaveActionInput,
  actorUserId: string,
) {
  const current = await getScopedRequest(organizationId, branchId, requestId);
  if (current.status !== 'PENDING')
    throw new ConflictError('Only pending leave requests can be reviewed');
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.leaveRequest.updateMany({
      where: {
        id: requestId,
        organization_id: organizationId,
        branch_id: branchId,
        status: 'PENDING',
      },
      data: {
        status,
        reviewed_by: actorUserId,
        reviewed_at: new Date(),
        review_note: input.review_note,
      },
    });
    if (result.count !== 1) throw new ConflictError('Leave request was already reviewed');
    const request = await tx.leaveRequest.findUniqueOrThrow({ where: { id: requestId } });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: status === 'APPROVED' ? 'APPROVE' : 'REJECT',
        target_type: 'LeaveRequest',
        target_id: requestId,
        after_state: { status, review_note: input.review_note ?? null },
      },
    });
    return request;
  });
  await notify({
    type: `LEAVE_${status}`,
    organizationId,
    branchId,
    actorUserId,
    entityType: 'LeaveRequest',
    entityId: updated.id,
    recipientUserIds: [current.member?.user_id ?? ''].filter(Boolean),
    title: status === 'APPROVED' ? 'Leave approved' : 'Leave request rejected',
    body:
      status === 'APPROVED'
        ? 'Your leave request was approved.'
        : 'Your leave request was rejected.',
    data: { organization_id: organizationId, branch_id: branchId, entity_id: updated.id },
    dedupeKey: `leave:${updated.id}:${status.toLowerCase()}`,
  });
  return updated;
}

export async function cancelLeaveRequest(
  organizationId: string,
  branchId: string,
  requestId: string,
  memberId: string,
  actorUserId: string,
) {
  const current = await getScopedRequest(organizationId, branchId, requestId);
  if (current.member_id !== memberId)
    throw new ForbiddenError('You can only cancel your own leave request');
  if (current.status !== 'PENDING')
    throw new ConflictError('Only pending leave requests can be cancelled');
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.leaveRequest.updateMany({
      where: {
        id: requestId,
        organization_id: organizationId,
        branch_id: branchId,
        member_id: memberId,
        status: 'PENDING',
      },
      data: { status: 'CANCELLED', reviewed_by: actorUserId, reviewed_at: new Date() },
    });
    if (result.count !== 1) throw new ConflictError('Leave request was already changed');
    const request = await tx.leaveRequest.findUniqueOrThrow({ where: { id: requestId } });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'CANCEL',
        target_type: 'LeaveRequest',
        target_id: requestId,
        after_state: { status: 'CANCELLED' },
      },
    });
    return request;
  });
  const reviewers = await findBranchRecipientUserIds(organizationId, branchId, 'LEAVE_MANAGE');
  await notify({
    type: 'LEAVE_CANCELLED',
    organizationId,
    branchId,
    actorUserId,
    entityType: 'LeaveRequest',
    entityId: updated.id,
    recipientUserIds: reviewers,
    title: 'Leave request cancelled',
    body: 'A pending leave request was cancelled.',
    data: { organization_id: organizationId, branch_id: branchId, entity_id: updated.id },
    dedupeKey: `leave:${updated.id}:cancelled`,
  });
  return updated;
}
