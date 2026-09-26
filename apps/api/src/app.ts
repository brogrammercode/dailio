import compression from 'compression';
import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';

import { env } from './config/env';
import { docsRouter } from './docs/swagger';
import { errorHandler } from './middleware/errorHandler';
import { requestIdMiddleware } from './middleware/requestId';
import { defaultRateLimiter } from './middleware/rateLimiter';
import { apiRouter } from './routes';
import { httpLogMiddleware, httpRequestBodyLogMiddleware } from './lib/httpLog';

export function createApp(): Express {
  const app = express();

  // Security
  app.use(helmet());
  app.use(
    cors({
      origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(','),
      credentials: true,
    }),
  );

  // Compression
  app.use(compression());

  // Request ID
  app.use(requestIdMiddleware);

  // HTTP logging keeps the mobile-compatible request format while response
  // lines stay compact and contain status/timing only.
  app.use(httpLogMiddleware);

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(httpRequestBodyLogMiddleware);

  // Rate limiting
  app.use('/api', defaultRateLimiter);

  // API routes
  app.use('/api/v1', apiRouter);

  // API docs
  app.use('/api/docs', docsRouter);

  // 404
  app.use((_req, res) => {
    res.status(404).json({ code: 'NOT_FOUND', message: 'Route not found' });
  });

  // Error handler — must be last
  app.use(errorHandler);

  return app;
}
