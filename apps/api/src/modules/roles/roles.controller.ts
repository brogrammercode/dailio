import { Request, Response, NextFunction } from 'express';

import { ForbiddenError, ValidationError } from '../../lib/errors';

import { CreateRoleSchema, UpdateRoleSchema } from './roles.schema';
import * as rolesService from './roles.service';

export async function listRoles(req: Request, res: Response, next: NextFunction) {
  try {
    const organization_id = req.query.organization_id as string;
    if (!organization_id) {
      throw new ValidationError('organization_id query parameter is required');
    }

    if (organization_id !== req.organization!.id)
      throw new ForbiddenError('Organization scope is invalid');
    const roles = await rolesService.getRoles(organization_id, req.branch!.id);
    res.status(200).json({ roles });
  } catch (err) {
    next(err);
  }
}

export async function createRole(req: Request, res: Response, next: NextFunction) {
  try {
    const payload = CreateRoleSchema.parse(req.body);
    if (payload.organization_id !== req.organization!.id) {
      throw new ForbiddenError('Organization scope is invalid');
    }
    if (payload.branch_id && payload.branch_id !== req.branch!.id && !req.permissions?.has('ALL')) {
      throw new ForbiddenError('Role branch scope is invalid');
    }
    const role = await rolesService.createRole(payload, req.user!.id);
    res.status(201).json({ role });
  } catch (err) {
    next(err);
  }
}

export async function updateRole(req: Request, res: Response, next: NextFunction) {
  try {
    const role_id = req.params.role_id;
    const payload = UpdateRoleSchema.parse(req.body);

    const role = await rolesService.updateRole(
      role_id,
      payload,
      req.organization!.id,
      req.branch!.id,
      req.user!.id,
      req.permissions ?? new Set<string>(),
    );
    res.status(200).json({ role });
  } catch (err) {
    next(err);
  }
}
