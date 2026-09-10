import { ulid } from 'ulid';
import type { Prisma } from '@prisma/client';

import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError } from '../../lib/errors';

import type { ClockInInput, ClockOutInput, ListSessionsQuery } from './attendance.schema';

export async function getEffectivePolicy(organization_id: string, branch_id: string) {
  const policy = await prisma.attendancePolicy.findFirst({
    where: { organization_id, branch_id },
    orderBy: { version: 'desc' },
  });

  if (policy) return policy;

  return {
    version: 1,
    punch_required: true,
    selfie_on_clock_in: false,
    location_on_clock_in: false,
    geofence_enabled: false,
    late_grace_minutes: 15,
    max_open_session_hours: 24,
    allow_offline_capture: false,
  };
}

export async function clockIn(actor_id: string, organization_id: string, branch_id: string, data: ClockInInput) {
  const membership = await prisma.member.findFirst({
    where: {
      organization_id,
      branch_id,
      user_id: actor_id,
      status: 'ACTIVE',
    },
  });

  if (!membership) {
    throw new NotFoundError('Membership');
  }

  const existingSession = await prisma.attendanceSession.findFirst({
    where: {
      member_id: membership.id,
      state: 'OPEN',
    },
  });

  if (existingSession) {
    throw new ConflictError('An attendance session is already open');
  }

  const policy = await getEffectivePolicy(organization_id, branch_id);

  const session = await prisma.attendanceSession.create({
    data: {
      id: ulid(),
      organization_id,
      branch_id,
      member_id: membership.id,
      policy_version: policy.version,
      state: 'OPEN',
      source: 'SELF',
      clock_in_at: new Date(),
      clock_in_client_at: data.client_time ? new Date(data.client_time) : new Date(),
      clock_in_timezone: data.timezone,
    },
  });

  return session;
}

export async function clockOut(actor_id: string, organization_id: string, branch_id: string, data: ClockOutInput, permissions: Set<string>) {
  const session = await prisma.attendanceSession.findUnique({
    where: { id: data.session_id },
    include: { member: { include: { user: true } } },
  });

  if (!session || session.organization_id !== organization_id || session.branch_id !== branch_id) {
    throw new NotFoundError('Session');
  }

  // Caller membership check (unless they have ATTENDANCE_CREATE_ALL)
  if (session.member!.user_id !== actor_id) {
    if (!permissions.has('ATTENDANCE_CREATE_ALL') && !permissions.has('ALL')) {
      throw new ConflictError('Session does not belong to the calling user');
    }
  }

  if (session.state !== 'OPEN') {
    throw new ConflictError('Session is not open');
  }

  const now = new Date();
  const worked_minutes = Math.floor((now.getTime() - session.clock_in_at.getTime()) / 60000);
  const derived_status = worked_minutes > 60 ? 'PRESENT' : 'INCOMPLETE';

  const updated = await prisma.attendanceSession.update({
    where: { id: session.id },
    data: {
      state: 'CLOSED',
      clock_out_at: now,
      clock_out_client_at: data.client_time ? new Date(data.client_time) : now,
      clock_out_timezone: data.timezone,
      worked_minutes,
      derived_status: derived_status as any,
      updated_at: now,
    },
  });

  return updated;
}

export async function getActiveSession(actor_id: string, organization_id: string, branch_id: string) {
  const membership = await prisma.member.findFirst({
    where: {
      organization_id,
      branch_id,
      user_id: actor_id,
    },
  });

  if (!membership) return null;

  return prisma.attendanceSession.findFirst({
    where: {
      member_id: membership.id,
      state: 'OPEN',
    },
  });
}

export async function listSessions(actor_id: string, organization_id: string, branch_id: string, query: ListSessionsQuery, permissions: Set<string>) {
  const { period, member_id, status } = query;
  
  const startDate = new Date();
  startDate.setUTCHours(0, 0, 0, 0);

  if (period === 'yesterday') {
    startDate.setUTCDate(startDate.getUTCDate() - 1);
  } else if (period === 'this_week') {
    startDate.setUTCDate(startDate.getUTCDate() - 7);
  } else if (period === 'this_month') {
    startDate.setUTCDate(startDate.getUTCDate() - 30);
  }

  const where: Prisma.AttendanceSessionWhereInput = {
    organization_id,
    branch_id,
    clock_in_at: { gte: startDate },
  };

  if (status) {
    where.derived_status = status as any;
  }

  if (permissions.has('ATTENDANCE_READ_ALL') || permissions.has('ALL')) {
    if (member_id) {
      where.member_id = member_id;
    }
  } else {
    // Only self
    const membership = await prisma.member.findFirst({
      where: {
        organization_id,
        branch_id,
        user_id: actor_id,
      },
    });
    if (!membership) return [];
    where.member_id = membership.id;
  }

  return prisma.attendanceSession.findMany({
    where,
    include: {
      member: {
        include: { user: true },
      },
    },
    orderBy: { clock_in_at: 'desc' },
  });
}
