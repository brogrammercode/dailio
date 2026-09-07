import { ulid } from 'ulid';
import type { Prisma } from '@prisma/client';

import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';

import type { ListMembersQuery, AssistedAdmissionInput, MemberActionInput } from './members.schema';

export async function listMembers(organization_id: string, location_id: string, query: ListMembersQuery) {
  const { search, status, page, limit } = query;
  
  const where: Prisma.LocationMembershipWhereInput = {
    organization_id,
    location_id,
  };

  if (status) {
    where.status = status;
  }

  if (search) {
    where.organization_membership = {
      OR: [
        { first_name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ],
    };
  }

  const skip = (page - 1) * limit;

  const [data, total] = await Promise.all([
    prisma.locationMembership.findMany({
      where,
      include: {
        organization_membership: true,
        role_assignments: {
          include: { role: true }
        }
      },
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
    }),
    prisma.locationMembership.count({ where }),
  ]);

  return { data, total, page, limit };
}

export async function getMemberDetail(organization_id: string, location_id: string, location_membership_id: string) {
  const member = await prisma.locationMembership.findUnique({
    where: { id: location_membership_id },
    include: {
      organization_membership: true,
      role_assignments: {
        include: { role: true }
      }
    }
  });

  if (!member || member.organization_id !== organization_id || member.location_id !== location_id) {
    throw new NotFoundError('Member');
  }

  return member;
}

export async function suspendMember(actor_id: string, organization_id: string, location_id: string, location_membership_id: string, data: MemberActionInput) {
  return prisma.$transaction(async (tx) => {
    const member = await tx.locationMembership.findUnique({
      where: { id: location_membership_id },
    });

    if (!member || member.organization_id !== organization_id || member.location_id !== location_id) {
      throw new NotFoundError('Member');
    }

    const updated = await tx.locationMembership.update({
      where: { id: location_membership_id },
      data: {
        status: 'SUSPENDED',
        suspended_by: actor_id,
        suspended_at: new Date(),
        updated_at: new Date(),
      },
    });

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        location_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'LocationMembership',
        target_id: location_membership_id,
        after_state: { status: 'SUSPENDED', reason: data.reason },
      },
    });

    return updated;
  });
}

export async function deactivateMember(actor_id: string, organization_id: string, location_id: string, location_membership_id: string, data: MemberActionInput) {
  return prisma.$transaction(async (tx) => {
    const member = await tx.locationMembership.findUnique({
      where: { id: location_membership_id },
    });

    if (!member || member.organization_id !== organization_id || member.location_id !== location_id) {
      throw new NotFoundError('Member');
    }

    const updated = await tx.locationMembership.update({
      where: { id: location_membership_id },
      data: {
        status: 'INACTIVE',
        deactivated_by: actor_id,
        deactivated_at: new Date(),
        updated_at: new Date(),
      },
    });

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        location_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'LocationMembership',
        target_id: location_membership_id,
        after_state: { status: 'INACTIVE', reason: data.reason },
      },
    });

    return updated;
  });
}

export async function createAssistedAdmission(actor_id: string, organization_id: string, location_id: string, data: AssistedAdmissionInput) {
  return prisma.$transaction(async (tx) => {
    const orgMembershipId = ulid();
    const orgMembership = await tx.organizationMembership.create({
      data: {
        id: orgMembershipId,
        organization_id,
        first_name: data.first_name,
        last_name: data.last_name,
        email: data.email,
        phone: data.phone,
      },
    });

    const locMembershipId = ulid();
    const locMembership = await tx.locationMembership.create({
      data: {
        id: locMembershipId,
        organization_id,
        location_id,
        organization_membership_id: orgMembership.id,
        membership_number: 'MEM-' + Date.now().toString().slice(-6),
        status: 'ACTIVE',
      },
    });

    const memberRole = await tx.role.findFirst({
      where: { organization_id, system_key: 'MEMBER' },
    });

    if (memberRole) {
      await tx.roleAssignment.create({
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

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        location_id,
        actor_id,
        action: 'CREATE',
        target_type: 'LocationMembership',
        target_id: locMembershipId,
        after_state: { status: 'ACTIVE', admission_type: 'ASSISTED' },
      },
    });

    return locMembership;
  });
}
