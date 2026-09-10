import { prisma } from '../../lib/prisma';

import type { DiscoverBranchesQuery } from './branches.schema';

export async function discoverBranches({ query, limit, cursor }: DiscoverBranchesQuery) {
  const branches = await prisma.branch.findMany({
    take: limit + 1,
    cursor: cursor ? { id: cursor } : undefined,
    where: {
      organization: {
        status: 'ACTIVE',
      },
      ...(query
        ? {
            OR: [
              { name: { contains: query, mode: 'insensitive' } },
              { organization: { name: { contains: query, mode: 'insensitive' } } },
            ],
          }
        : {}),
    },
    include: {
      organization: {
        select: {
          id: true,
          name: true,
          logo_url: true,
        },
      },
    },
    orderBy: { created_at: 'desc' },
  });

  let nextCursor: string | undefined = undefined;
  if (branches.length > limit) {
    const nextItem = branches.pop();
    nextCursor = nextItem?.id;
  }

  return { data: branches, nextCursor };
}
