import type { NextFunction, Request, Response } from 'express';

import { ForbiddenError } from '../../lib/errors';

import {
  AnnouncementMediaSignatureSchema,
  AnnouncementMediaUrlSchema,
  CreateAnnouncementCommentSchema,
  CreateAnnouncementSchema,
  SetAnnouncementReactionSchema,
  UpdateAnnouncementSchema,
} from './announcements.schema';
import * as announcementsService from './announcements.service';
import * as socialService from './announcements.social.service';

function assertOrganization(req: Request) {
  if (req.params.organization_id !== req.organization!.id)
    throw new ForbiddenError('Organization scope is invalid');
}
export async function listAnnouncements(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await announcementsService.listAnnouncements(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.user!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function createAnnouncement(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = CreateAnnouncementSchema.parse(req.body);
    if (input.branch_id === null && !req.permissions?.has('ALL'))
      throw new ForbiddenError('Organization-wide announcements require organization scope');
    res.status(201).json({
      data: await announcementsService.createAnnouncement(
        req.organization!.id,
        { organizationId: req.organization!.id, branchId: req.branch!.id },
        input,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function updateAnnouncement(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = UpdateAnnouncementSchema.parse(req.body);
    if (input.branch_id === null && !req.permissions?.has('ALL'))
      throw new ForbiddenError('Organization-wide announcements require organization scope');
    res.json({
      data: await announcementsService.updateAnnouncement(
        req.organization!.id,
        req.branch!.id,
        req.params.announcement_id,
        input,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function publishAnnouncement(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await announcementsService.publishAnnouncement(
        req.organization!.id,
        req.branch!.id,
        req.params.announcement_id,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function cancelAnnouncement(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    await announcementsService.cancelAnnouncement(
      req.organization!.id,
      req.branch!.id,
      req.params.announcement_id,
      req.user!.id,
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}
export async function getAnnouncement(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await socialService.getAnnouncement(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.user!.id,
        req.params.announcement_id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function listAnnouncementComments(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await socialService.listComments(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.user!.id,
        req.params.announcement_id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function createAnnouncementComment(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = CreateAnnouncementCommentSchema.parse(req.body);
    res.status(201).json({
      data: await socialService.createComment(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.user!.id,
        req.params.announcement_id,
        input,
        req.permissions ?? new Set(),
        req.header('Idempotency-Key') ?? undefined,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function setAnnouncementReaction(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = SetAnnouncementReactionSchema.parse(req.body);
    res.json({
      data: await socialService.setReaction(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.user!.id,
        req.params.announcement_id,
        input,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function removeAnnouncementReaction(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    await socialService.removeReaction(
      req.organization!.id,
      req.branch!.id,
      req.member!.id,
      req.user!.id,
      req.params.announcement_id,
      req.permissions ?? new Set(),
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}
export async function deleteAnnouncementComment(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    await socialService.deleteComment(
      req.organization!.id,
      req.branch!.id,
      req.user!.id,
      req.params.comment_id,
      req.permissions ?? new Set(),
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}
export async function createAnnouncementMediaSignature(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    assertOrganization(req);
    const input = AnnouncementMediaSignatureSchema.parse(req.body);
    res.status(201).json({
      data: announcementsService.createAnnouncementMediaUploadSignature(
        req.organization!.id,
        req.branch!.id,
        input.filename,
      ),
    });
  } catch (error) {
    next(error);
  }
}
export async function getAnnouncementMediaUrl(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = AnnouncementMediaUrlSchema.parse(req.query);
    const announcement = await socialService.getAnnouncement(
      req.organization!.id,
      req.branch!.id,
      req.member!.id,
      req.user!.id,
      input.announcement_id,
      req.permissions ?? new Set(),
    );
    const content = Array.isArray(announcement.content) ? announcement.content : [];
    const ownsMedia = content.some(
      (block) =>
        block &&
        typeof block === 'object' &&
        (block as { storage_key?: unknown }).storage_key === input.storage_key,
    );
    if (!ownsMedia) throw new ForbiddenError('Announcement media scope is invalid');
    res.json({
      data: announcementsService.createAnnouncementMediaDownloadUrl(
        req.organization!.id,
        input.storage_key,
        input.format,
      ),
    });
  } catch (error) {
    next(error);
  }
}
