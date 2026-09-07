import type { Request, Response } from 'express';

import { CreateJoinRequestSchema, JoinRequestActionSchema } from './admissions.schema';
import * as admissionsService from './admissions.service';

export async function joinLocation(req: Request, res: Response) {
  const { location_id } = req.params;
  const data = CreateJoinRequestSchema.parse(req).body;
  const result = await admissionsService.submitJoinRequest(req.user!.id, location_id, data);
  res.json(result);
}

export async function getJoinRequests(req: Request, res: Response) {
  const result = await admissionsService.listPendingRequests(
    req.organization!.id,
    req.location!.id,
  );
  res.json(result);
}

export async function approveRequest(req: Request, res: Response) {
  const { request_id } = req.params;
  const data = JoinRequestActionSchema.parse(req).body;
  const result = await admissionsService.approveJoinRequest(
    req.user!.id,
    req.organization!.id,
    req.location!.id,
    request_id,
    data,
  );
  res.json(result);
}

export async function rejectRequest(req: Request, res: Response) {
  const { request_id } = req.params;
  const data = JoinRequestActionSchema.parse(req).body;
  const result = await admissionsService.rejectJoinRequest(
    req.user!.id,
    req.organization!.id,
    req.location!.id,
    request_id,
    data,
  );
  res.json(result);
}
