import compression from 'compression';
import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { env } from './config/env';
import { logger } from './config/logger';
import { docsRouter } from './docs/swagger';
import { errorHandler } from './middleware/errorHandler';
import { requestIdMiddleware } from './middleware/requestId';
import { defaultRateLimiter } from './middleware/rateLimiter';
import { apiRouter } from './routes';

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

  // HTTP logging (skip in test)
  if (env.NODE_ENV !== 'test') {
    app.use(
      morgan('combined', {
        stream: { write: (msg) => logger.http(msg.trim()) },
      }),
    );
  }

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

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
