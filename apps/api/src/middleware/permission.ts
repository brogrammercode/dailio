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
