import { NextFunction, Request, Response } from 'express';

import { ForbiddenError, UnauthorizedError } from '../lib/errors';

export function requirePermission(permissionCode: string) {
  return (_req: Request, _res: Response, _next: NextFunction): void => {
    const req = _req;
    if (!req.user) {
      _next(new UnauthorizedError());
      return;
    }
    if (!req.permissions?.has(permissionCode) && !req.permissions?.has('ALL')) {
      _next(new ForbiddenError(`Permission required: ${permissionCode}`));
      return;
    }
    _next();
  };
}

export function requireAnyPermission(...permissionCodes: string[]) {
  return (_req: Request, _res: Response, _next: NextFunction): void => {
    const req = _req;
    if (!req.user) {
      _next(new UnauthorizedError());
      return;
    }
    const permissions = req.permissions ?? new Set<string>();
    if (permissions.has('ALL') || permissionCodes.some((code) => permissions.has(code))) {
      _next();
      return;
    }
    _next(
      new ForbiddenError(`One of these permissions is required: ${permissionCodes.join(', ')}`),
    );
  };
}
