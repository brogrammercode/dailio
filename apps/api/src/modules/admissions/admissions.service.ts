import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError } from '../../lib/errors';

import type { CreateJoinRequestInput, JoinRequestActionInput } from './admissions.schema';

export async function submitJoinRequest(
  user_id: string,
  branch_id: string,
  data: CreateJoinRequestInput,
) {
  const branch = await prisma.branch.findUnique({
    where: { id: branch_id },
    include: { organization: true },
  });

  if (!branch) throw new NotFoundError('Branch');

  // Check if they are already a member or have a pending request
  const existingMember = await prisma.member.findFirst({
    where: { branch_id, user_id },
  });
  if (existingMember) throw new ConflictError('Already a member of this branch');

  const existingRequest = await prisma.joinRequest.findFirst({
    where: { user_id, branch_id, status: 'PENDING' },
  });
  if (existingRequest) throw new ConflictError('A pending join request already exists');

  return prisma.joinRequest.create({
    data: {
      id: ulid(),
      user_id,
      branch_id,
      organization_id: branch.organization_id,
      status: 'PENDING',
      message: data.message,
    },
  });
}

export async function listPendingRequests(organization_id: string, branch_id: string) {
  return prisma.joinRequest.findMany({
    where: {
      organization_id,
      branch_id,
      status: 'PENDING',
    },
    include: {
      user: {
        select: { id: true, name: true, email: true },
      },
    },
    orderBy: { created_at: 'asc' },
  });
}

export async function approveJoinRequest(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  request_id: string,
  data: JoinRequestActionInput,
) {
  return prisma.$transaction(async (tx) => {
    const txClient = tx as typeof prisma;
    const request = await txClient.joinRequest.findUnique({
      where: { id: request_id },
      include: { user: true },
    });

    if (
      !request ||
      request.organization_id !== organization_id ||
      request.branch_id !== branch_id
    ) {
      throw new NotFoundError('Join Request');
    }
    if (request.status !== 'PENDING') {
      throw new ConflictError('Request is not pending');
    }

    // 1. Mark request as APPROVED
    await txClient.joinRequest.update({
      where: { id: request_id },
      data: { 
        status: 'APPROVED', 
        reviewed_at: new Date(),
        reviewed_by: actor_id,
      },
    });

    // 2. Fetch default MEMBER role
    const memberRole = await txClient.role.findFirst({
      where: { organization_id, system_key: 'MEMBER' },
    });

    // 3. Create Member
    const memberId = ulid();
    const member = await txClient.member.create({
      data: {
        id: memberId,
        user_id: request.user_id,
        organization_id,
        branch_id,
        role_id: memberRole?.id,
        member_number: 'MEM-' + Date.now().toString().slice(-6),
        status: 'ACTIVE',
        is_employee: false,
      },
    });

    // Link member to request
    await txClient.joinRequest.update({
      where: { id: request_id },
      data: { member_id: memberId }
    });

    // 4. Audit log
    await txClient.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'JoinRequest',
        target_id: request_id,
        after_state: { status: 'APPROVED', reason: data.reason },
      },
    });

    return member;
  }, { maxWait: 5000, timeout: 20000 });
}

export async function rejectJoinRequest(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  request_id: string,
  data: JoinRequestActionInput,
) {
  return prisma.$transaction(async (tx) => {
    const txClient = tx as typeof prisma;
    const request = await txClient.joinRequest.findUnique({
      where: { id: request_id },
    });

    if (
      !request ||
      request.organization_id !== organization_id ||
      request.branch_id !== branch_id
    ) {
      throw new NotFoundError('Join Request');
    }
    if (request.status !== 'PENDING') {
      throw new ConflictError('Request is not pending');
    }

    const updated = await txClient.joinRequest.update({
      where: { id: request_id },
      data: { 
        status: 'REJECTED', 
        rejection_reason: data.reason,
        reviewed_at: new Date(),
        reviewed_by: actor_id,
      },
    });

    await txClient.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'JoinRequest',
        target_id: request_id,
        after_state: { status: 'REJECTED', reason: data.reason },
      },
    });

    return updated;
  });
}
