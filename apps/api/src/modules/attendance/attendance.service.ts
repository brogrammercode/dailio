/* eslint-disable @typescript-eslint/no-explicit-any */
import { ulid } from 'ulid';
import type { Prisma } from '@prisma/client';

import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError } from '../../lib/errors';

import type {
  ClockInInput,
  ClockOutInput,
  ListSessionsQuery,
  UpdatePolicyInput,
  CorrectSessionInput,
} from './attendance.schema';

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

export async function clockIn(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: ClockInInput,
) {
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

export async function clockOut(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: ClockOutInput,
  permissions: Set<string>,
) {
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

export async function getActiveSession(
  actor_id: string,
  organization_id: string,
  branch_id: string,
) {
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

export async function listSessions(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  query: ListSessionsQuery,
  permissions: Set<string>,
) {
  const { period, member_id, status, role_id } = query;

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
    if (role_id) {
      where.member = { role_id };
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

export async function getPolicy(organization_id: string, branch_id: string) {
  return getEffectivePolicy(organization_id, branch_id);
}

export async function updatePolicy(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: UpdatePolicyInput,
) {
  return prisma.$transaction(async (tx) => {
    const txClient = tx as typeof prisma;
    const currentPolicy = await txClient.attendancePolicy.findFirst({
      where: { organization_id, branch_id },
      orderBy: { version: 'desc' },
    });

    const version = currentPolicy ? currentPolicy.version + 1 : 1;

    const newPolicy = await txClient.attendancePolicy.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        version,
        effective_from: new Date(),
        punch_required: data.punch_required ?? currentPolicy?.punch_required ?? true,
        selfie_on_clock_in: data.selfie_on_clock_in ?? currentPolicy?.selfie_on_clock_in ?? false,
        selfie_on_clock_out:
          data.selfie_on_clock_out ?? currentPolicy?.selfie_on_clock_out ?? false,
        location_on_clock_in:
          data.location_on_clock_in ?? currentPolicy?.location_on_clock_in ?? false,
        location_on_clock_out:
          data.location_on_clock_out ?? currentPolicy?.location_on_clock_out ?? false,
        geofence_enabled: data.geofence_enabled ?? currentPolicy?.geofence_enabled ?? false,
        geofence_lat:
          data.geofence_lat !== undefined ? data.geofence_lat : currentPolicy?.geofence_lat,
        geofence_lng:
          data.geofence_lng !== undefined ? data.geofence_lng : currentPolicy?.geofence_lng,
        geofence_radius_meters:
          data.geofence_radius_meters !== undefined
            ? data.geofence_radius_meters
            : currentPolicy?.geofence_radius_meters,
        geofence_accuracy_threshold:
          data.geofence_accuracy_threshold !== undefined
            ? data.geofence_accuracy_threshold
            : currentPolicy?.geofence_accuracy_threshold,
        shift_enforcement_enabled:
          data.shift_enforcement_enabled ?? currentPolicy?.shift_enforcement_enabled ?? false,
        early_arrival_minutes:
          data.early_arrival_minutes ?? currentPolicy?.early_arrival_minutes ?? 30,
        late_grace_minutes: data.late_grace_minutes ?? currentPolicy?.late_grace_minutes ?? 15,
        min_session_minutes: data.min_session_minutes ?? currentPolicy?.min_session_minutes ?? 0,
        max_open_session_hours:
          data.max_open_session_hours ?? currentPolicy?.max_open_session_hours ?? 24,
        allow_manual_entry: data.allow_manual_entry ?? currentPolicy?.allow_manual_entry ?? false,
        allow_offline_capture:
          data.allow_offline_capture ?? currentPolicy?.allow_offline_capture ?? false,
      },
    });

    await txClient.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'AttendancePolicy',
        target_id: newPolicy.id,
      },
    });

    return newPolicy;
  });
}

export async function correctSession(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  session_id: string,
  data: CorrectSessionInput,
) {
  return prisma.$transaction(async (tx) => {
    const txClient = tx as typeof prisma;

    const session = await txClient.attendanceSession.findUnique({
      where: { id: session_id },
    });

    if (
      !session ||
      session.organization_id !== organization_id ||
      session.branch_id !== branch_id
    ) {
      throw new NotFoundError('Attendance session not found');
    }

    const updatedSession = await txClient.attendanceSession.update({
      where: { id: session_id },
      data: {
        clock_in_at: data.clock_in_at ? new Date(data.clock_in_at) : undefined,
        clock_out_at: data.clock_out_at ? new Date(data.clock_out_at) : undefined,
        derived_status: data.derived_status ?? undefined,
        state: 'CORRECTED',
        corrected_at: new Date(),
        corrected_by: actor_id,
        correction_reason: data.correction_reason,
      },
    });

    await txClient.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'CORRECT',
        target_type: 'AttendanceSession',
        target_id: session.id,
        reason: data.correction_reason,
        before_state: {
          clock_in: session.clock_in_at,
          clock_out: session.clock_out_at,
          status: session.derived_status,
        },
        after_state: {
          clock_in: updatedSession.clock_in_at,
          clock_out: updatedSession.clock_out_at,
          status: updatedSession.derived_status,
        },
      },
    });

    return updatedSession;
  });
}
