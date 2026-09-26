/* eslint-disable @typescript-eslint/no-explicit-any */
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ForbiddenError, NotFoundError } from '../../lib/errors';

export async function listSalaryStructures(organization_id: string, branch_id?: string) {
  const structures = await prisma.salaryStructure.findMany({
    where: {
      organization_id,
      ...(branch_id === 'none' ? { branch_id: null } : branch_id ? { branch_id } : {}),
    } as any,
    include: {
      _count: {
        select: { members: true },
      },
      members: {
        take: 3,
        select: {
          user: {
            select: {
              avatar_url: true,
            },
          },
        },
      },
    },
    orderBy: { created_at: 'desc' },
  });

  return structures.map((s) => {
    const avatarUrls = s.members.map((m) => m.user.avatar_url).filter((url) => url != null);
    return {
      id: s.id,
      organization_id: s.organization_id,
      branch_id: s.branch_id,
      name: s.name,
      amount: s.amount,
      earnings: s.earnings,
      deductions: s.deductions,
      created_at: s.created_at,
      updated_at: s.updated_at,
      membersCount: s._count.members,
      avatars: avatarUrls,
    };
  });
}

export async function createSalaryStructure(
  organization_id: string,
  data: any,
  actorId: string,
  contextBranchId: string,
  permissions: Set<string>,
) {
  const branchId = data.branch_id === 'none' ? null : (data.branch_id ?? contextBranchId);
  if (branchId && branchId !== contextBranchId && !permissions.has('ALL')) {
    throw new ForbiddenError('Salary structure is limited to the active branch');
  }
  const structure = await prisma.salaryStructure.create({
    data: {
      organization_id,
      name: data.name,
      amount: data.amount ?? 0,
      branch_id: branchId,
      earnings: data.earnings ?? [],
      deductions: data.deductions ?? [],
    },
  });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id,
      branch_id: structure.branch_id ?? contextBranchId,
      actor_id: actorId,
      action: 'CREATE',
      target_type: 'SalaryStructure',
      target_id: structure.id,
      after_state: { name: structure.name },
    },
  });
  return structure;
}

export async function updateSalaryStructure(
  organization_id: string,
  id: string,
  data: any,
  actorId: string,
  contextBranchId: string,
  permissions: Set<string>,
) {
  const existing = await prisma.salaryStructure.findFirst({ where: { id, organization_id } });
  if (!existing) throw new NotFoundError('Salary structure not found');
  if (existing.branch_id && existing.branch_id !== contextBranchId && !permissions.has('ALL')) {
    throw new NotFoundError('Salary structure not found');
  }

  const updateData: any = { ...data };
  if (updateData.branch_id === 'none') updateData.branch_id = null;
  if (updateData.branch_id && updateData.branch_id !== contextBranchId && !permissions.has('ALL')) {
    throw new ForbiddenError('Salary structure is limited to the active branch');
  }
  delete updateData.id;
  delete updateData.organization_id;

  const updated = await prisma.salaryStructure.update({ where: { id }, data: updateData });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id,
      branch_id: updated.branch_id ?? contextBranchId,
      actor_id: actorId,
      action: 'UPDATE',
      target_type: 'SalaryStructure',
      target_id: updated.id,
      after_state: { name: updated.name },
    },
  });
  return updated;
}

export async function deleteSalaryStructure(
  organization_id: string,
  id: string,
  actorId: string,
  contextBranchId: string,
  permissions: Set<string>,
) {
  const existing = await prisma.salaryStructure.findFirst({ where: { id, organization_id } });
  if (!existing) throw new NotFoundError('Salary structure not found');
  if (existing.branch_id && existing.branch_id !== contextBranchId && !permissions.has('ALL')) {
    throw new NotFoundError('Salary structure not found');
  }
  const deleted = await prisma.salaryStructure.delete({ where: { id } });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id,
      branch_id: existing.branch_id ?? contextBranchId,
      actor_id: actorId,
      action: 'DELETE',
      target_type: 'SalaryStructure',
      target_id: existing.id,
      before_state: { name: existing.name },
    },
  });
  return deleted;
}
