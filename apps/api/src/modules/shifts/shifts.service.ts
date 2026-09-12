/* eslint-disable @typescript-eslint/no-explicit-any */
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

export async function createShift(organization_id: string, data: CreateShiftInput) {
  // Validate branch belongs to organization
  const branch = await prisma.branch.findFirst({
    where: { id: data.branch_id, organization_id },
  });
  if (!branch) throw new NotFoundError('Branch');

  return prisma.shift.create({
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
}

export async function updateShift(organization_id: string, shift_id: string, data: UpdateShiftInput) {
  const shift = await prisma.shift.findUnique({ where: { id: shift_id } });
  if (!shift || shift.organization_id !== organization_id) {
    throw new NotFoundError('Shift');
  }

  return prisma.shift.update({
    where: { id: shift_id },
    data,
  });
}

export async function deleteShift(organization_id: string, shift_id: string) {
  const shift = await prisma.shift.findUnique({ where: { id: shift_id } });
  if (!shift || shift.organization_id !== organization_id) {
    throw new NotFoundError('Shift');
  }

  return prisma.shift.delete({
    where: { id: shift_id },
  });
}




