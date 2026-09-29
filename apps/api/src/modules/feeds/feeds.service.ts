import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../lib/errors';
import { cloudinary, getUploadSignature } from '../../lib/cloudinary';
import { logger } from '../../config/logger';
import { findBranchRecipientUserIds, notify } from '../notifications/notifications.service';

import type {
  CreateFeedCommentInput,
  CreateFeedInput,
  CreateFeedPostInput,
  SetFeedReactionInput,
  UpdateFeedInput,
  UpdateFeedPostInput,
} from './feeds.schema';

export function createFeedMediaUploadSignature(
  organizationId: string,
  branchId: string,
  filename: string,
) {
  const safeName = filename.replace(/[^a-zA-Z0-9_-]/g, '-').slice(0, 80) || 'feed-media';
  const folder = `organizations/${organizationId}/branches/${branchId}/feeds`;
  const publicId = `${safeName}-${ulid()}`;
  return {
    ...getUploadSignature(folder, publicId, 'authenticated'),
    storage_key: `${folder}/${publicId}`,
  };
}

export function createFeedMediaDownloadUrl(
  organizationId: string,
  branchId: string,
  storageKey: string,
  requestedFormat?: string,
) {
  const parts = storageKey.split('/');
  const validPath =
    parts.length > 5 &&
    parts[0] === 'organizations' &&
    parts[1] === organizationId &&
    parts[2] === 'branches' &&
    parts[3] === branchId &&
    parts[4] === 'feeds' &&
    parts.slice(5).join('/').length > 0;
  if (!validPath) throw new ValidationError('Feed media scope is invalid');
  const extension =
    requestedFormat?.toLowerCase() ||
    (storageKey.includes('.') ? (storageKey.split('.').pop() ?? 'jpg') : 'jpg');
  return {
    url: cloudinary.utils.private_download_url(storageKey, extension, {
      resource_type: 'image',
      type: 'authenticated',
      expires_at: Math.floor(Date.now() / 1000) + 300,
      attachment: false,
    }),
  };
}

async function materializeFeedContent(
  organizationId: string,
  branchId: string,
  content: CreateFeedPostInput['content'],
) {
  const folder = `organizations/${organizationId}/branches/${branchId}/feeds`;
  return Promise.all(
    content.map(async (block) => {
      if (!block.media_base64 || (block.type !== 'image' && block.type !== 'slide')) {
        return block;
      }
      const filename = block.media_filename ?? block.alt ?? 'feed-image.jpg';
      const safeName = filename.replace(/[^a-zA-Z0-9_-]/g, '-').slice(0, 80) || 'feed-media';
      const publicId = `${safeName}-${ulid()}`;
      const source = block.media_base64.startsWith('data:')
        ? block.media_base64
        : `data:image/jpeg;base64,${block.media_base64}`;
      const uploaded = await cloudinary.uploader.upload(source, {
        folder,
        public_id: publicId,
        type: 'authenticated',
        resource_type: 'image',
      });
      const stored = { ...block };
      delete stored.media_base64;
      delete stored.media_filename;
      return {
        ...stored,
        storage_key: `${folder}/${publicId}`,
        format: uploaded.format,
        alt: block.alt ?? filename,
      };
    }),
  );
}

function canManage(permissions: Set<string>) {
  return (
    permissions.has('ALL') ||
    permissions.has('FEED_CREATE') ||
    permissions.has('FEED_UPDATE') ||
    permissions.has('FEED_MODERATE')
  );
}

function canModerate(permissions: Set<string>) {
  return permissions.has('ALL') || permissions.has('FEED_MODERATE');
}

async function activeMembersInBranch(
  organizationId: string,
  branchId: string,
  memberIds: string[],
) {
  const members = await prisma.member.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      status: 'ACTIVE',
      id: { in: memberIds },
    },
    select: { id: true, user_id: true },
  });
  if (members.length !== new Set(memberIds).size)
    throw new ValidationError('One or more feed participants are outside this branch');
  return members;
}

async function feedUserIds(feedId: string, excludeUserId?: string) {
  const participants = await prisma.feedParticipant.findMany({
    where: { feed_id: feedId, removed_at: null },
    select: { member: { select: { user_id: true } } },
  });
  return participants.map((item) => item.member.user_id).filter((id) => id !== excludeUserId);
}

async function safeFeedUserIds(feedId: string, excludeUserId?: string) {
  try {
    return await feedUserIds(feedId, excludeUserId);
  } catch {
    return [];
  }
}

function notifyFeedUsers(
  type: string,
  organizationId: string,
  branchId: string,
  feedId: string,
  recipientUserIds: string[],
  title: string,
  body: string,
  actorUserId?: string,
  dedupeSuffix?: string,
) {
  if (recipientUserIds.length === 0) return;
  void notify({
    type,
    organizationId,
    branchId,
    entityType: 'Feed',
    entityId: feedId,
    recipientUserIds,
    actorUserId,
    title,
    body,
    dedupeKey: `${type}:${feedId}:${dedupeSuffix ?? feedId}`,
    data: { feed_id: feedId },
  }).catch((error: unknown) => {
    logger.warn('Feed notification delivery failed', {
      event_type: type,
      feed_id: feedId,
      recipient_count: recipientUserIds.length,
      error: error instanceof Error ? error.message : String(error),
    });
  });
}

async function getFeed(
  organizationId: string,
  branchId: string,
  feedId: string,
  memberId: string,
  permissions: Set<string>,
) {
  const managed = canManage(permissions);
  const feed = await prisma.feed.findFirst({
    where: {
      id: feedId,
      organization_id: organizationId,
      branch_id: branchId,
      ...(managed ? {} : { participants: { some: { member_id: memberId, removed_at: null } } }),
    },
    include: {
      created_by: { select: { id: true, name: true, avatar_url: true } },
      participants: {
        where: { removed_at: null },
        include: {
          member: { include: { user: { select: { id: true, name: true, avatar_url: true } } } },
        },
      },
      _count: { select: { participants: true, posts: true } },
    },
  });
  if (!feed) throw new NotFoundError('Feed');
  if (feed.disbanded && !managed) throw new ConflictError('This feed has been disbanded');
  return feed;
}

export async function listFeeds(
  organizationId: string,
  branchId: string,
  memberId: string,
  permissions: Set<string>,
) {
  const managed = canManage(permissions);
  const feeds = await prisma.feed.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      ...(managed ? {} : { participants: { some: { member_id: memberId, removed_at: null } } }),
    },
    include: {
      created_by: { select: { id: true, name: true, avatar_url: true } },
      participants: { where: { removed_at: null }, select: { member_id: true } },
      _count: { select: { participants: true, posts: true } },
    },
    orderBy: { created_at: 'asc' },
  });
  return feeds
    .filter((feed) => managed || !feed.disbanded)
    .map((feed) => ({
      id: feed.id,
      name: feed.name,
      participants_can_post: feed.participants_can_post,
      post_timeout: feed.post_timeout,
      disbanded: feed.disbanded,
      report_threshold: feed.report_threshold,
      created_at: feed.created_at,
      updated_at: feed.updated_at,
      created_by: feed.created_by,
      participant_count: feed._count.participants,
      post_count: feed._count.posts,
      is_participant: feed.participants.some((item) => item.member_id === memberId),
    }));
}

export async function createFeed(
  organizationId: string,
  branchId: string,
  creatorMemberId: string,
  actorUserId: string,
  input: CreateFeedInput,
) {
  const ids = [...new Set([creatorMemberId, ...input.member_ids])];
  const members = await activeMembersInBranch(organizationId, branchId, ids);
  const feed = await prisma.$transaction(async (tx) => {
    const created = await tx.feed.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        name: input.name,
        participants_can_post: input.participants_can_post,
        post_timeout: input.post_timeout,
        report_threshold: input.report_threshold,
        created_by_user_id: actorUserId,
        participants: {
          create: members.map((member) => ({
            id: ulid(),
            member_id: member.id,
            added_by_user_id: actorUserId,
          })),
        },
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'CREATE',
        target_type: 'Feed',
        target_id: created.id,
        after_state: { name: created.name, participant_count: members.length },
      },
    });
    return created;
  });
  notifyFeedUsers(
    'FEED_CREATED',
    organizationId,
    branchId,
    feed.id,
    members.map((member) => member.user_id),
    `New feed: ${feed.name}`,
    'You have been added to a new feed.',
    actorUserId,
    feed.id,
  );
  return feed;
}

export async function updateFeed(
  organizationId: string,
  branchId: string,
  feedId: string,
  actorUserId: string,
  input: UpdateFeedInput,
) {
  await getFeed(organizationId, branchId, feedId, '', new Set(['FEED_UPDATE']));
  return prisma.$transaction(async (tx) => {
    const feed = await tx.feed.update({ where: { id: feedId }, data: input });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'UPDATE',
        target_type: 'Feed',
        target_id: feedId,
        after_state: input,
      },
    });
    return feed;
  });
}

export async function addParticipant(
  organizationId: string,
  branchId: string,
  feedId: string,
  actorUserId: string,
  memberId: string,
) {
  const feed = await getFeed(organizationId, branchId, feedId, '', new Set(['FEED_UPDATE']));
  const [member] = await activeMembersInBranch(organizationId, branchId, [memberId]);
  const participant = await prisma.$transaction(async (tx) => {
    const result = await tx.feedParticipant.upsert({
      where: { feed_id_member_id: { feed_id: feed.id, member_id: member.id } },
      create: { id: ulid(), feed_id: feed.id, member_id: member.id, added_by_user_id: actorUserId },
      update: { removed_at: null, added_by_user_id: actorUserId },
      include: { member: { select: { user_id: true } } },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'ASSIGN',
        target_type: 'FeedParticipant',
        target_id: `${feedId}:${member.id}`,
      },
    });
    return result;
  });
  notifyFeedUsers(
    'FEED_PARTICIPANT_ADDED',
    organizationId,
    branchId,
    feed.id,
    [participant.member.user_id],
    `Added to ${feed.name}`,
    'You can now view this feed in Dailio.',
    actorUserId,
    member.id,
  );
  return participant;
}

export async function removeParticipant(
  organizationId: string,
  branchId: string,
  feedId: string,
  memberId: string,
  actorUserId: string,
) {
  const feed = await getFeed(organizationId, branchId, feedId, '', new Set(['FEED_UPDATE']));
  const target = await prisma.member.findFirst({
    where: { id: memberId, organization_id: organizationId, branch_id: branchId },
    select: { user_id: true },
  });
  if (!target) throw new NotFoundError('Feed participant');
  if (target?.user_id === feed.created_by_user_id)
    throw new ConflictError('The feed creator must remain a participant');
  await prisma.$transaction(async (tx) => {
    await tx.feedParticipant.updateMany({
      where: { feed_id: feedId, member_id: memberId, removed_at: null },
      data: { removed_at: new Date() },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'UNASSIGN',
        target_type: 'FeedParticipant',
        target_id: `${feedId}:${memberId}`,
      },
    });
  });
}

export async function disbandFeed(
  organizationId: string,
  branchId: string,
  feedId: string,
  actorUserId: string,
) {
  const feed = await getFeed(organizationId, branchId, feedId, '', new Set(['FEED_UPDATE']));
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.feed.update({ where: { id: feed.id }, data: { disbanded: true } });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'ARCHIVE',
        target_type: 'Feed',
        target_id: feed.id,
        after_state: { disbanded: true },
      },
    });
    return result;
  });
  notifyFeedUsers(
    'FEED_DISBANDED',
    organizationId,
    branchId,
    feed.id,
    await safeFeedUserIds(feed.id, actorUserId),
    `${feed.name} was closed`,
    'This feed is no longer active.',
    actorUserId,
    feed.id,
  );
  return updated;
}

export async function listPosts(
  organizationId: string,
  branchId: string,
  feedId: string,
  memberId: string,
  permissions: Set<string>,
) {
  const feed = await getFeed(organizationId, branchId, feedId, memberId, permissions);
  const managed = canModerate(permissions);
  const posts = await prisma.feedPost.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      feed_id: feed.id,
      ...(managed
        ? {}
        : { status: 'ACTIVE', OR: [{ expires_at: null }, { expires_at: { gt: new Date() } }] }),
    },
    include: {
      member: {
        include: {
          user: { select: { id: true, name: true, avatar_url: true } },
          role: { select: { name: true } },
        },
      },
      read_by: { where: { member_id: memberId }, select: { read_at: true } },
      reactions: { where: { member_id: memberId }, select: { reaction: true } },
      _count: { select: { reactions: true, comments: true, reports: true } },
    },
    orderBy: { created_at: 'desc' },
  });
  return posts.map((post) => ({
    ...post,
    my_reaction: post.reactions[0]?.reaction ?? null,
    is_read: post.read_by.length > 0,
  }));
}

export async function getPost(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  permissions: Set<string>,
) {
  await getFeed(organizationId, branchId, feedId, memberId, permissions);
  const post = await prisma.feedPost.findFirst({
    where: { id: postId, feed_id: feedId, organization_id: organizationId, branch_id: branchId },
    include: {
      feed: true,
      member: {
        include: {
          user: { select: { id: true, name: true, avatar_url: true } },
          role: { select: { name: true } },
        },
      },
      reactions: { where: { member_id: memberId }, select: { reaction: true } },
      _count: { select: { reactions: true, comments: true, reports: true } },
    },
  });
  if (!post) throw new NotFoundError('Feed post');
  if (
    !canModerate(permissions) &&
    (post.status === 'HIDDEN' || (post.expires_at && post.expires_at <= new Date()))
  )
    throw new NotFoundError('Feed post');
  return {
    ...post,
    my_reaction: post.reactions[0]?.reaction ?? null,
  };
}

export async function createPost(
  organizationId: string,
  branchId: string,
  feedId: string,
  memberId: string,
  actorUserId: string,
  input: CreateFeedPostInput,
  permissions: Set<string>,
) {
  const feed = await getFeed(organizationId, branchId, feedId, memberId, permissions);
  if (!feed.participants_can_post && !canModerate(permissions))
    throw new ForbiddenError('Only feed managers can post in this feed');
  if (input.idempotency_key) {
    const existing = await prisma.feedPost.findUnique({
      where: { idempotency_key: input.idempotency_key },
    });
    if (existing) return existing;
  }
  const materializedContent = await materializeFeedContent(organizationId, branchId, input.content);
  const created = await prisma.$transaction(async (tx) => {
    const post = await tx.feedPost.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        feed_id: feedId,
        title: input.title,
        body: input.body,
        content: materializedContent,
        member_id: memberId,
        idempotency_key: input.idempotency_key,
        expires_at: feed.post_timeout ? new Date(Date.now() + feed.post_timeout * 60_000) : null,
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'CREATE',
        target_type: 'FeedPost',
        target_id: post.id,
        after_state: { feed_id: feedId, title: post.title },
      },
    });
    return post;
  });
  notifyFeedUsers(
    'FEED_POSTED',
    organizationId,
    branchId,
    feedId,
    await safeFeedUserIds(feedId, actorUserId),
    `${feed.name}: ${created.title}`,
    created.body.slice(0, 180),
    actorUserId,
    created.id,
  );
  return created;
}

export async function updatePost(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  actorUserId: string,
  input: UpdateFeedPostInput,
  permissions: Set<string>,
) {
  const post = await getPost(organizationId, branchId, feedId, postId, memberId, permissions);
  const isAuthor = post.member.user_id === actorUserId;
  if (!isAuthor && !canModerate(permissions) && !permissions.has('FEED_UPDATE')) {
    throw new ForbiddenError('You cannot edit this feed post');
  }
  const materializedContent =
    input.content === undefined
      ? undefined
      : await materializeFeedContent(organizationId, branchId, input.content);
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.feedPost.update({
      where: { id: postId },
      data: {
        ...(input.title === undefined ? {} : { title: input.title }),
        ...(input.body === undefined ? {} : { body: input.body }),
        ...(materializedContent === undefined ? {} : { content: materializedContent }),
      },
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorUserId,
        action: 'UPDATE',
        target_type: 'FeedPost',
        target_id: postId,
        after_state: { feed_id: feedId, title: result.title },
      },
    });
    return result;
  });
  return updated;
}

export async function markPostRead(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  permissions: Set<string>,
) {
  await getPost(organizationId, branchId, feedId, postId, memberId, permissions);
  return prisma.feedPostRead.upsert({
    where: { feed_post_id_member_id: { feed_post_id: postId, member_id: memberId } },
    create: { id: ulid(), feed_post_id: postId, member_id: memberId },
    update: { read_at: new Date() },
  });
}

export async function setReaction(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  actorUserId: string,
  input: SetFeedReactionInput,
  permissions: Set<string>,
) {
  const post = await getPost(organizationId, branchId, feedId, postId, memberId, permissions);
  const reaction = await prisma.feedReaction.upsert({
    where: { feed_post_id_member_id: { feed_post_id: postId, member_id: memberId } },
    create: {
      id: ulid(),
      organization_id: organizationId,
      branch_id: branchId,
      feed_post_id: postId,
      member_id: memberId,
      reaction: input.reaction,
    },
    update: { reaction: input.reaction },
  });
  if (post.member.user_id !== actorUserId)
    notifyFeedUsers(
      'FEED_REACTED',
      organizationId,
      branchId,
      feedId,
      [post.member.user_id],
      'New feed reaction',
      'Someone reacted to your feed post.',
      actorUserId,
      `${postId}:${memberId}`,
    );
  return reaction;
}

export async function removeReaction(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  permissions: Set<string>,
) {
  await getPost(organizationId, branchId, feedId, postId, memberId, permissions);
  await prisma.feedReaction.deleteMany({
    where: {
      feed_post_id: postId,
      member_id: memberId,
      organization_id: organizationId,
      branch_id: branchId,
    },
  });
}

export async function listComments(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  permissions: Set<string>,
) {
  await getPost(organizationId, branchId, feedId, postId, memberId, permissions);
  return prisma.feedComment.findMany({
    where: {
      organization_id: organizationId,
      branch_id: branchId,
      feed_post_id: postId,
      deleted_at: null,
    },
    include: {
      member: { include: { user: { select: { id: true, name: true, avatar_url: true } } } },
    },
    orderBy: { created_at: 'asc' },
  });
}

export async function createComment(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  actorUserId: string,
  input: CreateFeedCommentInput,
  permissions: Set<string>,
) {
  const post = await getPost(organizationId, branchId, feedId, postId, memberId, permissions);
  if (input.idempotency_key) {
    const existing = await prisma.feedComment.findUnique({
      where: { idempotency_key: input.idempotency_key },
    });
    if (existing) return existing;
  }
  if (input.reply_to_id) {
    const parent = await prisma.feedComment.findFirst({
      where: { id: input.reply_to_id, feed_post_id: postId, deleted_at: null },
    });
    if (!parent) throw new ValidationError('Reply target is not part of this post');
  }
  const comment = await prisma.feedComment.create({
    data: {
      id: ulid(),
      organization_id: organizationId,
      branch_id: branchId,
      feed_post_id: postId,
      member_id: memberId,
      body: input.body,
      reply_to_id: input.reply_to_id,
      idempotency_key: input.idempotency_key,
    },
  });
  const recipients = new Set<string>();
  if (post.member.user_id !== actorUserId) recipients.add(post.member.user_id);
  if (input.reply_to_id) {
    try {
      const parent = await prisma.feedComment.findUnique({
        where: { id: input.reply_to_id },
        include: { member: { select: { user_id: true } } },
      });
      if (parent && parent.member.user_id !== actorUserId) recipients.add(parent.member.user_id);
    } catch {
      // The comment is already committed; delivery must remain best effort.
    }
  }
  notifyFeedUsers(
    'FEED_COMMENTED',
    organizationId,
    branchId,
    feedId,
    [...recipients],
    'New feed comment',
    input.body.slice(0, 180),
    actorUserId,
    comment.id,
  );
  return comment;
}

export async function deleteComment(
  organizationId: string,
  branchId: string,
  commentId: string,
  actorUserId: string,
  permissions: Set<string>,
) {
  const comment = await prisma.feedComment.findFirst({
    where: {
      id: commentId,
      organization_id: organizationId,
      branch_id: branchId,
      deleted_at: null,
    },
    include: { member: true },
  });
  if (!comment) throw new NotFoundError('Feed comment');
  if (comment.member.user_id !== actorUserId && !canModerate(permissions))
    throw new ForbiddenError();
  await prisma.feedComment.update({
    where: { id: commentId },
    data: { deleted_at: new Date(), body: '[deleted]' },
  });
}

export async function reportPost(
  organizationId: string,
  branchId: string,
  feedId: string,
  postId: string,
  memberId: string,
  actorUserId: string,
  reason: string,
  permissions: Set<string>,
) {
  const post = await getPost(organizationId, branchId, feedId, postId, memberId, permissions);
  const result = await prisma.$transaction(async (tx) => {
    const report = await tx.feedReport.upsert({
      where: {
        feed_post_id_reporter_member_id: { feed_post_id: postId, reporter_member_id: memberId },
      },
      create: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        feed_post_id: postId,
        reporter_member_id: memberId,
        reason,
      },
      update: {},
    });
    const openCount = await tx.feedReport.count({
      where: { feed_post_id: postId, status: 'OPEN' },
    });
    const hidden = openCount >= post.feed.report_threshold;
    if (hidden) await tx.feedPost.update({ where: { id: postId }, data: { status: 'HIDDEN' } });
    return { report, hidden };
  });
  let moderators: string[] = [];
  try {
    moderators = await findBranchRecipientUserIds(organizationId, branchId, 'FEED_MODERATE');
  } catch {
    // A committed report must not become a 500 when notification fan-out is unavailable.
  }
  notifyFeedUsers(
    'FEED_REPORTED',
    organizationId,
    branchId,
    feedId,
    [...new Set([post.feed.created_by_user_id, ...moderators])],
    'Feed post reported',
    'A feed post needs review.',
    actorUserId,
    `${postId}:${memberId}`,
  );
  return result;
}
