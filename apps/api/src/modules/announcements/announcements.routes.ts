import { Router, type Router as RouterType } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import {
  cancelAnnouncement,
  createAnnouncement,
  createAnnouncementComment,
  createAnnouncementMediaSignature,
  deleteAnnouncementComment,
  getAnnouncement,
  getAnnouncementMediaUrl,
  listAnnouncementComments,
  listAnnouncements,
  publishAnnouncement,
  removeAnnouncementReaction,
  setAnnouncementReaction,
  updateAnnouncement,
} from './announcements.controller';

const router: RouterType = Router();
router.get(
  '/:organization_id/announcements',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  listAnnouncements,
);
router.post(
  '/:organization_id/announcements',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_CREATE'),
  createAnnouncement,
);
router.patch(
  '/:organization_id/announcements/:announcement_id',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_UPDATE'),
  updateAnnouncement,
);
router.post(
  '/:organization_id/announcements/:announcement_id/publish',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_UPDATE'),
  publishAnnouncement,
);
router.post(
  '/:organization_id/announcements/:announcement_id/cancel',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_DELETE'),
  cancelAnnouncement,
);
router.post(
  '/:organization_id/announcements/media/upload-signature',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_CREATE'),
  createAnnouncementMediaSignature,
);
router.get(
  '/:organization_id/announcements/media-url',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  getAnnouncementMediaUrl,
);
router.get(
  '/:organization_id/announcements/:announcement_id',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  getAnnouncement,
);
router.get(
  '/:organization_id/announcements/:announcement_id/comments',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  listAnnouncementComments,
);
router.post(
  '/:organization_id/announcements/:announcement_id/comments',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  createAnnouncementComment,
);
router.delete(
  '/:organization_id/announcements/comments/:comment_id',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  deleteAnnouncementComment,
);
router.put(
  '/:organization_id/announcements/:announcement_id/reaction',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  setAnnouncementReaction,
);
router.delete(
  '/:organization_id/announcements/:announcement_id/reaction',
  authenticate,
  resolveTenantContext,
  requirePermission('ANNOUNCEMENT_READ'),
  removeAnnouncementReaction,
);
export default router;
