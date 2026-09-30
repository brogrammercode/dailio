import { Prisma } from '@prisma/client';
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';

import { notify } from './notifications.service';

function localMonthDay(value: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const month = parts.find((part) => part.type === 'month')?.value;
  const day = parts.find((part) => part.type === 'day')?.value;
  return month && day ? `${month}-${day}` : '';
}

function localDate(value: Date, timezone: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(value);
}

export function birthdayMatchesLocalDate(dateOfBirth: Date, now: Date, timezone: string) {
  return localMonthDay(dateOfBirth, timezone) === localMonthDay(now, timezone);
}

export async function runBirthdayAnnouncements(now = new Date()) {
  const members = await prisma.member.findMany({
    where: { status: 'ACTIVE', user: { date_of_birth: { not: null } } },
    select: {
      id: true,
      branch_id: true,
      organization_id: true,
      user: { select: { id: true, name: true, date_of_birth: true } },
      branch: { select: { timezone: true } },
    },
  });
  let created = 0;
  for (const member of members) {
    if (!member.user.date_of_birth) continue;
    const businessDate = localDate(now, member.branch?.timezone ?? 'UTC');
    if (!birthdayMatchesLocalDate(member.user.date_of_birth, now, member.branch?.timezone ?? 'UTC'))
      continue;

    const automationKey = `birthday:${member.branch_id}:${member.id}:${businessDate}`;
    const owner = await prisma.member.findFirst({
      where: {
        organization_id: member.organization_id,
        branch_id: member.branch_id,
        status: 'ACTIVE',
        role: { system_key: 'OWNER' },
      },
      select: { user_id: true },
    });
    const actorUserId = owner?.user_id ?? member.user.id;
    const recipients = await prisma.member.findMany({
      where: {
        organization_id: member.organization_id,
        branch_id: member.branch_id,
        status: 'ACTIVE',
      },
      select: { id: true, user_id: true },
    });

    try {
      const announcement = await prisma.$transaction(async (tx) => {
        const existing = await tx.announcement.findUnique({
          where: { automation_key: automationKey },
        });
        if (existing) return null;
        const createdAnnouncement = await tx.announcement.create({
          data: {
            id: ulid(),
            organization_id: member.organization_id,
            branch_id: member.branch_id,
            title: `🎉 Happy Birthday, ${member.user.name}!`,
            body: `Help us celebrate ${member.user.name} today. Wishing them a wonderful year ahead!`,
            content: [
              { type: 'heading', text: `Happy Birthday, ${member.user.name}!` },
              { type: 'paragraph', text: 'Wishing you a strong, healthy and joyful year ahead.' },
            ],
            priority: 1,
            status: 'PUBLISHED',
            audience: 'ALL_ACTIVE_MEMBERS',
            publish_at: now,
            created_by: actorUserId,
            updated_by: actorUserId,
            automation_key: automationKey,
          },
        });
        await tx.announcementRecipient.createMany({
          data: recipients.map((recipient) => ({
            announcement_id: createdAnnouncement.id,
            member_id: recipient.id,
          })),
          skipDuplicates: true,
        });
        await tx.auditLog.create({
          data: {
            id: ulid(),
            organization_id: member.organization_id,
            branch_id: member.branch_id,
            actor_id: actorUserId,
            action: 'CREATE',
            target_type: 'Announcement',
            target_id: createdAnnouncement.id,
            source: 'SYSTEM',
            after_state: { automation_key: automationKey, birthday_member_id: member.id },
          },
        });
        return createdAnnouncement;
      });
      if (!announcement) continue;
      created += 1;
      await notify({
        type: 'ANNOUNCEMENT_PUBLISHED',
        organizationId: member.organization_id,
        branchId: member.branch_id,
        actorUserId,
        entityType: 'Announcement',
        entityId: announcement.id,
        recipientUserIds: [...new Set(recipients.map((recipient) => recipient.user_id))],
        title: announcement.title,
        body: announcement.body,
        data: {
          organization_id: member.organization_id,
          branch_id: member.branch_id,
          entity_id: announcement.id,
        },
        dedupeKey: `${automationKey}:notification`,
      }).catch(() => undefined);
    } catch (error) {
      if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002') {
        throw error;
      }
    }
  }
  return { scanned: members.length, created };
}
