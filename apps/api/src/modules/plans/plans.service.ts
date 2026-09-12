import { prisma } from '../../lib/prisma';
import { AppError } from '../../lib/errors';

export async function getOrganizationPlans(organizationId: string) {
  return await prisma.plan.findMany({
    where: { organization_id: organizationId },
    orderBy: { created_at: 'asc' },
  });
}

export async function createPlan(organizationId: string, data: any) {
  return await prisma.plan.create({
    data: {
      ...data,
      organization_id: organizationId,
    },
  });
}

export async function updatePlan(organizationId: string, planId: string, data: any) {
  const existing = await prisma.plan.findFirst({
    where: { id: planId, organization_id: organizationId },
  });
  if (!existing) {
    throw new AppError(404, 'NOT_FOUND', 'Plan not found');
  }

  return await prisma.plan.update({
    where: { id: planId },
    data,
  });
}


