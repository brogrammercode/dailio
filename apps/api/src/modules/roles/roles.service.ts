/* eslint-disable @typescript-eslint/no-explicit-any */
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { NotFoundError, ConflictError } from '../../lib/errors';

import type { CreateRoleInput, UpdateRoleInput } from './roles.schema';

export async function getRoles(organization_id: string, branch_id?: string) {
  const where: any = { organization_id };
  if (branch_id === 'none') {
    where.branch_id = null;
  } else if (branch_id) {
    where.OR = [{ branch_id }, { branch_id: null }];
  }
  return prisma.role.findMany({
    where,
    orderBy: { created_at: 'asc' },
  });
}

export async function createRole(data: CreateRoleInput, actorId: string) {
  const existingRole = await prisma.role.findUnique({
    where: {
      organization_id_name: {
        organization_id: data.organization_id,
        name: data.name,
      },
    },
  });

  if (existingRole) {
    throw new ConflictError('A role with this name already exists in the organization.');
  }

  const role = await prisma.role.create({
    data: {
      id: ulid(),
      organization_id: data.organization_id,
      name: data.name,
      branch_id: data.branch_id || null,
      permissions: data.permissions,
      is_protected: false,
      is_system: false,
    },
  });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id: data.organization_id,
      branch_id: data.branch_id,
      actor_id: actorId,
      action: 'CREATE',
      target_type: 'Role',
      target_id: role.id,
      after_state: { name: role.name, branch_id: role.branch_id },
    },
  });
  return role;
}

export async function updateRole(
  role_id: string,
  data: UpdateRoleInput,
  organizationId: string,
  branchId: string,
  actorId: string,
  permissions: Set<string>,
) {
  const role = await prisma.role.findUnique({
    where: { id: role_id },
  });

  if (!role) {
    throw new NotFoundError('Role');
  }
  if (role.organization_id !== organizationId) throw new NotFoundError('Role');
  if (role.branch_id && role.branch_id !== branchId && !permissions.has('ALL')) {
    throw new NotFoundError('Role');
  }
  if (data.branch_id && data.branch_id !== branchId && !permissions.has('ALL')) {
    throw new ConflictError('Role branch scope is invalid');
  }

  if (data.name && data.name !== role.name) {
    const existingRole = await prisma.role.findUnique({
      where: {
        organization_id_name: {
          organization_id: role.organization_id,
          name: data.name,
        },
      },
    });

    if (existingRole) {
      throw new ConflictError('A role with this name already exists in the organization.');
    }
  }

  const updated = await prisma.role.update({
    where: { id: role_id },
    data: {
      ...(data.name !== undefined && { name: data.name }),
      ...(data.permissions !== undefined && { permissions: data.permissions }),
      ...(data.branch_id !== undefined && { branch_id: data.branch_id }),
    },
  });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id: organizationId,
      branch_id: updated.branch_id ?? branchId,
      actor_id: actorId,
      action: 'UPDATE',
      target_type: 'Role',
      target_id: updated.id,
      after_state: { name: updated.name, branch_id: updated.branch_id },
    },
  });
  return updated;
}
