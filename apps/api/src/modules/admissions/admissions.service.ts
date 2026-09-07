import { ulid } from 'ulid';
import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError } from '../../lib/errors';
import type { CreateJoinRequestInput, JoinRequestActionInput } from './admissions.schema';

export async function submitJoinRequest(
  user_id: string,
  location_id: string,
  data: CreateJoinRequestInput,
) {
  const location = await prisma.location.findUnique({
    where: { id: location_id },
    include: { organization: true },
  });

  if (!location) throw new NotFoundError('Location');

  // Check if they are already a member or have a pending request
  const existingMember = await prisma.locationMembership.findFirst({
    where: { location_id, organization_membership: { user_id } },
  });
  if (existingMember) throw new ConflictError('Already a member of this location');

  const existingRequest = await prisma.joinRequest.findFirst({
    where: { user_id, location_id, status: 'PENDING' },
  });
  if (existingRequest) throw new ConflictError('A pending join request already exists');

  return prisma.joinRequest.create({
    data: {
      id: ulid(),
      user_id,
      location_id,
      organization_id: location.organization_id,
      status: 'PENDING',
    },
  });
}

export async function listPendingRequests(organization_id: string, location_id: string) {
  return prisma.joinRequest.findMany({
    where: {
      organization_id,
      location_id,
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
  location_id: string,
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
      request.location_id !== location_id
    ) {
      throw new NotFoundError('Join Request');
    }
    if (request.status !== 'PENDING') {
      throw new ConflictError('Request is not pending');
    }

    // 1. Mark request as APPROVED
    await txClient.joinRequest.update({
      where: { id: request_id },
      data: { status: 'APPROVED', updated_at: new Date() },
    });

    // 2. Ensure OrganizationMembership exists
    let orgMembership = await txClient.organizationMembership.findFirst({
      where: { user_id: request.user_id, organization_id },
    });

    if (!orgMembership) {
      orgMembership = await txClient.organizationMembership.create({
        data: {
          id: ulid(),
          user_id: request.user_id,
          organization_id,
          first_name: request.user.name,
          email: request.user.email,
        },
      });
    }

    // 3. Create LocationMembership
    const locMembershipId = ulid();
    const locMembership = await txClient.locationMembership.create({
      data: {
        id: locMembershipId,
        organization_id,
        location_id,
        organization_membership_id: orgMembership.id,
        membership_number: 'MEM-' + Date.now().toString().slice(-6),
        status: 'ACTIVE',
      },
    });

    // 4. Assign default MEMBER role
    const memberRole = await txClient.role.findFirst({
      where: { organization_id, system_key: 'MEMBER' },
    });

    if (memberRole) {
      await txClient.roleAssignment.create({
        data: {
          id: ulid(),
          organization_id,
          location_id,
          role_id: memberRole.id,
          location_membership_id: locMembershipId,
          assigned_by: actor_id,
        },
      });
    }

    // 5. Audit log
    await txClient.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        location_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'JoinRequest',
        target_id: request_id,
        after_state: { status: 'APPROVED', reason: data.reason },
      },
    });

    return locMembership;
  });
}

export async function rejectJoinRequest(
  actor_id: string,
  organization_id: string,
  location_id: string,
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
      request.location_id !== location_id
    ) {
      throw new NotFoundError('Join Request');
    }
    if (request.status !== 'PENDING') {
      throw new ConflictError('Request is not pending');
    }

    const updated = await txClient.joinRequest.update({
      where: { id: request_id },
      data: { status: 'REJECTED', updated_at: new Date() },
    });

    await txClient.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        location_id,
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
