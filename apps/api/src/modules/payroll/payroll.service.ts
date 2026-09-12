/* eslint-disable @typescript-eslint/no-explicit-any */
import { PrismaClient } from '@prisma/client';

import { NotFoundError } from '../../lib/errors';
const prisma = new PrismaClient();

export async function listSalaryStructures(organization_id: string, branch_id?: string) {
  return await prisma.salaryStructure.findMany({
    where: { organization_id, ...(branch_id ? { branch_id } : {}) },
    orderBy: { created_at: 'desc' }
  });
}

export async function createSalaryStructure(organization_id: string, data: any) {
  return await prisma.salaryStructure.create({
    data: {
      organization_id,
      name: data.name,
      amount: data.amount,
      branch_id: data.branch_id
    }
  });
}

export async function updateSalaryStructure(organization_id: string, id: string, data: any) {
  const existing = await prisma.salaryStructure.findFirst({ where: { id, organization_id } });
  if (!existing) throw new NotFoundError('Salary structure not found');
  return await prisma.salaryStructure.update({ where: { id }, data });
}

export async function deleteSalaryStructure(organization_id: string, id: string) {
  const existing = await prisma.salaryStructure.findFirst({ where: { id, organization_id } });
  if (!existing) throw new NotFoundError('Salary structure not found');
  return await prisma.salaryStructure.delete({ where: { id } });
}

