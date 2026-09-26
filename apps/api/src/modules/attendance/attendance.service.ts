/* eslint-disable @typescript-eslint/no-explicit-any */
import { createHmac, timingSafeEqual } from 'node:crypto';

import { ulid } from 'ulid';
import { Prisma } from '@prisma/client';

import { prisma } from '../../lib/prisma';
import { env } from '../../config/env';
import {
  AppError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
  UnprocessableError,
} from '../../lib/errors';
import { getUploadSignature } from '../../lib/cloudinary';
import { cloudinary } from '../../lib/cloudinary';
import { getFirebaseMessaging } from '../../lib/firebase';

import type {
  ClockInInput,
  ClockOutInput,
  CreateManualSessionInput,
  ListSessionsQuery,
  UpdatePolicyInput,
  CorrectSessionInput,
} from './attendance.schema';

const fallbackPolicy = {
  version: 1,
  id: null,
  organization_id: null,
  branch_id: null,
  role_id: null,
  member_id: null,
  source_scope: 'BRANCH_DEFAULT',
  effective_from: null,
  punch_required: true,
  selfie_on_clock_in: false,
  location_on_clock_in: false,
  selfie_on_clock_out: false,
  location_on_clock_out: false,
  geofence_enabled: false,
  geofence_lat: null,
  geofence_lng: null,
  geofence_radius_meters: null,
  geofence_accuracy_threshold: null,
  shift_enforcement_enabled: false,
  early_arrival_minutes: 30,
  late_grace_minutes: 15,
  min_session_minutes: 0,
  max_open_session_hours: 24,
  allow_manual_entry: false,
  allow_offline_capture: false,
} as const;

// Neon/serverless PostgreSQL can spend longer acquiring a connection than
// Prisma's five-second interactive-transaction default. Attendance commands
// remain bounded, but allow enough time for a cold pool without letting a
// transaction hang indefinitely.
const attendanceTransactionOptions = {
  maxWait: 10_000,
  timeout: 15_000,
} as const;

async function notifyAttendance(
  userId: string,
  organizationId: string,
  title: string,
  body: string,
  data: Record<string, string>,
  dedupeKey: string,
) {
  try {
    const existing = await prisma.notification.findUnique({ where: { dedupe_key: dedupeKey } });
    if (existing) return;
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { fcm_token: true },
    });
    await prisma.notification.create({
      data: {
        id: ulid(),
        user_id: userId,
        organization_id: organizationId,
        title,
        body,
        channel: 'IN_APP',
        status: 'SENT',
        sent_at: new Date(),
        dedupe_key: dedupeKey,
        data,
      },
    });
    const messaging = getFirebaseMessaging();
    if (messaging && user?.fcm_token) {
      await messaging.send({ token: user.fcm_token, notification: { title, body }, data });
    }
  } catch {
    // Notifications are auxiliary; never fail an attendance command or scheduler pass.
  }
}

export function getAttendanceFailureMessage(error: unknown) {
  return error instanceof AppError
    ? error.message
    : 'Attendance could not be validated. Please try again.';
}

async function notifyAttendanceFailure(
  userId: string,
  organizationId: string,
  action: 'clock_in' | 'clock_out',
  idempotencyKey: string,
  error: unknown,
) {
  const message = getAttendanceFailureMessage(error);
  await notifyAttendance(
    userId,
    organizationId,
    'Attendance action needs attention',
    `${action === 'clock_in' ? 'Clock-in' : 'Clock-out'} was not completed: ${message}`,
    { type: 'ATTENDANCE_ACTION_FAILED', action },
    `attendance-failure:${idempotencyKey}`,
  );
}

type PunchEvidenceInput = {
  latitude?: number;
  longitude?: number;
  accuracy?: number;
  selfie_storage_key?: string;
  selfie_upload_token?: string;
  selfie_content_type?: string;
  selfie_size_bytes?: number;
};

function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number) {
  const earthRadius = 6_371_000;
  const toRadians = (value: number) => (value * Math.PI) / 180;
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLng / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function validatePunchEvidence(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  policy: any,
  data: PunchEvidenceInput,
  action: 'clock_in' | 'clock_out',
) {
  const branch = await prisma.branch.findFirst({
    where: { id: branch_id, organization_id },
    select: { latitude: true, longitude: true },
  });
  let geofenceDistanceMeters: number | null = null;
  const locationRequired = policy[`location_on_${action}`];
  if (
    locationRequired &&
    (data.latitude == null || data.longitude == null || data.accuracy == null)
  ) {
    throw new UnprocessableError('Location evidence is required for this attendance action', {
      reason: 'LOCATION_REQUIRED',
      action,
      requirements: { latitude: true, longitude: true, accuracy: true },
    });
  }
  if (policy.geofence_enabled) {
    const centerLat = policy.geofence_lat ?? branch?.latitude;
    const centerLng = policy.geofence_lng ?? branch?.longitude;
    if (centerLat == null || centerLng == null || data.latitude == null || data.longitude == null) {
      throw new UnprocessableError('Geofence location is not configured or was not captured', {
        reason: 'GEOFENCE_LOCATION_UNAVAILABLE',
        action,
      });
    }
    if (
      policy.geofence_accuracy_threshold != null &&
      (data.accuracy == null || data.accuracy > policy.geofence_accuracy_threshold)
    ) {
      throw new UnprocessableError('Location accuracy is outside the attendance policy', {
        reason: 'LOCATION_ACCURACY_TOO_LOW',
        action,
        accuracy: data.accuracy,
        maximum_accuracy: policy.geofence_accuracy_threshold,
      });
    }
    geofenceDistanceMeters = distanceMeters(centerLat, centerLng, data.latitude, data.longitude);
    if (
      policy.geofence_radius_meters != null &&
      geofenceDistanceMeters > policy.geofence_radius_meters
    ) {
      throw new UnprocessableError('You are outside the branch attendance geofence', {
        reason: 'OUTSIDE_GEOFENCE',
        action,
        radius_meters: policy.geofence_radius_meters,
      });
    }
  }
  const expectedSelfiePrefix = `organizations/${organization_id}/branches/${branch_id}/attendance-selfies/`;
  if (data.selfie_storage_key && !data.selfie_storage_key.startsWith(expectedSelfiePrefix)) {
    throw new UnprocessableError('Attendance selfie storage key is invalid', {
      reason: 'SELFIE_STORAGE_KEY_INVALID',
      action,
    });
  }
  if (data.selfie_storage_key) {
    if (
      !data.selfie_upload_token ||
      !verifyAttendanceSelfieUploadToken(
        data.selfie_upload_token,
        actor_id,
        organization_id,
        branch_id,
        data.selfie_storage_key,
      )
    ) {
      throw new UnprocessableError('Attendance selfie upload is not authorized for this action', {
        reason: 'SELFIE_UPLOAD_UNAUTHORIZED',
        action,
      });
    }
  }
  if (policy[`selfie_on_${action}`] && !data.selfie_storage_key) {
    throw new UnprocessableError('A live selfie is required for this attendance action', {
      reason: 'SELFIE_REQUIRED',
      action,
    });
  }
  return { geofence_distance_meters: geofenceDistanceMeters };
}

function localMinutes(value: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: timezone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(value);
  const hour = Number(parts.find((part) => part.type === 'hour')?.value ?? 0);
  const minute = Number(parts.find((part) => part.type === 'minute')?.value ?? 0);
  return hour * 60 + minute;
}

function localDate(value: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const get = (type: string) => parts.find((part) => part.type === type)?.value ?? '01';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function subtractLocalDays(date: string, days: number) {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() - days);
  return value.toISOString().slice(0, 10);
}

function addLocalDays(date: string, days: number) {
  return subtractLocalDays(date, -days);
}

function localMidnightUtc(date: string, timezone: string) {
  const target = Date.parse(`${date}T00:00:00.000Z`);
  let candidate = target;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date(candidate));
    const get = (type: string) => parts.find((part) => part.type === type)?.value ?? '00';
    const displayed = Date.UTC(
      Number(get('year')),
      Number(get('month')) - 1,
      Number(get('day')),
      Number(get('hour')),
      Number(get('minute')),
      Number(get('second')),
    );
    candidate -= displayed - target;
  }
  return new Date(candidate);
}

function localDateTimeUtc(date: string, minutes: number, timezone: string) {
  const dayOffset = Math.floor(minutes / 1_440);
  const minuteOfDay = minutes - dayOffset * 1_440;
  const normalizedDate = addLocalDays(date, dayOffset);
  const [year, month, day] = normalizedDate.split('-').map(Number);
  const target = Date.UTC(year, month - 1, day, 0, minuteOfDay, 0);
  let candidate = target;
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date(candidate));
    const get = (type: string) => parts.find((part) => part.type === type)?.value ?? '00';
    const displayed = Date.UTC(
      Number(get('year')),
      Number(get('month')) - 1,
      Number(get('day')),
      Number(get('hour')),
      Number(get('minute')),
      Number(get('second')),
    );
    candidate -= displayed - target;
  }
  return new Date(candidate);
}

function shiftTimeMinutes(value: unknown) {
  if (typeof value !== 'string' || !/^\d{2}:\d{2}$/.test(value)) return null;
  const [hour, minute] = value.split(':').map(Number);
  return hour * 60 + minute;
}

function localWeekday(value: Date, timezone: string) {
  const weekday = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    weekday: 'short',
  }).format(value);
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(weekday) || 0;
}

export function validateShiftWindow(
  shiftSnapshot: any,
  policy: any,
  value: Date,
  timezone: string,
  action: 'clock_in' | 'clock_out',
) {
  if (!policy.shift_enforcement_enabled) return;
  if (!shiftSnapshot) {
    throw new UnprocessableError('A scheduled shift is required for this attendance action', {
      reason: 'SHIFT_NOT_ASSIGNED',
      action,
    });
  }

  // A clock-out belongs to the already-open session. For an overnight shift,
  // its local calendar day can be the day after the configured shift day.
  // The open-session invariant and the snapshotted shift are authoritative;
  // do not reject a valid overnight clock-out on that next day.
  if (action === 'clock_out') return;

  const weekDays = Array.isArray(shiftSnapshot.week_days) ? shiftSnapshot.week_days : [];
  const weekday = localWeekday(value, timezone);
  const normalizedWeekday = weekday === 0 ? 7 : weekday;
  const start = shiftTimeMinutes(shiftSnapshot.start_time);
  const end = shiftTimeMinutes(shiftSnapshot.end_time);
  if (start == null || end == null) {
    if (weekDays.length > 0 && !weekDays.includes(normalizedWeekday)) {
      throw new UnprocessableError('This attendance action is outside the scheduled work days', {
        reason: 'SHIFT_DAY_NOT_SCHEDULED',
        action,
        weekday: normalizedWeekday,
      });
    }
    return;
  }

  const current = localMinutes(value, timezone);
  const earliest = start - (policy.early_arrival_minutes ?? 0);
  const isOvernight = Boolean(shiftSnapshot.is_overnight) && start > end;

  if (!isOvernight) {
    if (weekDays.length > 0 && !weekDays.includes(normalizedWeekday)) {
      throw new UnprocessableError('This attendance action is outside the scheduled work days', {
        reason: 'SHIFT_DAY_NOT_SCHEDULED',
        action,
        weekday: normalizedWeekday,
      });
    }
    if (current < earliest) {
      throw new UnprocessableError('Clock-in is before the allowed shift window', {
        reason: 'BEFORE_SHIFT_WINDOW',
        action,
        early_arrival_minutes: policy.early_arrival_minutes ?? 0,
      });
    }
    return;
  }

  const previousWeekday = normalizedWeekday === 1 ? 7 : normalizedWeekday - 1;
  const currentDayScheduled = weekDays.length === 0 || weekDays.includes(normalizedWeekday);
  const previousDayScheduled = weekDays.length === 0 || weekDays.includes(previousWeekday);
  const isAfterMidnightForPreviousShift = previousDayScheduled && current <= end;
  const isWithinCurrentShiftStartWindow = currentDayScheduled && current >= earliest;

  if (!isAfterMidnightForPreviousShift && !isWithinCurrentShiftStartWindow) {
    if (!currentDayScheduled && !previousDayScheduled) {
      throw new UnprocessableError('This attendance action is outside the scheduled work days', {
        reason: 'SHIFT_DAY_NOT_SCHEDULED',
        action,
        weekday: normalizedWeekday,
      });
    }
    throw new UnprocessableError('Clock-in is before the allowed shift window', {
      reason: 'BEFORE_SHIFT_WINDOW',
      action,
      early_arrival_minutes: policy.early_arrival_minutes ?? 0,
    });
  }
}

export function calculateAttendanceVariance(
  shiftSnapshot: any,
  policy: any,
  value: Date,
  timezone: string,
  clockInAt?: Date,
) {
  if (!policy.shift_enforcement_enabled || !shiftSnapshot) {
    return { lateMinutes: 0, earlyLeaveMinutes: 0 };
  }
  const start = shiftTimeMinutes(shiftSnapshot.start_time);
  const end = shiftTimeMinutes(shiftSnapshot.end_time);
  if (start == null || end == null) return { lateMinutes: 0, earlyLeaveMinutes: 0 };
  const current = localMinutes(value, timezone);
  const lateReference = clockInAt ?? value;
  const lateReferenceMinutes = localMinutes(lateReference, timezone);
  const isOvernight = Boolean(shiftSnapshot.is_overnight) && start > end;
  const elapsedFromShiftStart =
    isOvernight && lateReferenceMinutes <= end
      ? lateReferenceMinutes + 1_440 - start
      : lateReferenceMinutes - start;
  const lateMinutes = Math.max(0, elapsedFromShiftStart - (policy.late_grace_minutes ?? 0));
  let earlyLeaveMinutes = 0;
  if (!isOvernight && current < end) {
    earlyLeaveMinutes = Math.max(0, end - current);
  } else if (isOvernight && clockInAt && value.getTime() > clockInAt.getTime()) {
    const clockInDate = localDate(clockInAt, timezone);
    const clockInMinutes = localMinutes(clockInAt, timezone);
    const shiftStartDate = clockInMinutes <= end ? subtractLocalDays(clockInDate, 1) : clockInDate;
    const expectedEnd = localDateTimeUtc(shiftStartDate, end + 1_440, timezone);
    if (value < expectedEnd) {
      earlyLeaveMinutes = Math.max(
        0,
        Math.floor((expectedEnd.getTime() - value.getTime()) / 60_000),
      );
    }
  }
  return { lateMinutes, earlyLeaveMinutes };
}

export function deriveAttendanceStatus(
  previousStatus: string | null | undefined,
  workedMinutes: number,
  policy: any,
  variance: { lateMinutes: number; earlyLeaveMinutes: number },
) {
  const exceedsMaximumOpenDuration =
    (policy.max_open_session_hours ?? 24) > 0 &&
    workedMinutes > (policy.max_open_session_hours ?? 24) * 60;
  if (exceedsMaximumOpenDuration) return 'INCOMPLETE';
  if (workedMinutes < (policy.min_session_minutes ?? 0)) return 'INCOMPLETE';
  if (previousStatus === 'LATE' || variance.lateMinutes > 0) return 'LATE';
  if (variance.earlyLeaveMinutes > 0) return 'LEFT_EARLY';
  return 'PRESENT';
}

function sanitizeEvidence<T>(evidence: T) {
  const privateFields = new Set(['latitude', 'longitude', 'device_metadata', 'ip_address']);
  return Object.fromEntries(
    Object.entries(evidence as Record<string, unknown>).filter(([key]) => !privateFields.has(key)),
  );
}

function buildAttendanceTimeline(session: any, corrections: any[] = []) {
  const events = [
    {
      type: 'CLOCK_IN_CONFIRMED',
      at: session.clock_in_at,
      source: session.source,
      status: 'CONFIRMED',
    },
    ...(session.evidence ?? []).map((evidence: any) => ({
      type: evidence.type,
      at: evidence.created_at,
      status: 'ACCEPTED',
      evidence_id: evidence.id,
      accuracy: evidence.accuracy,
    })),
    ...(session.clock_out_at
      ? [
          {
            type: 'CLOCK_OUT_CONFIRMED',
            at: session.clock_out_at,
            source: session.clock_out_source ?? session.source,
            status: 'CONFIRMED',
          },
        ]
      : []),
    ...corrections.map((correction: any) => ({
      type: 'CORRECTION_APPLIED',
      at: correction.created_at,
      status: 'CONFIRMED',
      correction_id: correction.id,
      version: correction.version,
      reason: correction.reason,
    })),
  ];
  return events.sort((a, b) => new Date(a.at).getTime() - new Date(b.at).getTime());
}

export async function getEffectivePolicy(
  organization_id: string,
  branch_id: string,
  member_id?: string,
) {
  if (member_id) return getEffectivePolicyForMember(organization_id, branch_id, member_id);

  const policy = await prisma.attendancePolicy.findFirst({
    where: {
      organization_id,
      branch_id,
      role_id: null,
      member_id: null,
      effective_from: { lte: new Date() },
      OR: [{ effective_to: null }, { effective_to: { gt: new Date() } }],
    },
    orderBy: [{ effective_from: 'desc' }, { version: 'desc' }],
  });
  return policy ? { ...policy, source_scope: 'BRANCH_DEFAULT' as const } : fallbackPolicy;
}

const ATTENDANCE_SELFIE_UPLOAD_TTL_SECONDS = 10 * 60;

function attendanceSelfieUploadToken(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  storage_key: string,
  expires_at: number,
) {
  const payload = Buffer.from(
    JSON.stringify({ actor_id, organization_id, branch_id, storage_key, expires_at }),
  ).toString('base64url');
  const signature = createHmac('sha256', env.JWT_ACCESS_SECRET).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}

function verifyAttendanceSelfieUploadToken(
  token: string,
  actor_id: string,
  organization_id: string,
  branch_id: string,
  storage_key: string,
) {
  try {
    const separator = token.lastIndexOf('.');
    if (separator <= 0 || separator === token.length - 1) return false;
    const payload = token.slice(0, separator);
    const receivedSignature = Buffer.from(token.slice(separator + 1), 'base64url');
    const expectedSignature = createHmac('sha256', env.JWT_ACCESS_SECRET).update(payload).digest();
    if (
      receivedSignature.length !== expectedSignature.length ||
      !timingSafeEqual(receivedSignature, expectedSignature)
    ) {
      return false;
    }
    const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as {
      actor_id?: string;
      organization_id?: string;
      branch_id?: string;
      storage_key?: string;
      expires_at?: number;
    };
    return (
      parsed.actor_id === actor_id &&
      parsed.organization_id === organization_id &&
      parsed.branch_id === branch_id &&
      parsed.storage_key === storage_key &&
      typeof parsed.expires_at === 'number' &&
      parsed.expires_at >= Math.floor(Date.now() / 1000)
    );
  } catch {
    return false;
  }
}

export function createAttendanceSelfieUploadSignature(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  filename: string,
) {
  const safeName = filename.replace(/[^a-zA-Z0-9_-]/g, '-').slice(0, 80) || 'selfie';
  const folder = `organizations/${organization_id}/branches/${branch_id}/attendance-selfies`;
  const publicId = `${safeName}-${ulid()}`;
  const storageKey = `${folder}/${publicId}`;
  const expiresAt = Math.floor(Date.now() / 1000) + ATTENDANCE_SELFIE_UPLOAD_TTL_SECONDS;
  return {
    ...getUploadSignature(folder, publicId, 'authenticated'),
    storage_key: storageKey,
    upload_token: attendanceSelfieUploadToken(
      actor_id,
      organization_id,
      branch_id,
      storageKey,
      expiresAt,
    ),
    upload_token_expires_at: new Date(expiresAt * 1000).toISOString(),
  };
}

/**
 * Purge sensitive attendance evidence without deleting the attendance record.
 * This is intentionally batched so it is safe to run from each API instance.
 */
export async function purgeExpiredAttendanceEvidence(batchSize = 100) {
  const cutoff = new Date(
    Date.now() - env.ATTENDANCE_EVIDENCE_RETENTION_DAYS * 24 * 60 * 60 * 1000,
  );
  const evidence = await prisma.attendanceEvidence.findMany({
    where: {
      created_at: { lt: cutoff },
      OR: [
        { latitude: { not: null } },
        { longitude: { not: null } },
        { device_metadata: { not: Prisma.DbNull } },
        { asset_id: { not: null } },
      ],
    },
    take: batchSize,
    select: {
      id: true,
      asset_id: true,
      asset: { select: { id: true, storage_key: true } },
    },
  });

  let purged = 0;
  for (const item of evidence) {
    if (item.asset) {
      try {
        await cloudinary.uploader.destroy(item.asset.storage_key, {
          resource_type: 'image',
          type: 'authenticated',
          invalidate: true,
        });
      } catch {
        // Keep the asset reference so a later retention pass can retry deletion.
        continue;
      }
    }
    await prisma.$transaction(async (tx) => {
      await tx.attendanceEvidence.update({
        where: { id: item.id },
        data: {
          latitude: null,
          longitude: null,
          device_metadata: Prisma.DbNull,
          ip_address: null,
          asset_id: null,
        },
      });
      if (item.asset_id) {
        // Multiple API instances can observe the same batch before either
        // transaction commits. deleteMany makes the cleanup idempotent when
        // another worker has already removed the asset row.
        await tx.mediaAsset.deleteMany({
          where: { id: item.asset_id },
        });
      }
    });
    purged += 1;
  }
  return { purged, scanned: evidence.length, cutoff };
}

/**
 * Notify members whose open sessions exceeded the policy maximum. The session
 * remains open until an authorized clock-out/correction; this job only makes
 * the operational risk visible and is safe across multiple API instances.
 */
export async function reviewOpenAttendanceSessions(batchSize = 500) {
  const sessions = await prisma.attendanceSession.findMany({
    where: { state: 'OPEN' },
    take: batchSize,
    select: {
      id: true,
      organization_id: true,
      member_id: true,
      clock_in_at: true,
      policy_snapshot: true,
      member: { select: { user_id: true } },
    },
  });

  const now = Date.now();
  let notified = 0;
  for (const session of sessions) {
    if (!session.member) continue;
    const policy = (session.policy_snapshot as Record<string, unknown> | null) ?? {};
    const maxHours = Number(policy.max_open_session_hours ?? 24);
    if (maxHours <= 0) continue;
    const elapsedHours = (now - session.clock_in_at.getTime()) / (60 * 60 * 1000);
    if (elapsedHours <= maxHours) continue;

    await notifyAttendance(
      session.member.user_id,
      session.organization_id,
      'Clock-out reminder',
      'Your attendance session is still open beyond the configured maximum. Please clock out or contact an administrator.',
      { type: 'ATTENDANCE_MISSING_CLOCK_OUT', session_id: session.id },
      `attendance-missing-clock-out:${session.id}:${new Date().toISOString().slice(0, 10)}`,
    );
    notified += 1;
  }
  return { scanned: sessions.length, notified };
}

export async function getEffectivePolicyForMember(
  organization_id: string,
  branch_id: string,
  member_id: string,
) {
  const now = new Date();
  const member = await prisma.member.findFirst({
    where: { id: member_id, organization_id, branch_id },
    select: {
      id: true,
      role_id: true,
      role_assignments: {
        where: {
          organization_id,
          branch_id,
          effective_from: { lte: now },
          OR: [{ effective_to: null }, { effective_to: { gt: now } }],
        },
        orderBy: [{ priority: 'asc' }, { effective_from: 'desc' }, { id: 'asc' }],
        select: { role_id: true },
      },
    },
  });
  if (!member) return fallbackPolicy;

  const assignments = member.role_assignments ?? [];
  const roleIds =
    assignments.length > 0
      ? assignments.map((assignment) => assignment.role_id)
      : member.role_id
        ? [member.role_id]
        : [];

  const policies = await prisma.attendancePolicy.findMany({
    where: {
      organization_id,
      branch_id,
      effective_from: { lte: now },
      AND: [
        { OR: [{ effective_to: null }, { effective_to: { gt: now } }] },
        {
          OR: [
            { member_id: member.id },
            ...roleIds.map((roleId) => ({ role_id: roleId, member_id: null })),
            { role_id: null, member_id: null },
          ],
        },
      ],
    },
    orderBy: [{ effective_from: 'desc' }, { version: 'desc' }],
  });

  const selected =
    policies.find((item) => item.member_id === member.id) ??
    roleIds
      .map((roleId) => policies.find((item) => item.role_id === roleId && item.member_id == null))
      .find((item) => item != null) ??
    policies.find((item) => item.role_id == null && item.member_id == null);

  if (!selected) return fallbackPolicy;
  return {
    ...selected,
    source_scope: selected.member_id ? 'MEMBER' : selected.role_id ? 'ROLE' : 'BRANCH_DEFAULT',
    resolved_role_id: selected.role_id,
  } as const;
}

async function getAttendanceScopeMemberIds(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  permissions: Set<string>,
) {
  if (
    permissions.has('ALL') ||
    permissions.has('ATTENDANCE_READ_ALL') ||
    permissions.has('ATTENDANCE_READ_BRANCH')
  ) {
    return null;
  }

  const actor = await prisma.member.findFirst({
    where: { organization_id, branch_id, user_id: actor_id, status: 'ACTIVE' },
    select: { id: true },
  });
  if (!actor) return [];
  if (!permissions.has('ATTENDANCE_READ_TEAM')) return [actor.id];

  const members = await prisma.member.findMany({
    where: { organization_id, branch_id, status: 'ACTIVE' },
    select: { id: true, manager_member_id: true },
  });
  const children = new Map<string, string[]>();
  for (const member of members) {
    if (!member.manager_member_id) continue;
    const list = children.get(member.manager_member_id) ?? [];
    list.push(member.id);
    children.set(member.manager_member_id, list);
  }
  const ids = new Set<string>([actor.id]);
  const queue = [actor.id];
  while (queue.length > 0) {
    const parent = queue.shift()!;
    for (const child of children.get(parent) ?? []) {
      if (ids.has(child)) continue;
      ids.add(child);
      queue.push(child);
    }
  }
  return [...ids];
}

export async function clockIn(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: ClockInInput,
  source: 'SELF' | 'QR_GATE' = 'SELF',
) {
  const membership = await prisma.member.findFirst({
    where: {
      organization_id,
      branch_id,
      user_id: actor_id,
      status: 'ACTIVE',
      branch: { status: 'ACTIVE' },
    },
    include: { branch: true, shift: true },
  });

  if (!membership) {
    throw new NotFoundError('Membership');
  }

  if (data.idempotency_key) {
    const prior = await prisma.attendanceSession.findFirst({
      where: {
        idempotency_key_in: data.idempotency_key,
        organization_id,
        branch_id,
        member_id: membership.id,
      },
      include: { evidence: true },
    });
    if (prior) return prior;
  }

  const policy = await getEffectivePolicyForMember(organization_id, branch_id, membership.id);
  if (data.policy_version != null && data.policy_version !== policy.version) {
    throw new ConflictError('Attendance policy changed while you were preparing the punch', {
      reason: 'STALE_POLICY_VERSION',
      reviewed_version: data.policy_version,
      current_version: policy.version,
    });
  }
  if (policy.punch_required === false) {
    throw new UnprocessableError('Attendance punching is disabled by this policy', {
      reason: 'PUNCH_NOT_REQUIRED',
    });
  }
  const branchTimezone = membership.branch?.timezone ?? data.timezone;
  validateShiftWindow(membership.shift, policy, new Date(), branchTimezone, 'clock_in');
  let evidenceValidation;
  try {
    evidenceValidation = await validatePunchEvidence(
      actor_id,
      organization_id,
      branch_id,
      policy,
      data,
      'clock_in',
    );
  } catch (error) {
    void notifyAttendanceFailure(
      actor_id,
      organization_id,
      'clock_in',
      data.idempotency_key,
      error,
    );
    throw error;
  }

  try {
    const created = await prisma.$transaction(
      async (tx) => {
        const existingSession = await tx.attendanceSession.findFirst({
          where: {
            organization_id,
            branch_id,
            member_id: membership.id,
            state: 'OPEN',
          },
        });
        if (existingSession) throw new ConflictError('An attendance session is already open');

        const now = new Date();
        const variance = calculateAttendanceVariance(membership.shift, policy, now, branchTimezone);
        const policySnapshot = JSON.parse(JSON.stringify(policy)) as Prisma.InputJsonValue;
        const session = await tx.attendanceSession.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            member_id: membership.id,
            policy_version: policy.version,
            state: 'OPEN',
            source: source as any,
            shift_id: membership.shift_id,
            shift_snapshot: membership.shift
              ? (JSON.parse(JSON.stringify(membership.shift)) as Prisma.InputJsonValue)
              : undefined,
            policy_snapshot: policySnapshot,
            branch_timezone: branchTimezone,
            late_minutes: variance.lateMinutes || undefined,
            derived_status: variance.lateMinutes > 0 ? 'LATE' : undefined,
            clock_in_at: now,
            clock_in_client_at: data.client_time ? new Date(data.client_time) : now,
            clock_in_timezone: branchTimezone,
            idempotency_key_in: data.idempotency_key,
          },
        });

        let selfieAssetId: string | undefined;
        if (data.selfie_storage_key) {
          const asset = await tx.mediaAsset.create({
            data: {
              id: ulid(),
              organization_id,
              owner_type: 'ATTENDANCE_SELFIE',
              owner_id: session.id,
              storage_key: data.selfie_storage_key,
              content_type: data.selfie_content_type ?? 'image/jpeg',
              size_bytes: data.selfie_size_bytes,
              uploaded_by: actor_id,
            },
          });
          selfieAssetId = asset.id;
        }

        if (data.latitude != null || data.longitude != null || data.accuracy != null) {
          await tx.attendanceEvidence.create({
            data: {
              id: ulid(),
              session_id: session.id,
              organization_id,
              type: 'LOCATION_IN',
              latitude: data.latitude,
              longitude: data.longitude,
              accuracy: data.accuracy,
              geofence_distance_meters: evidenceValidation.geofence_distance_meters,
              device_metadata: data.device_info as Prisma.InputJsonValue | undefined,
            },
          });
        }
        if (selfieAssetId) {
          await tx.attendanceEvidence.create({
            data: {
              id: ulid(),
              session_id: session.id,
              organization_id,
              type: 'SELFIE_IN',
              asset_id: selfieAssetId,
            },
          });
        }
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            actor_id,
            action: 'CREATE',
            target_type: 'AttendanceSession',
            target_id: session.id,
          },
        });
        return session;
      },
      { ...attendanceTransactionOptions, isolationLevel: 'Serializable' },
    );
    if (created.derived_status === 'LATE') {
      void notifyAttendance(
        actor_id,
        organization_id,
        'Late arrival recorded',
        'Your attendance was recorded after the scheduled grace period.',
        { type: 'ATTENDANCE_LATE', session_id: created.id },
        `attendance-late:${created.id}`,
      );
    }
    return created;
  } catch (error) {
    const code = (error as { code?: string })?.code;
    if (code === 'P2002' || code === 'P2034') {
      const prior = data.idempotency_key
        ? await prisma.attendanceSession.findFirst({
            where: {
              idempotency_key_in: data.idempotency_key,
              organization_id,
              branch_id,
              member_id: membership.id,
            },
            include: { evidence: true },
          })
        : null;
      if (prior) return prior;
      throw new ConflictError(
        'An attendance session was created concurrently; refresh and try again',
      );
    }
    throw error;
  }
}

export async function clockOut(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: ClockOutInput,
  permissions: Set<string>,
  source: 'SELF' | 'QR_GATE' = 'SELF',
) {
  const session = await prisma.attendanceSession.findFirst({
    where: {
      id: data.session_id,
      organization_id,
      branch_id,
      branch: { status: 'ACTIVE' },
    },
    include: {
      member: { include: { user: { select: { id: true, name: true, avatar_url: true } } } },
    },
  });

  if (!session) throw new NotFoundError('Session');

  // Authorize the target before evaluating evidence or idempotency. A client
  // must never be able to replay another member's result by reusing a key.
  if (session.member!.user_id !== actor_id) {
    if (!permissions.has('ATTENDANCE_CREATE_ALL') && !permissions.has('ALL')) {
      throw new ConflictError('Session does not belong to the calling user');
    }
  }

  if (data.idempotency_key) {
    const prior = await prisma.attendanceSession.findFirst({
      where: {
        idempotency_key_out: data.idempotency_key,
        organization_id,
        branch_id,
        member_id: session.member_id,
      },
      include: { evidence: true },
    });
    if (prior) return prior;
  }

  const policy = session.policy_snapshot
    ? (session.policy_snapshot as any)
    : await getEffectivePolicyForMember(organization_id, branch_id, session.member_id);
  if (data.policy_version != null && data.policy_version !== session.policy_version) {
    throw new ConflictError(
      'Attendance policy changed for this session; refresh before clock-out',
      {
        reason: 'STALE_POLICY_VERSION',
        reviewed_version: data.policy_version,
        session_version: session.policy_version,
      },
    );
  }
  let evidenceValidation;
  try {
    evidenceValidation = await validatePunchEvidence(
      actor_id,
      organization_id,
      branch_id,
      policy,
      data,
      'clock_out',
    );
  } catch (error) {
    void notifyAttendanceFailure(
      actor_id,
      organization_id,
      'clock_out',
      data.idempotency_key,
      error,
    );
    throw error;
  }

  if (session.state !== 'OPEN') {
    throw new ConflictError('Session is not open');
  }

  const now = new Date();
  const worked_minutes = Math.floor((now.getTime() - session.clock_in_at.getTime()) / 60000);
  const branchTimezone = session.branch_timezone ?? data.timezone;
  const variance = calculateAttendanceVariance(
    session.shift_snapshot,
    policy,
    now,
    branchTimezone,
    session.clock_in_at,
  );
  const derived_status = deriveAttendanceStatus(
    session.derived_status,
    worked_minutes,
    policy,
    variance,
  );

  let updated;
  try {
    updated = await prisma.$transaction(
      async (tx) => {
        const result = await tx.attendanceSession.update({
          where: { id: session.id },
          data: {
            state: 'CLOSED',
            clock_out_at: now,
            clock_out_client_at: data.client_time ? new Date(data.client_time) : now,
            clock_out_timezone: branchTimezone,
            worked_minutes,
            late_minutes: variance.lateMinutes || session.late_minutes || undefined,
            early_leave_minutes: variance.earlyLeaveMinutes || undefined,
            derived_status: derived_status as any,
            idempotency_key_out: data.idempotency_key,
            clock_out_source: source,
            updated_at: now,
          },
        });
        let selfieAssetId: string | undefined;
        if (data.selfie_storage_key) {
          const asset = await tx.mediaAsset.create({
            data: {
              id: ulid(),
              organization_id,
              owner_type: 'ATTENDANCE_SELFIE',
              owner_id: session.id,
              storage_key: data.selfie_storage_key,
              content_type: data.selfie_content_type ?? 'image/jpeg',
              size_bytes: data.selfie_size_bytes,
              uploaded_by: actor_id,
            },
          });
          selfieAssetId = asset.id;
        }
        if (data.latitude != null || data.longitude != null || data.accuracy != null) {
          await tx.attendanceEvidence.create({
            data: {
              id: ulid(),
              session_id: session.id,
              organization_id,
              type: 'LOCATION_OUT',
              latitude: data.latitude,
              longitude: data.longitude,
              accuracy: data.accuracy,
              geofence_distance_meters: evidenceValidation.geofence_distance_meters,
            },
          });
        }
        if (selfieAssetId) {
          await tx.attendanceEvidence.create({
            data: {
              id: ulid(),
              session_id: session.id,
              organization_id,
              type: 'SELFIE_OUT',
              asset_id: selfieAssetId,
            },
          });
        }
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            actor_id,
            action: 'UPDATE',
            target_type: 'AttendanceSession',
            target_id: session.id,
          },
        });
        return result;
      },
      { ...attendanceTransactionOptions, isolationLevel: 'Serializable' },
    );
  } catch (error) {
    const code = (error as { code?: string })?.code;
    if (code === 'P2002' || code === 'P2034') {
      const prior = data.idempotency_key
        ? await prisma.attendanceSession.findFirst({
            where: {
              idempotency_key_out: data.idempotency_key,
              organization_id,
              branch_id,
              member_id: session.member_id,
            },
            include: { evidence: true },
          })
        : null;
      if (prior) return prior;
      throw new ConflictError(
        'This attendance session changed while you were submitting; refresh and try again',
      );
    }
    throw error;
  }

  if (updated.derived_status === 'INCOMPLETE' || updated.derived_status === 'LEFT_EARLY') {
    void notifyAttendance(
      actor_id,
      organization_id,
      updated.derived_status === 'INCOMPLETE'
        ? 'Attendance session needs review'
        : 'Early departure recorded',
      updated.derived_status === 'INCOMPLETE'
        ? 'This attendance session did not meet the configured duration or open-session rule.'
        : 'Your attendance was recorded before the scheduled shift end.',
      { type: `ATTENDANCE_${updated.derived_status}`, session_id: updated.id },
      `attendance-status:${updated.id}:${updated.derived_status}`,
    );
  }
  return updated;
}

/**
 * Create a manager-entered attendance record when the resolved policy
 * explicitly allows it. Manual records are always closed/open according to
 * the supplied server-validated values, carry an ADMIN source and MANUAL
 * status, and are audited with the required reason. They never masquerade as
 * a self or QR punch and cannot bypass the one-open-session invariant.
 */
export async function createManualSession(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: CreateManualSessionInput & { idempotency_key: string },
  permissions: Set<string>,
) {
  if (!permissions.has('ALL') && !permissions.has('ATTENDANCE_CREATE_ALL')) {
    throw new ForbiddenError('Manual attendance entry permission is required');
  }

  const membership = await prisma.member.findFirst({
    where: {
      id: data.member_id,
      organization_id,
      branch_id,
      status: 'ACTIVE',
      branch: { status: 'ACTIVE' },
    },
    include: { branch: true },
  });
  if (!membership) throw new NotFoundError('Manual attendance member');

  const prior = await prisma.attendanceSession.findFirst({
    where: {
      idempotency_key_in: data.idempotency_key,
      organization_id,
      branch_id,
      member_id: membership.id,
    },
    include: { evidence: true },
  });
  if (prior) return prior;

  const policy = await getEffectivePolicyForMember(organization_id, branch_id, membership.id);
  if (!policy.allow_manual_entry) {
    throw new ForbiddenError('Manual attendance entry is disabled by this policy');
  }
  if (data.policy_version != null && data.policy_version !== policy.version) {
    throw new ConflictError('Attendance policy changed while the manual record was prepared', {
      reason: 'STALE_POLICY_VERSION',
      reviewed_version: data.policy_version,
      current_version: policy.version,
    });
  }

  const clockInAt = new Date(data.clock_in_at);
  const clockOutAt = data.clock_out_at ? new Date(data.clock_out_at) : null;
  if (Number.isNaN(clockInAt.valueOf()) || (clockOutAt && Number.isNaN(clockOutAt.valueOf()))) {
    throw new UnprocessableError('Manual attendance timestamps are invalid');
  }
  if (clockOutAt && clockOutAt < clockInAt) {
    throw new UnprocessableError('Clock-out must be after clock-in');
  }

  try {
    const created = await prisma.$transaction(
      async (tx) => {
        const existingOpen = await tx.attendanceSession.findFirst({
          where: {
            organization_id,
            branch_id,
            member_id: membership.id,
            state: 'OPEN',
          },
        });
        if (existingOpen) throw new ConflictError('An attendance session is already open');

        const session = await tx.attendanceSession.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            member_id: membership.id,
            policy_version: policy.version,
            policy_snapshot: JSON.parse(JSON.stringify(policy)) as Prisma.InputJsonValue,
            branch_timezone: membership.branch?.timezone ?? 'UTC',
            state: clockOutAt ? 'CLOSED' : 'OPEN',
            source: 'ADMIN',
            derived_status: 'MANUAL',
            worked_minutes: clockOutAt
              ? Math.max(0, Math.floor((clockOutAt.getTime() - clockInAt.getTime()) / 60_000))
              : undefined,
            clock_in_at: clockInAt,
            clock_in_timezone: membership.branch?.timezone ?? 'UTC',
            clock_out_at: clockOutAt ?? undefined,
            clock_out_timezone: clockOutAt ? (membership.branch?.timezone ?? 'UTC') : undefined,
            clock_out_source: clockOutAt ? 'ADMIN' : undefined,
            correction_reason: data.reason,
            idempotency_key_in: data.idempotency_key,
          },
        });

        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id,
            branch_id,
            actor_id,
            action: 'CREATE',
            target_type: 'AttendanceSession',
            target_id: session.id,
            reason: data.reason,
            after_state: {
              source: 'ADMIN',
              derived_status: 'MANUAL',
              member_id: membership.id,
              clock_in_at: clockInAt.toISOString(),
              clock_out_at: clockOutAt?.toISOString() ?? null,
              policy_version: policy.version,
            },
          },
        });
        return session;
      },
      { ...attendanceTransactionOptions, isolationLevel: 'Serializable' },
    );
    return created;
  } catch (error) {
    const code = (error as { code?: string })?.code;
    if (code === 'P2002' || code === 'P2034') {
      const replay = await prisma.attendanceSession.findFirst({
        where: {
          idempotency_key_in: data.idempotency_key,
          organization_id,
          branch_id,
          member_id: membership.id,
        },
        include: { evidence: true },
      });
      if (replay) return replay;
      throw new ConflictError(
        'A manual attendance record was created concurrently; refresh and try again',
      );
    }
    throw error;
  }
}

export async function getActiveSession(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  permissions: Set<string> = new Set<string>(),
) {
  const membership = await prisma.member.findFirst({
    where: {
      organization_id,
      branch_id,
      user_id: actor_id,
      status: 'ACTIVE',
      branch: { status: 'ACTIVE' },
    },
  });

  if (!membership) return null;

  const session = await prisma.attendanceSession.findFirst({
    where: {
      organization_id,
      branch_id,
      member_id: membership.id,
      state: 'OPEN',
    },
    include: { evidence: true },
  });
  if (!session) return null;
  const canReadEvidence =
    permissions.has('ALL') || permissions.has('ATTENDANCE_EVIDENCE_READ_SELF');
  return {
    ...session,
    evidence: canReadEvidence ? session.evidence.map(sanitizeEvidence) : [],
  };
}

export async function listSessions(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  query: ListSessionsQuery,
  permissions: Set<string>,
) {
  const result = await listSessionsPage(actor_id, organization_id, branch_id, query, permissions);
  return result.data;
}

export async function listSessionsPage(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  query: ListSessionsQuery,
  permissions: Set<string>,
) {
  const { period, date_from, date_to, member_id, status, role_id, limit, cursor } = query;

  const branch = await prisma.branch.findFirst({
    where: { id: branch_id, organization_id },
    select: { timezone: true, week_start: true },
  });
  const timezone = branch?.timezone ?? 'UTC';
  const now = new Date();
  const today = localDate(now, timezone);
  let localStart = today;
  let localEnd = addLocalDays(today, 1);
  if (period === 'yesterday') {
    localStart = subtractLocalDays(today, 1);
    localEnd = today;
  } else if (period === 'this_week') {
    const utcWeekday = new Date(`${today}T00:00:00.000Z`).getUTCDay();
    const localWeekday = utcWeekday === 0 ? 7 : utcWeekday;
    const weekStart = branch?.week_start ?? 1;
    localStart = subtractLocalDays(today, (localWeekday - weekStart + 7) % 7);
    localEnd = addLocalDays(localStart, 7);
  } else if (period === 'this_month') {
    const [year, month] = today.split('-').map(Number);
    localStart = `${year.toString().padStart(4, '0')}-${month.toString().padStart(2, '0')}-01`;
    localEnd =
      month === 12 ? `${year + 1}-01-01` : `${year}-${(month + 1).toString().padStart(2, '0')}-01`;
  } else if (period === 'this_year') {
    const year = Number(today.slice(0, 4));
    localStart = `${year}-01-01`;
    localEnd = `${year + 1}-01-01`;
  } else if (period === 'custom') {
    localStart = date_from!;
    localEnd = addLocalDays(date_to!, 1);
  }
  const startDate = localMidnightUtc(localStart, timezone);
  const endDate = localMidnightUtc(localEnd, timezone);

  const where: Prisma.AttendanceSessionWhereInput = {
    organization_id,
    branch_id,
    clock_in_at: { gte: startDate, lt: endDate },
  };

  const roleFilter = role_id
    ? {
        OR: [
          { role_id },
          {
            role_assignments: {
              some: {
                role_id,
                effective_from: { lte: now },
                OR: [{ effective_to: null }, { effective_to: { gt: now } }],
              },
            },
          },
        ],
      }
    : undefined;

  if (status) {
    where.derived_status = status as any;
  }

  const scopeMemberIds = await getAttendanceScopeMemberIds(
    actor_id,
    organization_id,
    branch_id,
    permissions,
  );
  if (scopeMemberIds === null) {
    if (member_id) {
      where.member_id = member_id;
    }
    if (role_id) {
      where.member = roleFilter;
    }
  } else if (scopeMemberIds.length === 0) {
    return { data: [], next_cursor: null };
  } else {
    if (member_id && !scopeMemberIds.includes(member_id)) {
      return { data: [], next_cursor: null };
    }
    where.member_id = { in: scopeMemberIds };
    if (role_id) where.member = roleFilter;
  }

  if (cursor) {
    const cursorSession = await prisma.attendanceSession.findFirst({
      where: { id: cursor, organization_id, branch_id },
      select: { id: true, clock_in_at: true },
    });
    if (cursorSession) {
      where.OR = [
        { clock_in_at: { lt: cursorSession.clock_in_at } },
        { clock_in_at: cursorSession.clock_in_at, id: { lt: cursorSession.id } },
      ];
    }
  }

  const sessions = await prisma.attendanceSession.findMany({
    where,
    include: {
      member: {
        include: { user: { select: { id: true, name: true, avatar_url: true } } },
      },
      evidence: true,
      corrections: { orderBy: { created_at: 'asc' } },
    },
    orderBy: [{ clock_in_at: 'desc' }, { id: 'desc' }],
    take: limit + 1,
  });
  const hasMore = sessions.length > limit;
  const pageSessions = hasMore ? sessions.slice(0, limit) : sessions;
  const canReadAllEvidence =
    permissions.has('ALL') || permissions.has('ATTENDANCE_EVIDENCE_READ_ALL');
  const data = pageSessions.map((session) => {
    const safeEvidence = session.evidence.map(sanitizeEvidence);
    const canReadEvidence =
      canReadAllEvidence && (permissions.has('ATTENDANCE_READ_ALL') || permissions.has('ALL'))
        ? true
        : session.member?.user_id === actor_id &&
          (permissions.has('ATTENDANCE_EVIDENCE_READ_SELF') ||
            permissions.has('ATTENDANCE_READ_SELF'));
    const timeline = buildAttendanceTimeline(
      { ...session, evidence: canReadEvidence ? safeEvidence : [] },
      session.corrections,
    );
    return canReadEvidence
      ? { ...session, evidence: safeEvidence, timeline }
      : { ...session, evidence: [], timeline };
  });
  return {
    data,
    next_cursor: hasMore && data.length > 0 ? data[data.length - 1].id : null,
  };
}

export async function exportSessions(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  query: ListSessionsQuery,
  permissions: Set<string>,
) {
  const sessions = await listSessions(actor_id, organization_id, branch_id, query, permissions);
  await prisma.auditLog.create({
    data: {
      id: ulid(),
      organization_id,
      branch_id,
      actor_id,
      action: 'EXPORT',
      target_type: 'AttendanceSessionExport',
      target_id: branch_id,
      after_state: {
        period: query.period,
        row_count: sessions.length,
        role_filter: query.role_id ?? null,
      },
    },
  });
  const escape = (value: unknown) => {
    const text = value == null ? '' : String(value);
    return `"${text.replace(/"/g, '""')}"`;
  };
  const header = [
    'member_id',
    'member_name',
    'clock_in_at',
    'clock_out_at',
    'worked_minutes',
    'state',
    'derived_status',
    'source',
    'clock_out_source',
    'late_minutes',
    'early_leave_minutes',
    'branch_timezone',
  ];
  const rows = sessions.map((session: any) => [
    session.member_id,
    session.member?.user?.name,
    session.clock_in_at?.toISOString?.() ?? session.clock_in_at,
    session.clock_out_at?.toISOString?.() ?? session.clock_out_at,
    session.worked_minutes,
    session.state,
    session.derived_status,
    session.source,
    session.clock_out_source,
    session.late_minutes,
    session.early_leave_minutes,
    session.branch_timezone,
  ]);
  return [header, ...rows].map((row) => row.map(escape).join(',')).join('\n');
}

export async function getSessionDetail(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  session_id: string,
  permissions: Set<string>,
) {
  const scopeMemberIds = await getAttendanceScopeMemberIds(
    actor_id,
    organization_id,
    branch_id,
    permissions,
  );
  if (scopeMemberIds !== null && scopeMemberIds.length === 0) {
    throw new NotFoundError('Attendance session');
  }
  const session = await prisma.attendanceSession.findFirst({
    where: {
      id: session_id,
      organization_id,
      branch_id,
      ...(scopeMemberIds === null ? {} : { member_id: { in: scopeMemberIds } }),
    },
    include: {
      member: { include: { user: { select: { id: true, name: true, avatar_url: true } } } },
      evidence: true,
      corrections: { orderBy: { created_at: 'asc' } },
    },
  });
  if (!session) throw new NotFoundError('Attendance session');
  const canReadEvidence =
    (permissions.has('ALL') || permissions.has('ATTENDANCE_EVIDENCE_READ_ALL')) &&
    (scopeMemberIds === null || permissions.has('ATTENDANCE_READ_ALL'))
      ? true
      : session.member?.user_id === actor_id &&
        (permissions.has('ATTENDANCE_EVIDENCE_READ_SELF') ||
          permissions.has('ATTENDANCE_READ_SELF'));
  const safeEvidence = session.evidence.map(sanitizeEvidence);
  const timeline = buildAttendanceTimeline(
    { ...session, evidence: canReadEvidence ? safeEvidence : [] },
    session.corrections,
  );
  return canReadEvidence
    ? { ...session, evidence: safeEvidence, timeline }
    : { ...session, evidence: [], timeline };
}

export async function getEvidenceDownloadUrl(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  session_id: string,
  evidence_id: string,
  permissions: Set<string>,
) {
  const session = await prisma.attendanceSession.findFirst({
    where: { id: session_id, organization_id, branch_id },
    include: {
      member: { select: { user_id: true } },
      evidence: { where: { id: evidence_id } },
    },
  });
  if (!session || session.evidence.length === 0) throw new NotFoundError('Attendance evidence');
  const canReadAll = permissions.has('ALL') || permissions.has('ATTENDANCE_EVIDENCE_READ_ALL');
  const canReadSelf =
    permissions.has('ATTENDANCE_EVIDENCE_READ_SELF') ||
    (!canReadAll && permissions.has('ATTENDANCE_READ_SELF'));
  if (!canReadAll && (!canReadSelf || session.member?.user_id !== actor_id)) {
    throw new ForbiddenError('You cannot access this attendance evidence');
  }
  const evidence = session.evidence[0];
  if (!evidence.asset_id) throw new NotFoundError('Attendance media');
  const asset = await prisma.mediaAsset.findFirst({
    where: {
      id: evidence.asset_id,
      organization_id,
      owner_type: 'ATTENDANCE_SELFIE',
      owner_id: session.id,
    },
  });
  if (!asset) throw new NotFoundError('Attendance media');
  const extension = asset.content_type.split('/')[1] ?? 'jpg';
  return {
    url: cloudinary.utils.private_download_url(asset.storage_key, extension, {
      resource_type: 'image',
      type: 'authenticated',
      expires_at: Math.floor(Date.now() / 1000) + 300,
      attachment: false,
    }),
    expires_at: new Date(Date.now() + 300_000),
    content_type: asset.content_type,
  };
}

export async function getPolicy(
  organization_id: string,
  branch_id: string,
  actor_id?: string,
  permissions: Set<string> = new Set<string>(),
  target_member_id?: string,
) {
  if (actor_id) {
    const actorMembership = await prisma.member.findFirst({
      where: { organization_id, branch_id, user_id: actor_id, status: 'ACTIVE' },
      select: { id: true },
    });
    const membership = await prisma.member.findFirst({
      where: {
        organization_id,
        branch_id,
        status: 'ACTIVE',
        ...(target_member_id ? { id: target_member_id } : { user_id: actor_id }),
      },
      include: { branch: true, shift: true },
    });
    if (target_member_id && !membership) throw new NotFoundError('Member policy target');
    if (target_member_id && membership && membership.id !== actorMembership?.id) {
      const scopeMemberIds = await getAttendanceScopeMemberIds(
        actor_id,
        organization_id,
        branch_id,
        permissions,
      );
      const canManagePolicy =
        permissions.has('ALL') ||
        permissions.has('ATTENDANCE_POLICY_READ') ||
        permissions.has('ATTENDANCE_POLICY_ASSIGN') ||
        permissions.has('ATTENDANCE_POLICY_MANAGE');
      if (!canManagePolicy && scopeMemberIds !== null && !scopeMemberIds.includes(membership.id)) {
        throw new ForbiddenError('You cannot inspect this member attendance policy');
      }
    }
    if (membership) {
      const policy = await getEffectivePolicyForMember(organization_id, branch_id, membership.id);
      return {
        ...policy,
        location_required:
          policy.location_on_clock_in || policy.location_on_clock_out || policy.geofence_enabled,
        resolved_member_id: membership.id,
        branch_timezone: membership.branch?.timezone ?? null,
        shift_snapshot: membership.shift
          ? {
              id: membership.shift.id,
              name: membership.shift.name,
              start_time: membership.shift.start_time,
              end_time: membership.shift.end_time,
              is_overnight: membership.shift.is_overnight,
              week_days: membership.shift.week_days,
            }
          : null,
      };
    }
  }
  const policy = await getEffectivePolicy(organization_id, branch_id);
  return {
    ...policy,
    location_required:
      policy.location_on_clock_in || policy.location_on_clock_out || policy.geofence_enabled,
  };
}

export async function listPolicies(
  organization_id: string,
  branch_id: string,
  permissions: Set<string>,
) {
  if (
    !permissions.has('ALL') &&
    !permissions.has('ATTENDANCE_POLICY_READ') &&
    !permissions.has('ATTENDANCE_POLICY_MANAGE') &&
    !permissions.has('ATTENDANCE_READ_ALL')
  ) {
    throw new ForbiddenError('Attendance policy read permission is required');
  }
  const policies = await prisma.attendancePolicy.findMany({
    where: { organization_id, branch_id },
    include: {
      role: { select: { id: true, name: true, system_key: true } },
      member: { include: { user: { select: { id: true, name: true, avatar_url: true } } } },
    },
    orderBy: [{ effective_from: 'desc' }, { version: 'desc' }],
  });
  const now = new Date();
  return Promise.all(
    policies.map(async (policy) => {
      const activeMemberWhere: Prisma.MemberWhereInput = {
        organization_id,
        branch_id,
        status: 'ACTIVE',
      };
      if (policy.member_id) {
        activeMemberWhere.id = policy.member_id;
      } else if (policy.role_id) {
        activeMemberWhere.OR = [
          { role_id: policy.role_id },
          {
            role_assignments: {
              some: {
                role_id: policy.role_id,
                effective_from: { lte: now },
                OR: [{ effective_to: null }, { effective_to: { gt: now } }],
              },
            },
          },
        ];
      }
      const affected_member_count = await prisma.member.count({ where: activeMemberWhere });
      return { ...policy, affected_member_count };
    }),
  );
}

export async function updatePolicy(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  data: UpdatePolicyInput,
  permissions: Set<string>,
) {
  if (
    !permissions.has('ALL') &&
    !permissions.has('ATTENDANCE_POLICY_MANAGE') &&
    !permissions.has('ATTENDANCE_POLICY_ASSIGN') &&
    !permissions.has('BRANCH_SETTINGS_UPDATE')
  ) {
    throw new ForbiddenError('Attendance policy management permission is required');
  }
  return prisma.$transaction(async (tx) => {
    const txClient = tx as typeof prisma;
    const roleId = data.role_id ?? null;
    const memberId = data.member_id ?? null;
    if (roleId && memberId) {
      throw new ConflictError('An attendance policy can target a role or member, not both');
    }
    if (memberId) {
      const target = await txClient.member.findFirst({
        where: { id: memberId, organization_id, branch_id },
      });
      if (!target) throw new NotFoundError('Member policy target');
    }
    if (roleId) {
      const target = await txClient.role.findFirst({
        where: { id: roleId, organization_id, OR: [{ branch_id }, { branch_id: null }] },
      });
      if (!target) throw new NotFoundError('Role policy target');
    }
    const currentPolicy = await txClient.attendancePolicy.findFirst({
      where: {
        organization_id,
        branch_id,
        role_id: roleId,
        member_id: memberId,
        effective_to: null,
      },
      orderBy: [{ effective_from: 'desc' }, { version: 'desc' }],
    });

    const version = currentPolicy ? currentPolicy.version + 1 : 1;
    const effectiveFrom = data.effective_from ? new Date(data.effective_from) : new Date();
    if (Number.isNaN(effectiveFrom.valueOf())) {
      throw new UnprocessableError('Policy effective date is invalid');
    }
    if (effectiveFrom.getTime() < Date.now() - 60_000) {
      throw new UnprocessableError('Policy effective date cannot be in the past');
    }
    if (currentPolicy && effectiveFrom <= currentPolicy.effective_from) {
      throw new ConflictError('Policy effective date must be after the active version');
    }

    const geofenceEnabled = data.geofence_enabled ?? currentPolicy?.geofence_enabled ?? false;
    const geofenceLat =
      data.geofence_lat !== undefined ? data.geofence_lat : currentPolicy?.geofence_lat;
    const geofenceLng =
      data.geofence_lng !== undefined ? data.geofence_lng : currentPolicy?.geofence_lng;
    const geofenceRadius =
      data.geofence_radius_meters !== undefined
        ? data.geofence_radius_meters
        : currentPolicy?.geofence_radius_meters;
    const allowOfflineCapture =
      data.allow_offline_capture ?? currentPolicy?.allow_offline_capture ?? false;
    if (allowOfflineCapture) {
      throw new UnprocessableError(
        'Offline attendance capture is not supported until server sync safeguards are enabled',
        { reason: 'OFFLINE_CAPTURE_UNSUPPORTED' },
      );
    }
    if (geofenceEnabled) {
      if (geofenceRadius == null) {
        throw new UnprocessableError('A geofence radius is required when geofencing is enabled', {
          reason: 'GEOFENCE_RADIUS_REQUIRED',
        });
      }
      if (geofenceLat == null || geofenceLng == null) {
        const branch = await txClient.branch.findFirst({
          where: { id: branch_id, organization_id },
          select: { latitude: true, longitude: true },
        });
        if (branch?.latitude == null || branch.longitude == null) {
          throw new UnprocessableError(
            'A geofence center or branch location is required when geofencing is enabled',
            { reason: 'GEOFENCE_CENTER_REQUIRED' },
          );
        }
      }
    }

    if (currentPolicy) {
      await txClient.attendancePolicy.update({
        where: { id: currentPolicy.id },
        data: { effective_to: effectiveFrom },
      });
    }

    const newPolicy = await txClient.attendancePolicy.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        role_id: roleId,
        member_id: memberId,
        version,
        effective_from: effectiveFrom,
        punch_required: data.punch_required ?? currentPolicy?.punch_required ?? true,
        selfie_on_clock_in: data.selfie_on_clock_in ?? currentPolicy?.selfie_on_clock_in ?? false,
        selfie_on_clock_out:
          data.selfie_on_clock_out ?? currentPolicy?.selfie_on_clock_out ?? false,
        location_on_clock_in:
          data.location_on_clock_in ?? currentPolicy?.location_on_clock_in ?? false,
        location_on_clock_out:
          data.location_on_clock_out ?? currentPolicy?.location_on_clock_out ?? false,
        geofence_enabled: geofenceEnabled,
        geofence_lat: geofenceLat,
        geofence_lng: geofenceLng,
        geofence_radius_meters: geofenceRadius,
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
        allow_offline_capture: false,
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
  }, attendanceTransactionOptions);
}

export async function correctSession(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  session_id: string,
  data: CorrectSessionInput,
  permissions: Set<string>,
) {
  if (!permissions.has('ALL') && !permissions.has('ATTENDANCE_UPDATE')) {
    throw new ForbiddenError('Attendance correction permission is required');
  }
  try {
    return await prisma.$transaction(
      async (tx) => {
        const txClient = tx as typeof prisma;

        const session = await txClient.attendanceSession.findFirst({
          where: { id: session_id, organization_id, branch_id },
        });

        if (!session) {
          throw new NotFoundError('Attendance session not found');
        }

        const correctedClockIn = data.clock_in_at
          ? new Date(data.clock_in_at)
          : session.clock_in_at;
        const correctedClockOut = data.clock_out_at
          ? new Date(data.clock_out_at)
          : session.clock_out_at;
        if (correctedClockOut && correctedClockOut < correctedClockIn) {
          throw new UnprocessableError('Clock-out must be after clock-in');
        }

        const correctionVersion = session.correction_version + 1;
        await txClient.attendanceCorrection.create({
          data: {
            id: ulid(),
            session_id: session.id,
            organization_id,
            branch_id,
            version: correctionVersion,
            actor_id,
            previous_clock_in_at: session.clock_in_at,
            previous_clock_out_at: session.clock_out_at,
            previous_state: session.state,
            previous_derived_status: session.derived_status,
            corrected_clock_in_at: correctedClockIn,
            corrected_clock_out_at: correctedClockOut,
            corrected_state: 'CORRECTED',
            corrected_derived_status: data.derived_status ?? session.derived_status,
            reason: data.correction_reason,
          },
        });

        const updatedSession = await txClient.attendanceSession.update({
          where: { id: session_id },
          data: {
            clock_in_at: correctedClockIn,
            clock_out_at: correctedClockOut,
            worked_minutes: correctedClockOut
              ? Math.max(
                  0,
                  Math.floor((correctedClockOut.getTime() - correctedClockIn.getTime()) / 60000),
                )
              : null,
            derived_status: data.derived_status ?? session.derived_status,
            state: 'CORRECTED',
            correction_version: correctionVersion,
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
              correction_version: session.correction_version,
              clock_in: session.clock_in_at,
              clock_out: session.clock_out_at,
              status: session.derived_status,
            },
            after_state: {
              correction_version: correctionVersion,
              clock_in: updatedSession.clock_in_at,
              clock_out: updatedSession.clock_out_at,
              status: updatedSession.derived_status,
            },
          },
        });

        return updatedSession;
      },
      { ...attendanceTransactionOptions, isolationLevel: 'Serializable' },
    );
  } catch (error) {
    const code = (error as { code?: string })?.code;
    if (code === 'P2002' || code === 'P2034') {
      throw new ConflictError('This attendance record was corrected by another action; refresh it');
    }
    throw error;
  }
}
