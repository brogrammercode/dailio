import { ulid } from 'ulid';
import type { Holiday } from '@prisma/client';

import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../lib/errors';
import { prisma } from '../../lib/prisma';
import { findBranchRecipientUserIds, notify } from '../notifications/notifications.service';

import type { CreateHolidayInput, UpdateHolidayInput } from './holidays.schema';

type HolidayRow = {
  date: Date | null;
  end_date: Date | null;
  dates: unknown;
  recurring_weekdays: unknown;
};

function toDate(value: string) {
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    throw new ValidationError('Invalid holiday date');
  }
  return date;
}

function dateValue(value: Date) {
  return value.toISOString().slice(0, 10);
}

function uniqueSortedDates(values: string[]) {
  return [...new Set(values)].sort();
}

function expandLegacyDates(start: Date | null, end: Date | null) {
  if (!start) return [];
  const dates: string[] = [];
  const first = dateValue(start);
  const last = dateValue(end ?? start);
  for (let day = first; day <= last;) {
    dates.push(day);
    const next = new Date(`${day}T00:00:00.000Z`);
    next.setUTCDate(next.getUTCDate() + 1);
    day = next.toISOString().slice(0, 10);
  }
  return dates;
}

export function normalizedHolidayDates(row: HolidayRow) {
  return Array.isArray(row.dates) && row.dates.length > 0
    ? uniqueSortedDates(row.dates.map(String))
    : expandLegacyDates(row.date, row.end_date);
}

function normalizedWeekdays(value: unknown) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map(Number))]
    .filter((day) => day >= 1 && day <= 7)
    .sort((a, b) => a - b);
}

function isContiguous(dates: string[]) {
  if (dates.length < 2) return true;
  for (let index = 1; index < dates.length; index += 1) {
    const previous = new Date(`${dates[index - 1]}T00:00:00.000Z`);
    previous.setUTCDate(previous.getUTCDate() + 1);
    if (previous.toISOString().slice(0, 10) !== dates[index]) return false;
  }
  return true;
}

function legacyColumns(dates: string[]) {
  const first = dates[0] ? toDate(dates[0]) : null;
  return {
    date: first,
    end_date:
      first && isContiguous(dates) && dates.length > 1 ? toDate(dates[dates.length - 1]) : null,
  };
}

function normalizeInputDates(input: { dates?: string[]; date?: string; end_date?: string | null }) {
  if (input.dates !== undefined) {
    return uniqueSortedDates(input.dates.map((value) => dateValue(toDate(value))));
  }
  if (input.date) {
    return expandLegacyDates(toDate(input.date), input.end_date ? toDate(input.end_date) : null);
  }
  return [];
}

function branchScope(organizationId: string, branchId: string) {
  return { organization_id: organizationId, OR: [{ branch_id: branchId }, { branch_id: null }] };
}

function responseHoliday(row: Holiday) {
  return {
    ...row,
    dates: normalizedHolidayDates(row),
    recurring_weekdays: normalizedWeekdays(row.recurring_weekdays),
  };
}

function notifyHolidayChange(
  organizationId: string,
  branchId: string,
  actorUserId: string,
  holiday: { id: string; name: string },
  action: 'CREATED' | 'UPDATED' | 'DELETED',
  dates: string[],
  recurringWeekdays: number[],
) {
  void (async () => {
    try {
      const recipientUserIds = await findBranchRecipientUserIds(
        organizationId,
        branchId,
        'HOLIDAY_READ',
      );
      await notify({
        type: `HOLIDAY_${action}`,
        organizationId,
        branchId,
        actorUserId,
        entityType: 'Holiday',
        entityId: holiday.id,
        recipientUserIds,
        title: action === 'DELETED' ? 'Holiday removed' : 'Holiday calendar updated',
        body:
          action === 'CREATED'
            ? `${holiday.name} was added to the branch holiday calendar.`
            : action === 'UPDATED'
              ? `${holiday.name} was updated in the branch holiday calendar.`
              : `${holiday.name} was removed from the branch holiday calendar.`,
        data: {
          holiday_id: holiday.id,
          action,
          dates: JSON.stringify(dates),
          recurring_weekdays: JSON.stringify(recurringWeekdays),
        },
        dedupeKey: `holiday:${holiday.id}:${action.toLowerCase()}:${
          action === 'DELETED' ? 'deleted' : Date.now()
        }`,
      });
    } catch {
      // Calendar notifications are auxiliary and must never delay or fail the
      // committed holiday mutation.
    }
  })();
}

export async function listHolidays(organizationId: string, branchId: string) {
  const rows = await prisma.holiday.findMany({
    where: branchScope(organizationId, branchId),
    orderBy: [{ created_at: 'asc' }, { name: 'asc' }],
  });
  return rows.map(responseHoliday);
}

export async function createHoliday(
  organizationId: string,
  branchId: string,
  input: CreateHolidayInput,
  actorUserId: string,
  headerIdempotencyKey?: string,
) {
  if (input.branch_id && input.branch_id !== branchId)
    throw new ForbiddenError('Holiday branch scope is invalid');
  const dates = normalizeInputDates(input);
  const recurringWeekdays = normalizedWeekdays(input.recurring_weekdays);
  if (dates.length === 0 && recurringWeekdays.length === 0) {
    throw new ValidationError('Add at least one date or recurring weekday');
  }
  const idempotencyKey = input.idempotency_key ?? headerIdempotencyKey;
  if (idempotencyKey) {
    const existing = await prisma.holiday.findUnique({
      where: { idempotency_key: idempotencyKey },
    });
    if (existing) {
      if (existing.organization_id !== organizationId || existing.branch_id !== branchId)
        throw new ConflictError('Idempotency key belongs to another holiday');
      return responseHoliday(existing);
    }
  }
  const legacy = legacyColumns(dates);
  const holiday = await prisma.$transaction(async (tx) => {
    const created = await tx.holiday.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        name: input.name,
        date: legacy.date,
        end_date: legacy.end_date,
        dates,
        recurring_weekdays: recurringWeekdays,
        is_recurring: input.is_recurring === true || recurringWeekdays.length > 0,
        idempotency_key: idempotencyKey,
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'CREATE',
        target_type: 'Holiday',
        target_id: created.id,
        after_state: { name: created.name, dates, recurring_weekdays: recurringWeekdays },
      },
    });
    return created;
  });
  notifyHolidayChange(
    organizationId,
    branchId,
    actorUserId,
    holiday,
    'CREATED',
    dates,
    recurringWeekdays,
  );
  return responseHoliday(holiday);
}

async function getHoliday(organizationId: string, branchId: string, holidayId: string) {
  const holiday = await prisma.holiday.findFirst({
    where: { id: holidayId, organization_id: organizationId, branch_id: branchId },
  });
  if (!holiday) throw new NotFoundError('Holiday');
  return holiday;
}

export async function updateHoliday(
  organizationId: string,
  branchId: string,
  holidayId: string,
  input: UpdateHolidayInput,
  actorUserId: string,
) {
  const current = await getHoliday(organizationId, branchId, holidayId);
  const dates =
    input.dates !== undefined || input.date !== undefined
      ? normalizeInputDates(input)
      : normalizedHolidayDates(current);
  const recurringWeekdays =
    input.recurring_weekdays !== undefined
      ? normalizedWeekdays(input.recurring_weekdays)
      : normalizedWeekdays(current.recurring_weekdays);
  if (dates.length === 0 && recurringWeekdays.length === 0) {
    throw new ValidationError('Add at least one date or recurring weekday');
  }
  const legacy = legacyColumns(dates);
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.holiday.update({
      where: { id: current.id },
      data: {
        name: input.name,
        date: legacy.date,
        end_date: legacy.end_date,
        dates,
        recurring_weekdays: recurringWeekdays,
        is_recurring:
          input.is_recurring === undefined
            ? current.is_recurring || recurringWeekdays.length > 0
            : input.is_recurring || recurringWeekdays.length > 0,
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'UPDATE',
        target_type: 'Holiday',
        target_id: current.id,
        before_state: {
          name: current.name,
          dates: normalizedHolidayDates(current),
          recurring_weekdays: normalizedWeekdays(current.recurring_weekdays),
        },
        after_state: { name: result.name, dates, recurring_weekdays: recurringWeekdays },
      },
    });
    return result;
  });
  notifyHolidayChange(
    organizationId,
    branchId,
    actorUserId,
    updated,
    'UPDATED',
    dates,
    recurringWeekdays,
  );
  return responseHoliday(updated);
}

export async function deleteHoliday(
  organizationId: string,
  branchId: string,
  holidayId: string,
  actorUserId: string,
) {
  const current = await getHoliday(organizationId, branchId, holidayId);
  await prisma.$transaction(async (tx) => {
    await tx.holiday.delete({ where: { id: current.id } });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'DELETE',
        target_type: 'Holiday',
        target_id: current.id,
        before_state: {
          name: current.name,
          dates: normalizedHolidayDates(current),
          recurring_weekdays: normalizedWeekdays(current.recurring_weekdays),
        },
      },
    });
  });
  notifyHolidayChange(
    organizationId,
    branchId,
    actorUserId,
    current,
    'DELETED',
    normalizedHolidayDates(current),
    normalizedWeekdays(current.recurring_weekdays),
  );
}
