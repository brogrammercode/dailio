import { Router, type Router as RouterType } from 'express';

import { authenticate } from '../../middleware/auth';
import { requirePermission } from '../../middleware/permission';
import { resolveTenantContext } from '../../middleware/tenant';

import {
  addParticipant,
  createComment,
  createFeed,
  createFeedMediaSignature,
  createPost,
  deletePost,
  deleteComment,
  disbandFeed,
  getPost,
  getFeedMediaUrl,
  listComments,
  listFeeds,
  listPosts,
  markPostRead,
  removeParticipant,
  removeReaction,
  reportPost,
  setReaction,
  updateFeed,
  updatePost,
} from './feeds.controller';

const router: RouterType = Router();
const secured = [authenticate, resolveTenantContext];

router.get('/:organization_id/feeds', ...secured, requirePermission('FEED_READ'), listFeeds);
router.post('/:organization_id/feeds', ...secured, requirePermission('FEED_CREATE'), createFeed);
router.patch(
  '/:organization_id/feeds/:feed_id',
  ...secured,
  requirePermission('FEED_UPDATE'),
  updateFeed,
);
router.post(
  '/:organization_id/feeds/:feed_id/disband',
  ...secured,
  requirePermission('FEED_DISBAND'),
  disbandFeed,
);
router.post(
  '/:organization_id/feeds/:feed_id/participants',
  ...secured,
  requirePermission('FEED_PARTICIPANT_MANAGE'),
  addParticipant,
);
router.delete(
  '/:organization_id/feeds/:feed_id/participants/:member_id',
  ...secured,
  requirePermission('FEED_PARTICIPANT_MANAGE'),
  removeParticipant,
);
router.get(
  '/:organization_id/feeds/:feed_id/posts',
  ...secured,
  requirePermission('FEED_READ'),
  listPosts,
);
router.post(
  '/:organization_id/feeds/media/upload-signature',
  ...secured,
  requirePermission('FEED_POST'),
  createFeedMediaSignature,
);
router.get(
  '/:organization_id/feeds/media-url',
  ...secured,
  requirePermission('FEED_READ'),
  getFeedMediaUrl,
);
router.post(
  '/:organization_id/feeds/:feed_id/posts',
  ...secured,
  requirePermission('FEED_POST'),
  createPost,
);
router.get(
  '/:organization_id/feeds/:feed_id/posts/:post_id',
  ...secured,
  requirePermission('FEED_READ'),
  getPost,
);
router.patch(
  '/:organization_id/feeds/:feed_id/posts/:post_id',
  ...secured,
  requirePermission('FEED_POST'),
  updatePost,
);
router.delete(
  '/:organization_id/feeds/:feed_id/posts/:post_id',
  ...secured,
  requirePermission('FEED_READ'),
  deletePost,
);
router.post(
  '/:organization_id/feeds/:feed_id/posts/:post_id/read',
  ...secured,
  requirePermission('FEED_READ'),
  markPostRead,
);
router.put(
  '/:organization_id/feeds/:feed_id/posts/:post_id/reaction',
  ...secured,
  requirePermission('FEED_REACT'),
  setReaction,
);
router.delete(
  '/:organization_id/feeds/:feed_id/posts/:post_id/reaction',
  ...secured,
  requirePermission('FEED_REACT'),
  removeReaction,
);
router.get(
  '/:organization_id/feeds/:feed_id/posts/:post_id/comments',
  ...secured,
  requirePermission('FEED_COMMENT'),
  listComments,
);
router.post(
  '/:organization_id/feeds/:feed_id/posts/:post_id/comments',
  ...secured,
  requirePermission('FEED_COMMENT'),
  createComment,
);
router.delete(
  '/:organization_id/feeds/comments/:comment_id',
  ...secured,
  requirePermission('FEED_COMMENT'),
  deleteComment,
);
router.post(
  '/:organization_id/feeds/:feed_id/posts/:post_id/report',
  ...secured,
  requirePermission('FEED_REPORT'),
  reportPost,
);

export default router;
