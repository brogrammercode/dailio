import { NextFunction, Request, Response } from 'express';

import { ForbiddenError, NotFoundError, UnauthorizedError } from '../lib/errors';
import { prisma } from '../lib/prisma';
import { permissionsForMember } from '../modules/authorization/authorization.service';

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

    if (req.params.organization_id && req.params.organization_id !== organization_id) {
      throw new ForbiddenError('Organization route does not match the active organization');
    }
    if (req.params.branch_id && req.params.branch_id !== branch_id) {
      throw new ForbiddenError('Branch route does not match the active branch');
    }

    // Branch already owns the organization relation. Resolve both from one
    // query instead of paying two hosted-Postgres round trips on every scoped
    // request. The fallback organization read only supports isolated tests or
    // malformed legacy mocks; a real branch always has its organization.
    const branchWithOrganization = await prisma.branch.findUnique({
      where: { id: branch_id, organization_id },
      select: {
        id: true,
        organization_id: true,
        status: true,
        timezone: true,
        week_start: true,
        organization: { select: { id: true, status: true } },
      },
    });
    const branch = branchWithOrganization;
    let organization = branchWithOrganization?.organization;
    if (!organization && branch) {
      const legacyOrganization = await prisma.organization.findUnique({
        where: { id: organization_id },
      });
      if (legacyOrganization) {
        organization = legacyOrganization;
      }
    }
    if (!organization) throw new NotFoundError('Organization');
    if (!branch || branch.status === 'ARCHIVED') throw new NotFoundError('Branch');

    // Resolve the caller and their roles in one scoped query. This avoids a
    // second member read just to calculate permissions, which is significant
    // on hosted Postgres connections with non-trivial round-trip latency.
    const member = await prisma.member.findFirst({
      where: { organization_id, branch_id, user_id: req.user.id, status: 'ACTIVE' },
      include: {
        role: { select: { system_key: true, permissions: true } },
        role_assignments: {
          where: {
            organization_id,
            branch_id,
            effective_from: { lte: new Date() },
            OR: [{ effective_to: null }, { effective_to: { gt: new Date() } }],
          },
          orderBy: [{ priority: 'asc' }, { effective_from: 'desc' }, { id: 'asc' }],
          select: { role: { select: { system_key: true, permissions: true } } },
        },
      },
    });
    if (!member) throw new ForbiddenError('No active membership in this branch');
    const permissions = permissionsForMember(member);

    req.organization = organization as unknown as NonNullable<typeof req.organization>;
    req.branch = branch as unknown as NonNullable<typeof req.branch>;
    req.member = member;
    req.permissions = permissions;

    next();
  } catch (err) {
    next(err);
  }
}
