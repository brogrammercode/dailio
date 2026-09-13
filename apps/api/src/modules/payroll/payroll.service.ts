/* eslint-disable @typescript-eslint/no-explicit-any */
import { PrismaClient } from '@prisma/client';
import { NotFoundError } from '../../lib/errors';
const prisma = new PrismaClient();

export async function listSalaryStructures(organization_id: string, branch_id?: string) {
  const structures = await prisma.salaryStructure.findMany({
    where: { 
      organization_id, 
      ...(branch_id === 'none' ? { branch_id: null } : branch_id ? { branch_id } : {}) 
    } as any,
    include: {
      _count: {
        select: { members: true }
      },
      members: {
        take: 3,
        select: {
          user: {
            select: {
              avatar_url: true
            }
          }
        }
      }
    },
    orderBy: { created_at: 'desc' }
  });
  
  return structures.map(s => {
    const avatarUrls = s.members.map(m => m.user.avatar_url).filter(url => url != null);
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
      avatars: avatarUrls
    };
  });
}

export async function createSalaryStructure(organization_id: string, data: any) {
  return await prisma.salaryStructure.create({
    data: {
      organization_id,
      name: data.name,
      amount: data.amount ?? 0,
      branch_id: data.branch_id === 'none' ? null : data.branch_id,
      earnings: data.earnings ?? [],
      deductions: data.deductions ?? [],
    }
  });
}

export async function updateSalaryStructure(organization_id: string, id: string, data: any) {
  const existing = await prisma.salaryStructure.findFirst({ where: { id, organization_id } });
  if (!existing) throw new NotFoundError('Salary structure not found');
  
  const updateData: any = { ...data };
  if (updateData.branch_id === 'none') updateData.branch_id = null;
  delete updateData.id;
  delete updateData.organization_id;

  return await prisma.salaryStructure.update({ where: { id }, data: updateData });
}

export async function deleteSalaryStructure(organization_id: string, id: string) {
  const existing = await prisma.salaryStructure.findFirst({ where: { id, organization_id } });
  if (!existing) throw new NotFoundError('Salary structure not found');
  return await prisma.salaryStructure.delete({ where: { id } });
}
