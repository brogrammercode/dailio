import { prisma } from '../../lib/prisma';

import type { DiscoverLocationsQuery } from './locations.schema';

export async function discoverLocations({ query, limit, cursor }: DiscoverLocationsQuery) {
  const locations = await prisma.location.findMany({
    take: limit + 1,
    cursor: cursor ? { id: cursor } : undefined,
    where: {
      status: 'ACTIVE',
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
  if (locations.length > limit) {
    const nextItem = locations.pop();
    nextCursor = nextItem?.id;
  }

  return { data: locations, nextCursor };
}
