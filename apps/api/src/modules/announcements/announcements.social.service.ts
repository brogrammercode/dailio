import type { AnnouncementReactionType } from '@prisma/client';
import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ConflictError, ForbiddenError, NotFoundError } from '../../lib/errors';
import { notify } from '../notifications/notifications.service';

import type {
  CreateAnnouncementCommentInput,
  SetAnnouncementReactionInput,
} from './announcements.schema';

function canManage(permissions: Set<string>) {
  return (
    permissions.has('ALL') ||
    permissions.has('ANNOUNCEMENT_CREATE') ||
    permissions.has('ANNOUNCEMENT_UPDATE')
  );
}

async function getAccessibleAnnouncement(
  organizationId: string,
  branchId: string,
  memberId: string,
  userId: string,
  announcementId: string,
  permissions: Set<string>,
) {
  const managed = canManage(permissions);
  const announcement = await prisma.announcement.findFirst({
    where: {
      id: announcementId,
      organization_id: organizationId,
      OR: [{ branch_id: branchId }, { branch_id: null }],
      ...(managed
        ? { status: { not: 'CANCELLED' } }
        : {
            status: 'PUBLISHED',
            AND: [
              { OR: [{ expires_at: null }, { expires_at: { gt: new Date() } }] },
              { recipients: { some: { member_id: memberId } } },
            ],
          }),
    },
    include: {
      actor: { select: { id: true, name: true, avatar_url: true } },
      _count: { select: { recipients: true, reactions: true, comments: true } },
    },
  });
  if (!announcement) throw new NotFoundError('Announcement');
  const myReaction = await prisma.announcementReaction.findUnique({
    where: { announcement_id_user_id: { announcement_id: announcementId, user_id: userId } },
    select: { reaction: true },
  });
  return { ...announcement, my_reaction: myReaction?.reaction ?? null };
}

export async function getAnnouncement(
  organizationId: string,
  branchId: string,
  memberId: string,
  userId: string,
  announcementId: string,
  permissions: Set<string>,
) {
  return getAccessibleAnnouncement(
    organizationId,
    branchId,
    memberId,
    userId,
    announcementId,
    permissions,
  );
}

export async function listComments(
  organizationId: string,
  branchId: string,
  memberId: string,
  userId: string,
  announcementId: string,
  permissions: Set<string>,
) {
  await getAccessibleAnnouncement(
    organizationId,
    branchId,
    memberId,
    userId,
    announcementId,
    permissions,
  );
  return prisma.announcementComment.findMany({
    where: { organization_id: organizationId, announcement_id: announcementId },
    include: { user: { select: { id: true, name: true, avatar_url: true } } },
    orderBy: { created_at: 'asc' },
  });
}

export async function setReaction(
  organizationId: string,
  branchId: string,
  memberId: string,
  userId: string,
  announcementId: string,
  input: SetAnnouncementReactionInput,
  permissions: Set<string>,
) {
  const announcement = await getAccessibleAnnouncement(
    organizationId,
    branchId,
    memberId,
    userId,
    announcementId,
    permissions,
  );
  const reaction = await prisma.announcementReaction.upsert({
    where: { announcement_id_user_id: { announcement_id: announcementId, user_id: userId } },
    create: {
      id: ulid(),
      organization_id: organizationId,
      branch_id: announcement.branch_id ?? branchId,
      announcement_id: announcementId,
      user_id: userId,
      reaction: input.reaction as AnnouncementReactionType,
    },
    update: { reaction: input.reaction as AnnouncementReactionType },
  });
  const actorId = announcement.actor?.id;
  if (actorId && actorId !== userId) {
    await notify({
      type: 'ANNOUNCEMENT_REACTED',
      organizationId,
      branchId: announcement.branch_id ?? branchId,
      actorUserId: userId,
      entityType: 'Announcement',
      entityId: announcementId,
      recipientUserIds: [actorId],
      title: 'New announcement reaction',
      body: 'Someone reacted to your announcement.',
      data: {
        organization_id: organizationId,
        branch_id: announcement.branch_id ?? branchId,
        entity_id: announcementId,
      },
      dedupeKey: `announcement:${announcementId}:reaction:${userId}`,
    }).catch(() => undefined);
  }
  return reaction;
}

export async function removeReaction(
  organizationId: string,
  branchId: string,
  memberId: string,
  userId: string,
  announcementId: string,
  permissions: Set<string>,
) {
  await getAccessibleAnnouncement(
    organizationId,
    branchId,
    memberId,
    userId,
    announcementId,
    permissions,
  );
  await prisma.announcementReaction.deleteMany({
    where: { organization_id: organizationId, announcement_id: announcementId, user_id: userId },
  });
}

export async function createComment(
  organizationId: string,
  branchId: string,
  memberId: string,
  userId: string,
  announcementId: string,
  input: CreateAnnouncementCommentInput,
  permissions: Set<string>,
  headerIdempotencyKey?: string,
) {
  const announcement = await getAccessibleAnnouncement(
    organizationId,
    branchId,
    memberId,
    userId,
    announcementId,
    permissions,
  );
  const idempotencyKey = input.idempotency_key ?? headerIdempotencyKey;
  if (idempotencyKey) {
    const existing = await prisma.announcementComment.findUnique({
      where: { idempotency_key: idempotencyKey },
    });
    if (existing) {
      if (existing.user_id !== userId || existing.announcement_id !== announcementId)
        throw new ConflictError('Idempotency key belongs to another comment');
      return existing;
    }
  }
  let parentUserId: string | null = null;
  if (input.reply_to_id) {
    const parent = await prisma.announcementComment.findFirst({
      where: {
        id: input.reply_to_id,
        organization_id: organizationId,
        announcement_id: announcementId,
        deleted_at: null,
      },
      select: { user_id: true },
    });
    if (!parent) throw new NotFoundError('Comment');
    parentUserId = parent.user_id;
  }
  const created = await prisma.$transaction(async (tx) => {
    const comment = await tx.announcementComment.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: announcement.branch_id ?? branchId,
        announcement_id: announcementId,
        user_id: userId,
        body: input.body,
        reply_to_id: input.reply_to_id,
        idempotency_key: idempotencyKey,
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: announcement.branch_id ?? branchId,
        actor_id: userId,
        action: 'CREATE',
        target_type: 'AnnouncementComment',
        target_id: comment.id,
        after_state: { announcement_id: announcementId, reply_to_id: input.reply_to_id ?? null },
      },
    });
    return comment;
  });
  const recipients = new Set<string>();
  if (parentUserId && parentUserId !== userId) recipients.add(parentUserId);
  if (announcement.actor?.id && announcement.actor.id !== userId)
    recipients.add(announcement.actor.id);
  if (recipients.size > 0) {
    await notify({
      type: parentUserId ? 'ANNOUNCEMENT_REPLY' : 'ANNOUNCEMENT_COMMENTED',
      organizationId,
      branchId: announcement.branch_id ?? branchId,
      actorUserId: userId,
      entityType: 'Announcement',
      entityId: announcementId,
      recipientUserIds: [...recipients],
      title: parentUserId ? 'New reply on an announcement' : 'New announcement comment',
      body: parentUserId
        ? 'Someone replied to a comment.'
        : 'Someone commented on your announcement.',
      data: {
        organization_id: organizationId,
        branch_id: announcement.branch_id ?? branchId,
        entity_id: announcementId,
      },
      dedupeKey: `announcement:${announcementId}:comment:${created.id}`,
    }).catch(() => undefined);
  }
  return created;
}

export async function deleteComment(
  organizationId: string,
  branchId: string,
  userId: string,
  commentId: string,
  permissions: Set<string>,
) {
  const comment = await prisma.announcementComment.findFirst({
    where: { id: commentId, organization_id: organizationId, deleted_at: null },
    select: { id: true, user_id: true },
  });
  if (!comment) throw new NotFoundError('Comment');
  if (
    comment.user_id !== userId &&
    !permissions.has('ALL') &&
    !permissions.has('ANNOUNCEMENT_DELETE')
  )
    throw new ForbiddenError('You cannot delete this comment');
  await prisma.announcementComment.update({
    where: { id: comment.id },
    data: { deleted_at: new Date(), body: '[deleted]' },
  });
}
