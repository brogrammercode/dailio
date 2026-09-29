/* eslint-disable @typescript-eslint/no-explicit-any */
import { ulid } from 'ulid';
import type { Prisma } from '@prisma/client';

import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError } from '../../lib/errors';
import { findBranchRecipientUserIds, notify } from '../notifications/notifications.service';

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
        shift: true,
        role: true,
        subscriptions: {
          where: { status: { in: ['ACTIVE', 'UPCOMING', 'EXPIRED', 'PAUSED'] } },
          orderBy: { end_date: 'desc' },
          take: 1,
          include: { plan: true },
        },
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
      role_assignments: {
        where: { effective_to: null },
        orderBy: { priority: 'asc' },
        include: { role: true },
      },
      subscriptions: {
        orderBy: { end_date: 'desc' },
        include: { plan: true },
      },
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
  const result = await prisma.$transaction(async (tx) => {
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

    return { updated, userId: member.user_id };
  });

  try {
    await notify({
      type: 'MEMBERSHIP_SUSPENDED',
      organizationId: organization_id,
      branchId: branch_id,
      entityType: 'Member',
      entityId: member_id,
      recipientUserIds: [result.userId],
      title: 'Membership suspended',
      body: data.reason
        ? `Your membership has been suspended: ${data.reason}`
        : 'Your membership has been suspended. Contact the branch for details.',
      data: { organization_id, branch_id, entity_id: member_id },
      dedupeKey: `member:${member_id}:suspended:${result.updated.updated_at.toISOString()}`,
    });
    const reviewers = await findBranchRecipientUserIds(
      organization_id,
      branch_id,
      'MEMBER_READ_ALL',
    );
    await notify({
      type: 'MEMBERSHIP_SUSPENDED_REVIEW',
      organizationId: organization_id,
      branchId: branch_id,
      entityType: 'Member',
      entityId: member_id,
      recipientUserIds: reviewers.filter((userId) => userId !== result.userId),
      title: 'Membership suspended',
      body: 'A member has been suspended and may need follow-up.',
      data: { organization_id, branch_id, entity_id: member_id },
      dedupeKey: `member:${member_id}:suspended-review:${result.updated.updated_at.toISOString()}`,
    });
  } catch {
    // Notification delivery must not undo a committed membership change.
  }
  return result.updated;
}

export async function deactivateMember(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  member_id: string,
  data: MemberActionInput,
) {
  const result = await prisma.$transaction(async (tx) => {
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

    return { updated, userId: member.user_id };
  });

  try {
    await notify({
      type: 'MEMBERSHIP_DEACTIVATED',
      organizationId: organization_id,
      branchId: branch_id,
      entityType: 'Member',
      entityId: member_id,
      recipientUserIds: [result.userId],
      title: 'Membership deactivated',
      body: data.reason
        ? `Your membership has been deactivated: ${data.reason}`
        : 'Your membership has been deactivated. Contact the branch for details.',
      data: { organization_id, branch_id, entity_id: member_id },
      dedupeKey: `member:${member_id}:deactivated:${result.updated.updated_at.toISOString()}`,
    });
    const reviewers = await findBranchRecipientUserIds(
      organization_id,
      branch_id,
      'MEMBER_READ_ALL',
    );
    await notify({
      type: 'MEMBERSHIP_DEACTIVATED_REVIEW',
      organizationId: organization_id,
      branchId: branch_id,
      entityType: 'Member',
      entityId: member_id,
      recipientUserIds: reviewers.filter((userId) => userId !== result.userId),
      title: 'Membership deactivated',
      body: 'A member has been deactivated and may need follow-up.',
      data: { organization_id, branch_id, entity_id: member_id },
      dedupeKey: `member:${member_id}:deactivated-review:${result.updated.updated_at.toISOString()}`,
    });
  } catch {
    // Notification delivery must not undo a committed membership change.
  }
  return result.updated;
}

export async function createAssistedAdmission(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: AssistedAdmissionInput,
) {
  const member = await prisma.$transaction(async (tx) => {
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
    if (memberRole?.id) {
      await tx.memberRoleAssignment.create({
        data: {
          id: ulid(),
          organization_id,
          branch_id,
          member_id: member.id,
          role_id: memberRole.id,
          priority: 0,
          updated_at: new Date(),
        },
      });
    }

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

  try {
    await notify({
      type: 'MEMBERSHIP_CREATED',
      organizationId: organization_id,
      branchId: branch_id,
      entityType: 'Member',
      entityId: member.id,
      recipientUserIds: [member.user_id],
      title: 'Branch membership created',
      body: 'Your branch membership is active and ready to use.',
      data: { organization_id, branch_id, entity_id: member.id },
      dedupeKey: `member:${member.id}:created`,
    });
  } catch {
    // Notification delivery must not undo a committed admission.
  }
  return member;
}

export async function updateMember(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  member_id: string,
  data: UpdateMemberInput,
) {
  const updated = await prisma.$transaction(async (tx) => {
    const member = await tx.member.findUnique({
      where: { id: member_id },
    });

    if (!member || member.organization_id !== organization_id || member.branch_id !== branch_id) {
      throw new NotFoundError('Member');
    }

    if (data.manager_member_id !== undefined && data.manager_member_id !== null) {
      const manager = await tx.member.findUnique({
        where: { id: data.manager_member_id },
        select: {
          id: true,
          organization_id: true,
          branch_id: true,
          status: true,
          manager_member_id: true,
        },
      });
      if (
        !manager ||
        manager.organization_id !== organization_id ||
        manager.branch_id !== branch_id ||
        manager.status !== 'ACTIVE'
      ) {
        throw new NotFoundError('Manager member');
      }

      const visited = new Set<string>();
      let cursor: string | null = manager.id;
      while (cursor) {
        if (cursor === member_id || visited.has(cursor)) {
          throw new ConflictError('Reporting hierarchy cannot contain a cycle');
        }
        visited.add(cursor);
        let nextManagerId: string | null;
        if (cursor === manager.id) {
          nextManagerId = manager.manager_member_id;
        } else {
          const current: { manager_member_id: string | null } | null = await tx.member.findUnique({
            where: { id: cursor },
            select: { manager_member_id: true },
          });
          nextManagerId = current?.manager_member_id ?? null;
        }
        cursor = nextManagerId;
      }
    }

    const requestedRoleIds =
      data.role_ids !== undefined
        ? (data.role_ids ?? [])
        : data.role_id !== undefined
          ? data.role_id
            ? [data.role_id]
            : []
          : null;
    const now = new Date();
    if (requestedRoleIds !== null) {
      const roleIds = [...new Set(requestedRoleIds)];
      const roles = await tx.role.findMany({
        where: {
          id: { in: roleIds },
          organization_id,
          OR: [{ branch_id }, { branch_id: null }],
        },
        select: { id: true },
      });
      if (roles.length !== roleIds.length) throw new NotFoundError('Member role target');

      const activeAssignments = await tx.memberRoleAssignment.findMany({
        where: { member_id, effective_to: null },
      });
      for (const assignment of activeAssignments) {
        if (!roleIds.includes(assignment.role_id)) {
          await tx.memberRoleAssignment.update({
            where: { id: assignment.id },
            data: { effective_to: now },
          });
        }
      }
      for (const [priority, roleId] of roleIds.entries()) {
        const current = activeAssignments.find((assignment) => assignment.role_id === roleId);
        if (current) {
          if (current.priority !== priority) {
            await tx.memberRoleAssignment.update({
              where: { id: current.id },
              data: { priority },
            });
          }
          continue;
        }
        await tx.memberRoleAssignment.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            member_id,
            role_id: roleId,
            priority,
            effective_from: now,
            updated_at: now,
          },
        });
      }
    }

    const updated = await tx.member.update({
      where: { id: member_id },
      data: {
        role_id:
          data.role_ids !== undefined
            ? (data.role_ids?.[0] ?? null)
            : data.role_id !== undefined
              ? data.role_id
              : undefined,
        manager_member_id:
          data.manager_member_id !== undefined ? data.manager_member_id : undefined,
        subscription_id: data.subscription_id !== undefined ? data.subscription_id : undefined,
        shift_id: data.shift_id !== undefined ? data.shift_id : undefined,
        salary_structure_id:
          data.salary_structure_id !== undefined ? data.salary_structure_id : undefined,
        // other configuration fields can be added here if they exist in DB
        updated_at: new Date(),
      },
      include: {
        user: true,
        shift: true,
        role: true,
        role_assignments: {
          where: { effective_to: null },
          orderBy: { priority: 'asc' },
          include: { role: true },
        },
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

  const hasConfigurationChange =
    data.role_id !== undefined ||
    data.role_ids !== undefined ||
    data.manager_member_id !== undefined ||
    data.subscription_id !== undefined ||
    data.shift_id !== undefined ||
    data.salary_structure_id !== undefined;
  if (hasConfigurationChange) {
    try {
      await notify({
        type: 'MEMBER_CONFIGURATION_UPDATED',
        organizationId: organization_id,
        branchId: branch_id,
        entityType: 'Member',
        entityId: member_id,
        recipientUserIds: [updated.user.id],
        title: 'Membership details updated',
        body: 'Your branch membership details have been updated.',
        data: { organization_id, branch_id, entity_id: member_id },
        dedupeKey: `member:${member_id}:configuration:${updated.updated_at.toISOString()}`,
      });
    } catch {
      // Notification delivery must not undo a committed member update.
    }
  }
  if (data.shift_id !== undefined) {
    try {
      await notify({
        type: data.shift_id ? 'SHIFT_ASSIGNED' : 'SHIFT_UNASSIGNED',
        organizationId: organization_id,
        branchId: branch_id,
        entityType: 'Member',
        entityId: member_id,
        recipientUserIds: [updated.user.id],
        title: data.shift_id ? 'Shift assigned' : 'Shift removed',
        body: data.shift_id
          ? `You have been assigned to ${updated.shift?.name ?? 'a new shift'}.`
          : 'Your assigned shift has been removed.',
        data: { organization_id, branch_id, entity_id: member_id },
        dedupeKey: `member:${member_id}:shift:${updated.shift_id ?? 'none'}:${updated.updated_at.toISOString()}`,
      });
    } catch {
      // Notification delivery must not undo a committed member update.
    }
  }
  return updated;
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
      subscriptions: {
        where: { status: { in: ['ACTIVE', 'UPCOMING', 'EXPIRED', 'PAUSED'] } },
        orderBy: { end_date: 'desc' },
        take: 1,
        include: { plan: true },
      },
    },
    orderBy: { created_at: 'desc' },
  });

  // If user requested 'none', we could theoretically filter here, but we made branch_id required.
  // We'll just return an empty array or filter manually if we changed schema.
  if (branchId === 'none') {
    return { data: members.filter((m) => !m.branch_id) };
  }

  return {
    data: members,
    meta: {
      total: members.length,
      page: 1,
      limit: members.length,
    },
  };
}
