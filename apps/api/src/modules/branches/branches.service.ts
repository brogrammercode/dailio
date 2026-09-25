import { prisma } from '../../lib/prisma';
import { randomUUID } from 'node:crypto';

import type {
  DiscoverBranchesQuery,
  CreateBranchInput,
  UpdateBranchInput,
} from './branches.schema';

export async function discoverBranches({ query, limit, cursor, org_id }: DiscoverBranchesQuery) {
  const branches = await prisma.branch.findMany({
    take: limit + 1,
    cursor: cursor ? { id: cursor } : undefined,
    where: {
      organization: { status: 'ACTIVE' },
      ...(org_id ? { organization_id: org_id } : {}),
      ...(query
        ? {
            OR: [
              { name: { contains: query, mode: 'insensitive' } },
              { organization: { name: { contains: query, mode: 'insensitive' } } },
            ],
          }
        : {}),
    },
    include: { organization: { select: { id: true, name: true, logo_url: true } } },
    orderBy: { created_at: 'desc' },
  });

  let nextCursor: string | undefined = undefined;
  if (branches.length > limit) {
    const nextItem = branches.pop();
    nextCursor = nextItem?.id;
  }
  return { data: branches, nextCursor };
}

export async function createBranch(
  organizationId: string,
  data: CreateBranchInput,
  actorId: string,
) {
  return prisma.$transaction(async (tx) => {
    const branch = await tx.branch.create({
      data: { ...data, organization_id: organizationId },
    });
    await tx.auditLog.create({
      data: {
        id: randomUUID(),
        organization_id: organizationId,
        branch_id: branch.id,
        actor_id: actorId,
        action: 'CREATE',
        target_type: 'Branch',
        target_id: branch.id,
        after_state: { name: branch.name, timezone: branch.timezone },
      },
    });
    return branch;
  });
}

export async function updateBranch(
  branchId: string,
  organizationId: string,
  data: UpdateBranchInput,
  actorId: string,
) {
  return prisma.$transaction(async (tx) => {
    const before = await tx.branch.findFirst({
      where: { id: branchId, organization_id: organizationId },
    });
    if (!before) return null;
    const branch = await tx.branch.update({ where: { id: branchId }, data });
    await tx.auditLog.create({
      data: {
        id: randomUUID(),
        organization_id: organizationId,
        branch_id: branch.id,
        actor_id: actorId,
        action: 'UPDATE',
        target_type: 'Branch',
        target_id: branch.id,
        before_state: { name: before.name, timezone: before.timezone, status: before.status },
        after_state: { name: branch.name, timezone: branch.timezone, status: branch.status },
      },
    });
    return branch;
  });
}
export async function getBranchById(branchId: string, organizationId: string) {
  return await prisma.branch.findUnique({
    where: { id: branchId, organization_id: organizationId },
  });
}
export async function getOrganizationBranches(
  organizationId: string,
  contextBranchId: string,
  permissions: Set<string>,
) {
  return await prisma.branch.findMany({
    where: {
      organization_id: organizationId,
      ...(!permissions.has('ALL') ? { id: contextBranchId } : {}),
    },
    orderBy: { created_at: 'asc' },
  });
}
