import { NotFoundError } from '../../lib/errors';
import { prisma } from '../../lib/prisma';
import { normalizedHolidayDates } from '../holidays/holidays.service';

function localDate(value: Date, timezone: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(value);
}

function dateOnly(value: string) {
  return new Date(`${value}T00:00:00.000Z`);
}

function addDays(value: string, amount: number) {
  const date = dateOnly(value);
  date.setUTCDate(date.getUTCDate() + amount);
  return date.toISOString().slice(0, 10);
}

function weekday(value: string) {
  const sundayBased = new Date(`${value}T00:00:00.000Z`).getUTCDay();
  return sundayBased === 0 ? 7 : sundayBased;
}

export function recurringWeekdayDates(weekdaysInput: Iterable<number>, from: string, to: string) {
  const weekdays = new Set(weekdaysInput);
  const dates = new Set<string>();
  for (let day = from; day <= to; day = addDays(day, 1)) {
    if (weekdays.has(weekday(day))) dates.add(day);
  }
  return dates;
}

export function calculateStreakFromDates(
  attendedDatesInput: Iterable<string>,
  holidayDatesInput: Iterable<string>,
  today: string,
) {
  const attendedDates = new Set(attendedDatesInput);
  const holidayDates = new Set(holidayDatesInput);
  const firstDate = [...attendedDates].sort()[0];
  let current = 0;
  let best = 0;
  let lastAttendanceDate: string | null = null;
  if (firstDate) {
    for (let day = firstDate; day <= today; day = addDays(day, 1)) {
      if (attendedDates.has(day)) {
        current += 1;
        best = Math.max(best, current);
        lastAttendanceDate = day;
      } else if (!holidayDates.has(day)) {
        current = 0;
      }
    }
  }
  return { current, best, lastAttendanceDate };
}

export async function calculateMemberStreak(
  organizationId: string,
  branchId: string,
  memberId: string,
  now = new Date(),
) {
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, organization_id: organizationId },
    select: { timezone: true },
  });
  if (!branch) throw new NotFoundError('Branch');

  const today = localDate(now, branch.timezone);
  const sessions = await prisma.attendanceSession.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      member_id: memberId,
      state: { not: 'VOID' },
    },
    select: { clock_in_at: true },
    orderBy: { clock_in_at: 'asc' },
  });
  const attendedDates = sessions.map((session) => localDate(session.clock_in_at, branch.timezone));
  const holidays = await prisma.holiday.findMany({
    where: {
      organization_id: organizationId,
      OR: [{ branch_id: branchId }, { branch_id: null }],
    },
    select: {
      date: true,
      end_date: true,
      dates: true,
      recurring_weekdays: true,
      is_recurring: true,
    },
  });
  const holidayDates = new Set<string>();
  const firstAttendedDate = [...new Set(attendedDates)].sort()[0];
  for (const holiday of holidays) {
    const explicitDates = normalizedHolidayDates(holiday);
    if (holiday.is_recurring) {
      const startYear = firstAttendedDate
        ? Number(firstAttendedDate.slice(0, 4))
        : Number(today.slice(0, 4));
      const endYear = Number(today.slice(0, 4));
      for (const explicitDate of explicitDates) {
        for (let year = startYear; year <= endYear; year += 1) {
          const recurringDate = `${year}-${explicitDate.slice(5)}`;
          if (
            recurringDate <= today &&
            (!firstAttendedDate || recurringDate >= firstAttendedDate)
          ) {
            holidayDates.add(recurringDate);
          }
        }
      }
    } else {
      for (const explicitDate of explicitDates) {
        if (explicitDate <= today && (!firstAttendedDate || explicitDate >= firstAttendedDate)) {
          holidayDates.add(explicitDate);
        }
      }
    }
    if (firstAttendedDate && Array.isArray(holiday.recurring_weekdays)) {
      for (const date of recurringWeekdayDates(
        holiday.recurring_weekdays.map(Number),
        firstAttendedDate,
        today,
      )) {
        holidayDates.add(date);
      }
    }
  }

  const { current, best, lastAttendanceDate } = calculateStreakFromDates(
    attendedDates,
    holidayDates,
    today,
  );
  const calculated = dateOnly(today);
  const streak = await prisma.attendanceStreak.upsert({
    where: {
      organization_id_branch_id_member_id: {
        organization_id: organizationId,
        branch_id: branchId,
        member_id: memberId,
      },
    },
    create: {
      organization_id: organizationId,
      branch_id: branchId,
      member_id: memberId,
      current_streak: current,
      best_streak: best,
      last_attendance_date: lastAttendanceDate ? dateOnly(lastAttendanceDate) : null,
      calculated_for_date: calculated,
    },
    update: {
      current_streak: current,
      best_streak: best,
      last_attendance_date: lastAttendanceDate ? dateOnly(lastAttendanceDate) : null,
      calculated_for_date: calculated,
    },
  });
  return streak;
}

export async function getMemberStreak(organizationId: string, branchId: string, memberId: string) {
  // Streaks are an intentionally lightweight member-facing signal. The
  // route is already restricted to an authenticated active branch member;
  // keep the target lookup scoped below so this never becomes a cross-tenant
  // attendance read. Detailed attendance records and evidence remain
  // permission-scoped elsewhere.
  const member = await prisma.member.findFirst({
    where: { id: memberId, organization_id: organizationId, branch_id: branchId, status: 'ACTIVE' },
    select: { id: true },
  });
  if (!member) throw new NotFoundError('Member');
  return calculateMemberStreak(organizationId, branchId, memberId);
}

export async function refreshAllMemberStreaks() {
  const members = await prisma.member.findMany({
    where: { status: 'ACTIVE' },
    select: { id: true, organization_id: true, branch_id: true },
  });
  let refreshed = 0;
  for (const member of members) {
    try {
      await calculateMemberStreak(member.organization_id, member.branch_id, member.id);
      refreshed += 1;
    } catch {
      // A deleted/archived branch should not fail the rest of the daily job.
    }
  }
  return { scanned: members.length, refreshed };
}
