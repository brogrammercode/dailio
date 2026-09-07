import { prisma } from '../../lib/prisma';

export async function resolveEffectivePermissions(
  user_id: string,
  organization_id: string,
  location_id: string,
): Promise<Set<string>> {
  const permissions = new Set<string>();

  // Get active location membership
  const location_membership = await prisma.locationMembership.findFirst({
    where: {
      organization_id,
      location_id,
      organization_membership: { user_id },
      status: 'ACTIVE',
    },
    include: {
      role_assignments: {
        where: { revoked_at: null },
        include: {
          role: true,
        },
      },
    },
  });

  if (!location_membership) return permissions;

  for (const assignment of location_membership.role_assignments) {
    // Owner role grants ALL
    if (assignment.role.system_key === 'OWNER') {
      permissions.add('ALL');
      break;
    }
    for (const perm of assignment.role.permissions) {
      permissions.add(perm);
    }
  }

  return permissions;
}

export async function getLocationMembershipForUser(
  user_id: string,
  organization_id: string,
  location_id: string,
) {
  return prisma.locationMembership.findFirst({
    where: {
      organization_id,
      location_id,
      organization_membership: { user_id },
      status: 'ACTIVE',
    },
  });
}
