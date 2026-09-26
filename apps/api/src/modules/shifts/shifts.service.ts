/* eslint-disable @typescript-eslint/no-explicit-any */
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';

import { CreateShiftInput, UpdateShiftInput } from './shifts.schema';

export async function listShifts(organization_id: string, branch_id?: string) {
  const where: any = { organization_id };
  if (branch_id && branch_id !== 'none') {
    where.branch_id = branch_id;
  }
  const shifts = await prisma.shift.findMany({
    where,
    orderBy: { created_at: 'desc' },
  });

  if (branch_id === 'none') return [];
  return shifts;
}

export async function createShift(
  organization_id: string,
  data: CreateShiftInput,
  actor_id: string,
) {
  // Validate branch belongs to organization
  const branch = await prisma.branch.findFirst({
    where: { id: data.branch_id, organization_id },
  });
  if (!branch) throw new NotFoundError('Branch');

  return prisma.$transaction(async (tx) => {
    const shift = await tx.shift.create({
      data: {
        organization_id,
        branch_id: data.branch_id,
        name: data.name,
        start_time: data.start_time,
        end_time: data.end_time,
        is_overnight: data.is_overnight,
        break_minutes: data.break_minutes,
        grace_in_min: data.grace_in_min,
        grace_out_min: data.grace_out_min,
        week_days: data.week_days,
        active_from: new Date(),
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id: data.branch_id,
        actor_id,
        action: 'CREATE',
        target_type: 'Shift',
        target_id: shift.id,
        after_state: { name: shift.name, branch_id: shift.branch_id },
      },
    });
    return shift;
  });
}

export async function updateShift(
  organization_id: string,
  branch_id: string,
  shift_id: string,
  data: UpdateShiftInput,
  actor_id: string,
  permissions: Set<string>,
) {
  const shift = await prisma.shift.findUnique({ where: { id: shift_id } });
  if (
    !shift ||
    shift.organization_id !== organization_id ||
    (shift.branch_id !== branch_id && !permissions.has('ALL'))
  ) {
    throw new NotFoundError('Shift');
  }

  return prisma.$transaction(async (tx) => {
    const updated = await tx.shift.update({
      where: { id: shift_id },
      data,
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id: updated.branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'Shift',
        target_id: updated.id,
        after_state: data,
      },
    });
    return updated;
  });
}

export async function deleteShift(
  organization_id: string,
  branch_id: string,
  shift_id: string,
  actor_id: string,
  permissions: Set<string>,
) {
  const shift = await prisma.shift.findUnique({ where: { id: shift_id } });
  if (
    !shift ||
    shift.organization_id !== organization_id ||
    (shift.branch_id !== branch_id && !permissions.has('ALL'))
  ) {
    throw new NotFoundError('Shift');
  }

  return prisma.$transaction(async (tx) => {
    const deleted = await tx.shift.delete({
      where: { id: shift_id },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id: deleted.branch_id,
        actor_id,
        action: 'DELETE',
        target_type: 'Shift',
        target_id: deleted.id,
        before_state: { name: deleted.name, branch_id: deleted.branch_id },
      },
    });
    return deleted;
  });
}
