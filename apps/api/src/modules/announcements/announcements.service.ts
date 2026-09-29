import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError, ValidationError } from '../../lib/errors';
import { notify } from '../notifications/notifications.service';

import type { CreateAnnouncementInput, UpdateAnnouncementInput } from './announcements.schema';

type Scope = { organizationId: string; branchId: string | null };

function recipientWhere(scope: Scope, input: Pick<CreateAnnouncementInput, 'audience' | 'role_ids' | 'member_ids'>) {
  const branch = scope.branchId ? { branch_id: scope.branchId } : {};
  if (input.audience === 'SELECTED_MEMBERS') return { ...branch, id: { in: input.member_ids }, status: 'ACTIVE' as const };
  if (input.audience === 'SELECTED_ROLES') return { ...branch, role_id: { in: input.role_ids }, status: 'ACTIVE' as const };
  return { ...branch, status: 'ACTIVE' as const };
}

async function resolveRecipients(scope: Scope, input: Pick<CreateAnnouncementInput, 'audience' | 'role_ids' | 'member_ids'>) {
  if (input.audience === 'SELECTED_ROLES' && input.role_ids.length === 0) throw new ValidationError('Select at least one role');
  if (input.audience === 'SELECTED_MEMBERS' && input.member_ids.length === 0) throw new ValidationError('Select at least one member');
  const members = await prisma.member.findMany({ where: { organization_id: scope.organizationId, ...recipientWhere(scope, input) }, select: { id: true, user_id: true } });
  if (input.audience !== 'ALL_ACTIVE_MEMBERS' && members.length === 0) throw new ValidationError('No active recipients match the selected audience');
  if (input.audience === 'SELECTED_MEMBERS' && members.length !== input.member_ids.length) throw new ValidationError('One or more selected members are outside the announcement scope');
  return members;
}

function toDate(value: string | null | undefined) {
  if (value == null) return value === null ? null : undefined;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new ValidationError('Invalid announcement date');
  return date;
}

export async function listAnnouncements(organizationId: string, branchId: string) {
  return prisma.announcement.findMany({
    where: { organization_id: organizationId, OR: [{ branch_id: branchId }, { branch_id: null }] },
    include: { _count: { select: { recipients: true } } },
    orderBy: [{ priority: 'desc' }, { created_at: 'desc' }],
  });
}

export async function createAnnouncement(organizationId: string, scope: Scope, input: CreateAnnouncementInput, actorUserId: string) {
  const publishAt = toDate(input.publish_at);
  const expiresAt = toDate(input.expires_at);
  if (publishAt && expiresAt && expiresAt <= publishAt) throw new ValidationError('Expiry must be after publish time');
  if (scope.branchId && input.branch_id && input.branch_id !== scope.branchId) throw new ValidationError('Announcement branch scope is invalid');
  const branchId = input.branch_id === undefined ? scope.branchId : input.branch_id;
  if (input.branch_id !== undefined && input.branch_id !== null && input.branch_id !== scope.branchId) {
    throw new ValidationError('Announcement branch scope is invalid');
  }
  const status = publishAt && publishAt > new Date() ? 'SCHEDULED' : 'DRAFT';
  const initialRecipients = input.audience === 'ALL_ACTIVE_MEMBERS'
    ? []
    : await resolveRecipients({ organizationId, branchId }, input);
  const created = await prisma.$transaction(async (tx) => {
    const announcement = await tx.announcement.create({ data: { id: ulid(), organization_id: organizationId, branch_id: branchId, title: input.title, body: input.body, priority: input.priority ?? 0, audience: input.audience, publish_at: publishAt, expires_at: expiresAt, status, created_by: actorUserId, updated_by: actorUserId } });
    await tx.auditLog.create({ data: { id: ulid(), organization_id: organizationId, branch_id: branchId, actor_id: actorUserId, action: 'CREATE', target_type: 'Announcement', target_id: announcement.id, after_state: { title: announcement.title, audience: announcement.audience, status } } });
    if (initialRecipients.length > 0) {
      await tx.announcementRecipient.createMany({ data: initialRecipients.map((member) => ({ announcement_id: announcement.id, member_id: member.id })), skipDuplicates: true });
    }
    return announcement;
  });
  return created;
}

export async function updateAnnouncement(organizationId: string, branchId: string, id: string, input: UpdateAnnouncementInput, actorUserId: string) {
  const current = await prisma.announcement.findFirst({ where: { id, organization_id: organizationId, OR: [{ branch_id: branchId }, { branch_id: null }] } });
  if (!current) throw new NotFoundError('Announcement');
  if (!['DRAFT', 'SCHEDULED'].includes(current.status)) throw new ConflictError('Only draft or scheduled announcements can be edited');
  if (input.branch_id !== undefined && input.branch_id !== null && input.branch_id !== branchId) throw new ValidationError('Announcement branch scope is invalid');
  const publishAt = input.publish_at === undefined ? undefined : toDate(input.publish_at);
  const expiresAt = input.expires_at === undefined ? undefined : toDate(input.expires_at);
  const effectivePublishAt = publishAt === undefined ? current.publish_at : publishAt;
  const effectiveExpiresAt = expiresAt === undefined ? current.expires_at : expiresAt;
  if (effectivePublishAt && effectiveExpiresAt && effectiveExpiresAt <= effectivePublishAt) throw new ValidationError('Expiry must be after publish time');
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.announcement.update({ where: { id }, data: { branch_id: input.branch_id === undefined ? undefined : input.branch_id, title: input.title, body: input.body, priority: input.priority, audience: input.audience, publish_at: publishAt, expires_at: expiresAt, status: effectivePublishAt && effectivePublishAt > new Date() ? 'SCHEDULED' : 'DRAFT', updated_by: actorUserId } });
    await tx.auditLog.create({ data: { id: ulid(), organization_id: organizationId, branch_id: result.branch_id ?? branchId, actor_id: actorUserId, action: 'UPDATE', target_type: 'Announcement', target_id: id, after_state: { title: result.title, status: result.status } } });
    return result;
  });
  if (input.audience || input.role_ids || input.member_ids) {
    await prisma.announcementRecipient.deleteMany({ where: { announcement_id: id } });
    if (updated.audience !== 'ALL_ACTIVE_MEMBERS') {
      const members = await resolveRecipients(
        { organizationId, branchId: updated.branch_id },
        { audience: updated.audience, role_ids: input.role_ids ?? [], member_ids: input.member_ids ?? [] },
      );
      await prisma.announcementRecipient.createMany({ data: members.map((member) => ({ announcement_id: id, member_id: member.id })), skipDuplicates: true });
    }
  }
  return updated;
}

export async function publishAnnouncement(organizationId: string, branchId: string, id: string, actorUserId?: string) {
  const current = await prisma.announcement.findFirst({ where: { id, organization_id: organizationId, OR: [{ branch_id: branchId }, { branch_id: null }] } });
  if (!current) throw new NotFoundError('Announcement');
  if (!['DRAFT', 'SCHEDULED'].includes(current.status)) throw new ConflictError('Announcement is not publishable');
  const scope = { organizationId, branchId: current.branch_id };
  const storedRecipients = await prisma.announcementRecipient.findMany({ where: { announcement_id: id }, select: { member_id: true } });
  const members = current.audience === 'ALL_ACTIVE_MEMBERS'
    ? await resolveRecipients(scope, { audience: current.audience, role_ids: [], member_ids: [] })
    : await prisma.member.findMany({ where: { organization_id: organizationId, id: { in: storedRecipients.map((recipient) => recipient.member_id) }, status: 'ACTIVE' }, select: { id: true, user_id: true } });
  if (members.length === 0) throw new ValidationError('No active recipients match the selected audience');
  const published = await prisma.$transaction(async (tx) => {
    const result = await tx.announcement.updateMany({ where: { id, organization_id: organizationId, status: { in: ['DRAFT', 'SCHEDULED'] } }, data: { status: 'PUBLISHED', publish_at: new Date(), updated_by: actorUserId } });
    if (result.count !== 1) throw new ConflictError('Announcement was already published');
    await tx.announcementRecipient.createMany({ data: members.map((member) => ({ announcement_id: id, member_id: member.id })) , skipDuplicates: true });
    const announcement = await tx.announcement.findUniqueOrThrow({ where: { id } });
    await tx.auditLog.create({ data: { id: ulid(), organization_id: organizationId, branch_id: (announcement.branch_id ?? branchId) || null, actor_id: actorUserId, action: 'APPROVE', target_type: 'Announcement', target_id: id, after_state: { status: 'PUBLISHED', recipients: members.length } } });
    return announcement;
  });
  const notificationBranchId = current.branch_id ?? (branchId || undefined);
  await notify({ type: 'ANNOUNCEMENT_PUBLISHED', organizationId, branchId: notificationBranchId, entityType: 'Announcement', entityId: published.id, recipientUserIds: members.map((member) => member.user_id), title: published.title, body: published.body, data: { organization_id: organizationId, ...(notificationBranchId ? { branch_id: notificationBranchId } : {}), entity_id: published.id }, dedupeKey: `announcement:${published.id}:published` });
  return published;
}

export async function cancelAnnouncement(organizationId: string, branchId: string, id: string, actorUserId: string) {
  const result = await prisma.announcement.updateMany({ where: { id, organization_id: organizationId, OR: [{ branch_id: branchId }, { branch_id: null }], status: { in: ['DRAFT', 'SCHEDULED', 'PUBLISHED'] } }, data: { status: 'CANCELLED', updated_by: actorUserId } });
  if (result.count !== 1) throw new NotFoundError('Announcement');
  await prisma.auditLog.create({ data: { id: ulid(), organization_id: organizationId, branch_id: branchId, actor_id: actorUserId, action: 'CANCEL', target_type: 'Announcement', target_id: id, after_state: { status: 'CANCELLED' } } });
}

export async function publishDueAnnouncements(now = new Date()) {
  const due = await prisma.announcement.findMany({ where: { status: 'SCHEDULED', publish_at: { lte: now } }, select: { id: true, organization_id: true, branch_id: true, created_by: true }, take: 200, orderBy: { publish_at: 'asc' } });
  let published = 0;
  for (const announcement of due) {
    try { await publishAnnouncement(announcement.organization_id, announcement.branch_id ?? '', announcement.id, announcement.created_by ?? undefined); published += 1; } catch { /* another coordinator may have published it */ }
  }
  return { scanned: due.length, published };
}

export async function expireAnnouncements(now = new Date()) {
  const result = await prisma.announcement.updateMany({
    where: { status: 'PUBLISHED', expires_at: { lte: now } },
    data: { status: 'EXPIRED', updated_at: now },
  });
  return { expired: result.count };
}
