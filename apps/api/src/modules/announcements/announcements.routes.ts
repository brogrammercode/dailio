import { Router, type Router as RouterType } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requirePermission } from '../../middleware/permission';

import { cancelAnnouncement, createAnnouncement, listAnnouncements, publishAnnouncement, updateAnnouncement } from './announcements.controller';

const router: RouterType = Router();
router.get('/:organization_id/announcements', authenticate, resolveTenantContext, requirePermission('ANNOUNCEMENT_READ'), listAnnouncements);
router.post('/:organization_id/announcements', authenticate, resolveTenantContext, requirePermission('ANNOUNCEMENT_CREATE'), createAnnouncement);
router.patch('/:organization_id/announcements/:announcement_id', authenticate, resolveTenantContext, requirePermission('ANNOUNCEMENT_UPDATE'), updateAnnouncement);
router.post('/:organization_id/announcements/:announcement_id/publish', authenticate, resolveTenantContext, requirePermission('ANNOUNCEMENT_UPDATE'), publishAnnouncement);
router.post('/:organization_id/announcements/:announcement_id/cancel', authenticate, resolveTenantContext, requirePermission('ANNOUNCEMENT_DELETE'), cancelAnnouncement);
export default router;
