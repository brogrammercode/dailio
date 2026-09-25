/* eslint-disable @typescript-eslint/no-explicit-any */
import { prisma } from '../../lib/prisma';
import { ulid } from 'ulid';
import type { Prisma } from '@prisma/client';
import { AppError, ForbiddenError, NotFoundError } from '../../lib/errors';
import type { CreatePlanInput, UpdatePlanInput } from './plans.schema';

async function assertBranchAccess(
  organizationId: string,
  contextBranchId: string,
  requestedBranchId: string | null | undefined,
  permissions: Set<string>,
) {
  const branchId = requestedBranchId === 'none' ? 'none' : (requestedBranchId ?? contextBranchId);
  if (branchId && branchId !== contextBranchId && !permissions.has('ALL')) {
    throw new ForbiddenError('Plan access is limited to the active branch');
  }
  if (branchId && branchId !== 'none') {
    const branch = await prisma.branch.findFirst({
      where: { id: branchId, organization_id: organizationId },
    });
    if (!branch) throw new NotFoundError('Branch');
  }
  return branchId;
}

export async function getOrganizationPlans(
  organizationId: string,
  contextBranchId: string,
  requestedBranchId: string | undefined,
  permissions: Set<string>,
) {
  const branchId = await assertBranchAccess(
    organizationId,
    contextBranchId,
    requestedBranchId,
    permissions,
  );
  return await prisma.plan.findMany({
    where: {
      organization_id: organizationId,
      ...(branchId === 'none'
        ? { branch_id: null }
        : branchId
          ? { OR: [{ branch_id: branchId }, { branch_id: null }] }
          : {}),
    },
    orderBy: { created_at: 'asc' },
  });
}

export async function createPlan(
  organizationId: string,
  contextBranchId: string,
  permissions: Set<string>,
  data: CreatePlanInput,
  actorId: string,
) {
  const branchId = await assertBranchAccess(
    organizationId,
    contextBranchId,
    data.branch_id,
    permissions,
  );
  const plan = await prisma.plan.create({
    data: {
      ...data,
      branch_id: branchId === 'none' ? null : branchId,
      organization_id: organizationId,
      metadata: data.metadata as Prisma.InputJsonValue | undefined,
    },
  });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id: organizationId,
      branch_id: branchId === 'none' ? contextBranchId : branchId,
      actor_id: actorId,
      action: 'CREATE',
      target_type: 'Plan',
      target_id: plan.id,
      after_state: {
        name: plan.name,
        amount_minor_unit: plan.amount_minor_unit,
        is_active: plan.is_active,
      },
    },
  });
  return plan;
}

export async function updatePlan(
  organizationId: string,
  contextBranchId: string,
  permissions: Set<string>,
  planId: string,
  data: UpdatePlanInput,
  actorId: string,
) {
  const existing = await prisma.plan.findFirst({
    where: { id: planId, organization_id: organizationId },
  });
  if (!existing) throw new AppError(404, 'NOT_FOUND', 'Plan not found');
  await assertBranchAccess(organizationId, contextBranchId, existing.branch_id, permissions);
  if (data.branch_id !== undefined) {
    await assertBranchAccess(organizationId, contextBranchId, data.branch_id, permissions);
  }

  const updateData: Prisma.PlanUncheckedUpdateInput = {
    ...data,
    branch_id: data.branch_id === undefined ? undefined : data.branch_id,
    metadata: data.metadata as Prisma.InputJsonValue | undefined,
  };
  const plan = await prisma.plan.update({
    where: { id: planId },
    data: updateData,
  });
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id: organizationId,
      branch_id: plan.branch_id ?? contextBranchId,
      actor_id: actorId,
      action: 'UPDATE',
      target_type: 'Plan',
      target_id: plan.id,
      after_state: {
        name: plan.name,
        amount_minor_unit: plan.amount_minor_unit,
        is_active: plan.is_active,
      },
    },
  });
  return plan;
}
