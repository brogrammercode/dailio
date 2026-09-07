import { NextFunction, Request, Response } from 'express';

import { ForbiddenError, NotFoundError, UnauthorizedError } from '../lib/errors';
import { prisma } from '../lib/prisma';
import {
  getLocationMembershipForUser,
  resolveEffectivePermissions,
} from '../modules/authorization/authorization.service';

/**
 * Resolves and validates the organization + location context from request headers.
 * Must run after `authenticate`.
 * Headers: X-Organization-Id, X-Location-Id
 */
export async function resolveTenantContext(
  req: Request,
  _res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    if (!req.user) throw new UnauthorizedError();

    const organization_id = req.headers['x-organization-id'] as string;
    const location_id = req.headers['x-location-id'] as string;

    if (!organization_id || !location_id) {
      throw new ForbiddenError('X-Organization-Id and X-Location-Id headers are required');
    }

    const organization = await prisma.organization.findUnique({ where: { id: organization_id } });
    if (!organization || organization.status === 'ARCHIVED') throw new NotFoundError('Organization');

    const location = await prisma.location.findUnique({ where: { id: location_id, organization_id } });
    if (!location || location.status === 'ARCHIVED') throw new NotFoundError('Location');

    const location_membership = await getLocationMembershipForUser(req.user.id, organization_id, location_id);
    if (!location_membership) throw new ForbiddenError('No active membership in this location');

    const permissions = await resolveEffectivePermissions(req.user.id, organization_id, location_id);

    req.organization = organization;
    req.location = location;
    req.location_membership = location_membership;
    req.permissions = permissions;

    next();
  } catch (err) {
    next(err);
  }
}
