import { prisma } from '../../lib/prisma';

type PermissionRole = {
  system_key: string | null;
  permissions: string[];
};

type MemberWithPermissionRoles = {
  role: PermissionRole | null;
  role_assignments: Array<{ role: PermissionRole | null }>;
};

export function permissionsForMember(member: MemberWithPermissionRoles): Set<string> {
  const permissions = new Set<string>();
  const roles =
    member.role_assignments.length > 0
      ? member.role_assignments
          .map((assignment) => assignment.role)
          .filter((role): role is PermissionRole => role != null)
      : member.role
        ? [member.role]
        : [];

  // Owner role grants ALL. Check every effective assignment so a legacy member
  // with a null primary role cannot lose owner privileges or bypass scoping.
  if (roles.some((role) => role.system_key === 'OWNER')) {
    permissions.add('ALL');
  } else {
    for (const role of roles) {
      for (const permission of role.permissions) permissions.add(permission);
    }
  }
  return permissions;
}

export async function resolveEffectivePermissions(
  user_id: string,
  organization_id: string,
  branch_id: string,
): Promise<Set<string>> {
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

  if (!member) return new Set<string>();

  return permissionsForMember(member);
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
