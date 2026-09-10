import { NextFunction, Request, Response } from 'express';

import { ForbiddenError, NotFoundError, UnauthorizedError } from '../lib/errors';
import { prisma } from '../lib/prisma';
import {
  getMemberForUser,
  resolveEffectivePermissions,
} from '../modules/authorization/authorization.service';

/**
 * Resolves and validates the organization + branch context from request headers.
 * Must run after uthenticate.
 * Headers: X-Organization-Id, X-Branch-Id
 */
export async function resolveTenantContext(
  req: Request,
  _res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    if (!req.user) throw new UnauthorizedError();

    const organization_id = req.headers['x-organization-id'] as string;
    const branch_id = (req.headers['x-branch-id'] || req.headers['x-location-id']) as string; // fallback to location for now

    if (!organization_id || !branch_id) {
      throw new ForbiddenError('X-Organization-Id and X-Branch-Id headers are required');
    }

    const organization = await prisma.organization.findUnique({ where: { id: organization_id } });
    if (!organization || organization.status === 'ARCHIVED') throw new NotFoundError('Organization');

    const branch = await prisma.branch.findUnique({ where: { id: branch_id, organization_id } });
    if (!branch) throw new NotFoundError('Branch');

    const member = await getMemberForUser(req.user.id, organization_id, branch_id);
    if (!member) throw new ForbiddenError('No active membership in this branch');

    const permissions = await resolveEffectivePermissions(req.user.id, organization_id, branch_id);

    req.organization = organization;
    req.branch = branch;
    req.member = member;
    req.permissions = permissions;

    next();
  } catch (err) {
    next(err);
  }
}
