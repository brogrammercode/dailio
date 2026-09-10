import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';

import type { CreateOrganizationInput, CreateLocationInput, UpdateOrganizationInput } from './organizations.schema';

const SYSTEM_PERMISSIONS = [
  'GYM_READ', 'GYM_UPDATE', 'GYM_ARCHIVE',
  'BRANCH_READ', 'BRANCH_CREATE', 'BRANCH_UPDATE', 'BRANCH_ARCHIVE', 'BRANCH_SETTINGS_UPDATE',
  'ROLE_READ', 'ROLE_CREATE', 'ROLE_UPDATE', 'ROLE_DELETE', 'ROLE_ASSIGN',
  'MEMBER_READ_SELF', 'MEMBER_READ_ALL', 'MEMBER_CREATE', 'MEMBER_UPDATE_SELF', 'MEMBER_UPDATE_ALL',
  'MEMBER_SUSPEND', 'MEMBER_DEACTIVATE',
  'JOIN_REQUEST_READ', 'JOIN_REQUEST_APPROVE', 'JOIN_REQUEST_REJECT',
  'ATTENDANCE_READ_SELF', 'ATTENDANCE_READ_ALL', 'ATTENDANCE_CREATE_SELF', 'ATTENDANCE_CREATE_ALL',
  'ATTENDANCE_UPDATE', 'ATTENDANCE_DELETE', 'ATTENDANCE_EXPORT',
  'SHIFT_READ_SELF', 'SHIFT_READ_ALL', 'SHIFT_MANAGE',
  'LEAVE_READ_SELF', 'LEAVE_READ_ALL', 'LEAVE_CREATE_SELF', 'LEAVE_MANAGE',
  'HOLIDAY_READ', 'HOLIDAY_MANAGE',
  'PLAN_READ', 'PLAN_MANAGE',
  'SUBSCRIPTION_READ_SELF', 'SUBSCRIPTION_READ_ALL', 'SUBSCRIPTION_CREATE', 'SUBSCRIPTION_UPDATE', 'SUBSCRIPTION_CANCEL',
  'PAYMENT_READ_SELF', 'PAYMENT_READ_ALL', 'PAYMENT_CREATE', 'PAYMENT_REFUND', 'PAYMENT_VOID',
  'FINE_READ_SELF', 'FINE_READ_ALL', 'FINE_MANAGE',
  'REMINDER_READ_SELF', 'REMINDER_READ_ALL', 'REMINDER_MANAGE',
  'ANNOUNCEMENT_READ', 'ANNOUNCEMENT_CREATE', 'ANNOUNCEMENT_UPDATE', 'ANNOUNCEMENT_DELETE',
  'REPORT_READ', 'REPORT_EXPORT', 'AUDIT_READ',
];

const MEMBER_PERMISSIONS = [
  'GYM_READ', 'BRANCH_READ',
  'MEMBER_READ_SELF', 'MEMBER_UPDATE_SELF',
  'ATTENDANCE_READ_SELF', 'ATTENDANCE_CREATE_SELF',
  'SHIFT_READ_SELF',
  'LEAVE_READ_SELF', 'LEAVE_CREATE_SELF',
  'HOLIDAY_READ',
  'PLAN_READ',
  'SUBSCRIPTION_READ_SELF',
  'PAYMENT_READ_SELF', 'FINE_READ_SELF',
  'REMINDER_READ_SELF', 'ANNOUNCEMENT_READ',
];

const ADMIN_PERMISSIONS = [
  ...MEMBER_PERMISSIONS,
  'MEMBER_READ_ALL', 'MEMBER_CREATE', 'MEMBER_UPDATE_ALL', 'MEMBER_SUSPEND', 'MEMBER_DEACTIVATE',
  'JOIN_REQUEST_READ', 'JOIN_REQUEST_APPROVE', 'JOIN_REQUEST_REJECT',
  'ATTENDANCE_READ_ALL', 'ATTENDANCE_CREATE_ALL', 'ATTENDANCE_UPDATE',
  'SHIFT_READ_ALL', 'SHIFT_MANAGE',
  'LEAVE_READ_ALL', 'LEAVE_MANAGE', 'HOLIDAY_MANAGE',
  'PLAN_MANAGE', 'SUBSCRIPTION_READ_ALL', 'SUBSCRIPTION_CREATE', 'SUBSCRIPTION_UPDATE', 'SUBSCRIPTION_CANCEL',
  'PAYMENT_READ_ALL', 'PAYMENT_CREATE', 'FINE_READ_ALL', 'FINE_MANAGE',
  'REMINDER_READ_ALL', 'REMINDER_MANAGE',
  'ANNOUNCEMENT_CREATE', 'ANNOUNCEMENT_UPDATE', 'ANNOUNCEMENT_DELETE',
  'REPORT_READ',
];

async function seedRoles(tx: any, organization_id: string) {
  const ownerRole = await tx.role.create({
    data: { id: ulid(), organization_id, system_key: 'OWNER', name: 'Owner', is_protected: true, is_system: true, permissions: SYSTEM_PERMISSIONS },
  });
  const adminRole = await tx.role.create({
    data: { id: ulid(), organization_id, system_key: 'ADMIN', name: 'Admin', is_protected: true, is_system: true, permissions: ADMIN_PERMISSIONS },
  });
  const memberRole = await tx.role.create({
    data: { id: ulid(), organization_id, system_key: 'MEMBER', name: 'Member', is_protected: true, is_system: true, permissions: MEMBER_PERMISSIONS },
  });
  return { ownerRole, adminRole, memberRole };
}

export async function createOrganizationWithFirstLocation(
  user_id: string,
  organizationData: CreateOrganizationInput,
  locationData: CreateLocationInput,
) {
  return prisma.$transaction(
    async (tx: any) => {
      // 2. Create organization
      const organization_id = ulid();
      const slug = organizationData.name.toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-' + organization_id.slice(-6);
      const organization = await tx.organization.create({
        data: { id: organization_id, ...organizationData, slug, status: 'ACTIVE' },
      });

      // 3. Create first branch
      const branch_id = ulid();
      const location = await tx.branch.create({
        data: { id: branch_id, organization_id, ...locationData },
      });

      // 4. Seed roles
      const { ownerRole } = await seedRoles(tx, organization_id);

      // 5. Create owner member
      const member = await tx.member.create({
        data: {
          id: ulid(),
          organization_id,
          branch_id,
          user_id,
          is_employee: true,
          role_id: ownerRole.id,
          status: 'ACTIVE',
          member_number: '001',
        },
      });

      // 6. Audit
      await tx.auditLog.create({
        data: {
          id: ulid(),
          organization_id,
          actor_id: user_id,
          action: 'CREATE',
          target_type: 'Organization',
          target_id: organization_id,
          source: 'API',
        },
      });

      return { organization, location, organization_membership: member, location_membership: member };
    },
    { maxWait: 5000, timeout: 20000 }
  );
}

export async function getOrganization(organization_id: string, user_id: string) {
  const membership = await prisma.member.findFirst({ where: { organization_id, user_id } });
  if (!membership) throw new NotFoundError('Organization');
  return prisma.organization.findUnique({ where: { id: organization_id } });
}

export async function getUserOrganizations(user_id: string) {
  const members = await prisma.member.findMany({
    where: { user_id, status: 'ACTIVE' },
    include: {
      organization: true,
      branch: true,
      role: true
    },
  });
  
  const orgMap = new Map<string, any>();
  
  for (const m of members) {
    if (!orgMap.has(m.organization_id)) {
      orgMap.set(m.organization_id, {
        id: m.id,
        organization_id: m.organization_id,
        user_id: m.user_id,
        status: m.status,
        organization: m.organization,
        location_memberships: []
      });
    }
    const orgEntry = orgMap.get(m.organization_id);
    orgEntry.location_memberships.push({
      id: m.id,
      location_id: m.branch_id,
      location: m.branch,
      status: m.status,
    });
  }
  
  return Array.from(orgMap.values());
}

export async function updateOrganization(organization_id: string, user_id: string, data: UpdateOrganizationInput) {
  const membership = await prisma.member.findFirst({ where: { organization_id, user_id, status: 'ACTIVE' } });
  if (!membership) throw new NotFoundError('Organization');
  return prisma.organization.update({ where: { id: organization_id }, data });
}
