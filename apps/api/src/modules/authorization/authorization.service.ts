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
      role_assignments: {
        where: {
          organization_id,
          branch_id,
          effective_from: { lte: new Date() },
          OR: [{ effective_to: null }, { effective_to: { gt: new Date() } }],
        },
        orderBy: [{ priority: 'asc' }, { effective_from: 'desc' }, { id: 'asc' }],
        include: { role: true },
      },
    },
  });

  if (!member) return permissions;

  const roles =
    member.role_assignments.length > 0
      ? member.role_assignments.map((assignment) => assignment.role)
      : member.role
        ? [member.role]
        : [];

  // Owner role grants ALL. Check every effective assignment so a legacy member
  // with a null primary role cannot lose owner privileges or bypass scoping.
  if (roles.some((role) => role.system_key === 'OWNER')) {
    permissions.add('ALL');
  } else {
    for (const role of roles) {
      for (const perm of role.permissions) {
        permissions.add(perm);
      }
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
