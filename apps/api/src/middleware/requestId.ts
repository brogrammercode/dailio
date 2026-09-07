import { NextFunction, Request, Response } from 'express';
import { ulid } from 'ulid';

export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  const id = (req.headers['x-request-id'] as string) || ulid();
  req.request_id = id;
  res.setHeader('X-Request-ID', id);
  next();
}
