import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';

import { logger } from '../config/logger';
import { AppError } from '../lib/errors';

export function safeErrorForLog(error: unknown) {
  if (error instanceof AppError) {
    return {
      type: error.name,
      code: error.code,
      status_code: error.statusCode,
    };
  }
  if (error instanceof Error) {
    const errorCode = 'code' in error && typeof error.code === 'string' ? error.code : undefined;
    return {
      type: error.name || 'Error',
      ...(errorCode ? { code: errorCode } : {}),
    };
  }
  return { type: typeof error };
}

export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction): void {
  const request_id = req.request_id;

  if (err instanceof ZodError) {
    logger.warn('Validation error', { details: err.flatten().fieldErrors, request_id });
    res.status(400).json({
      code: 'VALIDATION_ERROR',
      message: 'Request validation failed',
      details: err.flatten().fieldErrors,
      request_id,
    });
    return;
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error('Application error', { error: safeErrorForLog(err), request_id });
    } else {
      logger.warn('Client error', { code: err.code, message: err.message, request_id });
    }
    res.status(err.statusCode).json({
      code: err.code,
      message: err.message,
      ...(err.details ? { details: err.details } : {}),
      request_id,
    });
    return;
  }

  logger.error('Unhandled error', { error: safeErrorForLog(err), request_id });
  res.status(500).json({
    code: 'INTERNAL_SERVER_ERROR',
    message: 'An unexpected error occurred',
    request_id,
  });
}
