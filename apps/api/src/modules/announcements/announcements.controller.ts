import type { NextFunction, Request, Response } from 'express';

import { ForbiddenError } from '../../lib/errors';

import { CreateAnnouncementSchema, UpdateAnnouncementSchema } from './announcements.schema';
import * as announcementsService from './announcements.service';

function assertOrganization(req: Request) { if (req.params.organization_id !== req.organization!.id) throw new ForbiddenError('Organization scope is invalid'); }
export async function listAnnouncements(req: Request, res: Response, next: NextFunction) { try { assertOrganization(req); res.json({ data: await announcementsService.listAnnouncements(req.organization!.id, req.branch!.id) }); } catch (error) { next(error); } }
export async function createAnnouncement(req: Request, res: Response, next: NextFunction) { try { assertOrganization(req); const input = CreateAnnouncementSchema.parse(req.body); if (input.branch_id === null && !req.permissions?.has('ALL')) throw new ForbiddenError('Organization-wide announcements require organization scope'); res.status(201).json({ data: await announcementsService.createAnnouncement(req.organization!.id, { organizationId: req.organization!.id, branchId: req.branch!.id }, input, req.user!.id) }); } catch (error) { next(error); } }
export async function updateAnnouncement(req: Request, res: Response, next: NextFunction) { try { assertOrganization(req); const input = UpdateAnnouncementSchema.parse(req.body); if (input.branch_id === null && !req.permissions?.has('ALL')) throw new ForbiddenError('Organization-wide announcements require organization scope'); res.json({ data: await announcementsService.updateAnnouncement(req.organization!.id, req.branch!.id, req.params.announcement_id, input, req.user!.id) }); } catch (error) { next(error); } }
export async function publishAnnouncement(req: Request, res: Response, next: NextFunction) { try { assertOrganization(req); res.json({ data: await announcementsService.publishAnnouncement(req.organization!.id, req.branch!.id, req.params.announcement_id, req.user!.id) }); } catch (error) { next(error); } }
export async function cancelAnnouncement(req: Request, res: Response, next: NextFunction) { try { assertOrganization(req); await announcementsService.cancelAnnouncement(req.organization!.id, req.branch!.id, req.params.announcement_id, req.user!.id); res.status(204).send(); } catch (error) { next(error); } }
