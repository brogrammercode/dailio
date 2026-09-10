import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { NotFoundError, ConflictError } from '../../lib/errors';

import type { CreateRoleInput, UpdateRoleInput } from './roles.schema';

export async function getRoles(organization_id: string) {
  return prisma.role.findMany({
    where: { organization_id },
    orderBy: { created_at: 'asc' },
  });
}

export async function createRole(data: CreateRoleInput) {
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

  return prisma.role.create({
    data: {
      id: ulid(),
      organization_id: data.organization_id,
      name: data.name,
      permissions: data.permissions,
      is_protected: false,
      is_system: false,
    },
  });
}

export async function updateRole(role_id: string, data: UpdateRoleInput) {
  const role = await prisma.role.findUnique({
    where: { id: role_id },
  });

  if (!role) {
    throw new NotFoundError('Role');
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

  return prisma.role.update({
    where: { id: role_id },
    data: {
      ...(data.name !== undefined && { name: data.name }),
      ...(data.permissions !== undefined && { permissions: data.permissions }),
    },
  });
}
