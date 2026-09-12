import { prisma } from '../../lib/prisma';
import type { DiscoverBranchesQuery, CreateBranchInput, UpdateBranchInput } from './branches.schema';

export async function discoverBranches({ query, limit, cursor }: DiscoverBranchesQuery) {
  const branches = await prisma.branch.findMany({
    take: limit + 1,
    cursor: cursor ? { id: cursor } : undefined,
    where: {
      organization: { status: 'ACTIVE' },
      ...(query
        ? { OR: [{ name: { contains: query, mode: 'insensitive' } }, { organization: { name: { contains: query, mode: 'insensitive' } } }] }
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

export async function createBranch(organizationId: string, data: CreateBranchInput) {
  return await prisma.branch.create({
    data: { ...data, organization_id: organizationId },
  });
}

export async function updateBranch(branchId: string, organizationId: string, data: UpdateBranchInput) {
  return await prisma.branch.update({
    where: { id: branchId, organization_id: organizationId },
    data,
  });
}
export async function getBranchById(branchId: string, organizationId: string) {
  return await prisma.branch.findUnique({
    where: { id: branchId, organization_id: organizationId },
  });
}
export async function getOrganizationBranches(organizationId: string) {
  return await prisma.branch.findMany({
    where: { organization_id: organizationId },
    orderBy: { created_at: 'asc' },
  });
}

