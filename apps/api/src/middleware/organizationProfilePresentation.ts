import type { Request, Response, NextFunction } from 'express';

import { presentOrganizationProfiles } from '../modules/members/profile-presentation.service';

/** Runs after a handler has authorized and loaded its scoped read model. */
export function organizationProfilePresentation(req: Request, res: Response, next: NextFunction) {
  const originalJson = res.json.bind(res);
  res.json = (body: unknown) => {
    const organizationId = req.organization?.id;
    if (req.method !== 'GET' || !organizationId || res.statusCode >= 400) return originalJson(body);
    void presentOrganizationProfiles(organizationId, body)
      .then((result) => {
        originalJson(result);
      })
      .catch(next);
    return res;
  };
  next();
}
