import { prisma } from '../../lib/prisma';

export async function resolveEffectivePermissions(
  user_id: string,
  organization_id: string,
  branch_id: string,
): Promise<Set<string>> {
  const permissions = new Set<string>();

  // Get active member
  const member = await prisma.member.findFirst({
    where: {
      organization_id,
      branch_id,
      user_id,
      status: 'ACTIVE',
    },
    include: {
      role: true,
    },
  });

  if (!member || !member.role) return permissions;

  // Owner role grants ALL
  if (member.role.system_key === 'OWNER') {
    permissions.add('ALL');
  } else {
    for (const perm of member.role.permissions) {
      permissions.add(perm);
    }
  }

  return permissions;
}

export async function getMemberForUser(
  user_id: string,
  organization_id: string,
  branch_id: string,
) {
  return prisma.member.findFirst({
    where: {
      organization_id,
      branch_id,
      user_id,
      status: 'ACTIVE',
    },
  });
}
