import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';

import type { UpdateProfileInput } from './users.schema';

export async function updateProfile(user_id: string, data: UpdateProfileInput) {
  const user = await prisma.user.findUnique({ where: { id: user_id } });
  if (!user) throw new NotFoundError('User');
  return prisma.user.update({ where: { id: user_id }, data });
}

export async function getUserContexts(user_id: string) {
  const organization_memberships = await prisma.organizationMembership.findMany({
    where: { user_id, status: 'ACTIVE' },
    include: {
      organization: true,
      location_memberships: {
        where: { status: 'ACTIVE' },
        include: { location: true },
      },
    },
  });
  return organization_memberships;
}
