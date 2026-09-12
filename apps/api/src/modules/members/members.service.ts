/* eslint-disable @typescript-eslint/no-explicit-any */
import { ulid } from 'ulid';
import type { Prisma } from '@prisma/client';

import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';

import type {
  ListMembersQuery,
  AssistedAdmissionInput,
  MemberActionInput,
  UpdateMemberInput,
} from './members.schema';

export async function listMembers(
  organization_id: string,
  branch_id: string,
  query: ListMembersQuery,
) {
  const { search, status, page, limit, role_id } = query;

  const where: Prisma.MemberWhereInput = {
    organization_id,
    branch_id,
  };

  if (status) {
    where.status = status;
  }

  if (role_id) {
    where.role_id = role_id;
  }

  if (search) {
    where.user = {
      OR: [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ],
    };
  }

  const skip = (page - 1) * limit;

  const [data, total] = await Promise.all([
    prisma.member.findMany({
      where,
      include: {
        user: true,
        role: true,
      },
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
    }),
    prisma.member.count({ where }),
  ]);

  return { data, total, page, limit };
}

export async function getMemberDetail(
  organization_id: string,
  branch_id: string,
  member_id: string,
) {
  const member = await prisma.member.findUnique({
    where: { id: member_id },
    include: {
      user: true,
      role: true,
    },
  });

  if (!member || member.organization_id !== organization_id || member.branch_id !== branch_id) {
    throw new NotFoundError('Member');
  }

  return member;
}

export async function suspendMember(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  member_id: string,
  data: MemberActionInput,
) {
  return prisma.$transaction(async (tx) => {
    const member = await tx.member.findUnique({
      where: { id: member_id },
    });

    if (!member || member.organization_id !== organization_id || member.branch_id !== branch_id) {
      throw new NotFoundError('Member');
    }

    const updated = await tx.member.update({
      where: { id: member_id },
      data: {
        status: 'SUSPENDED',
        updated_at: new Date(),
      },
    });

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id: branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'Member',
        target_id: member_id,
        after_state: { status: 'SUSPENDED', reason: data.reason },
      },
    });

    return updated;
  });
}

export async function deactivateMember(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  member_id: string,
  data: MemberActionInput,
) {
  return prisma.$transaction(async (tx) => {
    const member = await tx.member.findUnique({
      where: { id: member_id },
    });

    if (!member || member.organization_id !== organization_id || member.branch_id !== branch_id) {
      throw new NotFoundError('Member');
    }

    const updated = await tx.member.update({
      where: { id: member_id },
      data: {
        status: 'INACTIVE',
        updated_at: new Date(),
      },
    });

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id: branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'Member',
        target_id: member_id,
        after_state: { status: 'INACTIVE', reason: data.reason },
      },
    });

    return updated;
  });
}

export async function createAssistedAdmission(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: AssistedAdmissionInput,
) {
  return prisma.$transaction(async (tx) => {
    // 1. Check or Create User
    let targetUserId = ulid();
    if (data.email) {
      const existingUser = await tx.user.findUnique({ where: { email: data.email } });
      if (existingUser) {
        targetUserId = existingUser.id;
      } else {
        await tx.user.create({
          data: {
            id: targetUserId,
            name: (data.first_name + ' ' + (data.last_name || '')).trim(),
            email: data.email,
            phone: data.phone,
          },
        });
      }
    } else {
      await tx.user.create({
        data: {
          id: targetUserId,
          name: (data.first_name + ' ' + (data.last_name || '')).trim(),
          phone: data.phone,
        },
      });
    }

    const memberRole = await tx.role.findFirst({
      where: { organization_id, system_key: 'MEMBER' },
    });

    const memberId = ulid();
    const member = await tx.member.create({
      data: {
        id: memberId,
        organization_id,
        branch_id,
        user_id: targetUserId,
        role_id: memberRole?.id,
        member_number: 'MEM-' + Date.now().toString().slice(-6),
        status: 'ACTIVE',
      },
    });

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id: branch_id,
        actor_id,
        action: 'CREATE',
        target_type: 'Member',
        target_id: memberId,
        after_state: { status: 'ACTIVE', admission_type: 'ASSISTED' },
      },
    });

    return member;
  });
}

export async function updateMember(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  member_id: string,
  data: UpdateMemberInput,
) {
  return prisma.$transaction(async (tx) => {
    const member = await tx.member.findUnique({
      where: { id: member_id },
    });

    if (!member || member.organization_id !== organization_id || member.branch_id !== branch_id) {
      throw new NotFoundError('Member');
    }

    const updated = await tx.member.update({
      where: { id: member_id },
      data: {
        role_id: data.role_id !== undefined ? data.role_id : undefined,
          subscription_id: data.subscription_id !== undefined ? data.subscription_id : undefined,
          shift_id: data.shift_id !== undefined ? data.shift_id : undefined,
          salary_structure_id: data.salary_structure_id !== undefined ? data.salary_structure_id : undefined,
        // other configuration fields can be added here if they exist in DB
        updated_at: new Date(),
      },
      include: {
        user: true,
        role: true,
      },
    });

    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id: branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'Member',
        target_id: member_id,
        after_state: data as any,
      },
    });

    return updated;
  });
}
export async function listOrganizationMembers(organizationId: string, branchId?: string) {
  const where: any = { organization_id: organizationId };
  if (branchId && branchId !== 'none') {
    where.branch_id = branchId;
  }
  
  const members = await prisma.member.findMany({
    where,
    include: {
      user: true,
      role: true,
      branch: true,
    },
    orderBy: { created_at: 'desc' }
  });
  
  // If user requested 'none', we could theoretically filter here, but we made branch_id required.
  // We'll just return an empty array or filter manually if we changed schema.
  if (branchId === 'none') {
    return { data: members.filter(m => !m.branch_id) };
  }
  
  return {
    data: members,
    meta: {
      total: members.length,
      page: 1,
      limit: members.length
    }
  };
}



