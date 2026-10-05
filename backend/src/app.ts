import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import type { Logger } from 'pino';
import type { Environment } from './config/environment.js';
import { AppError } from './errors/app-error.js';
import { errorHandler, notFound } from './middleware/error-handler.js';
import { requestContext } from './middleware/request-context.js';
import { requestRateLimit } from './middleware/rate-limit.js';
import type { HealthRepository } from './modules/health/health.repository.js';
import { apiRoutes } from './routes/index.js';

export function createApp(
  environment: Environment,
  logger: Logger,
  repository: HealthRepository,
): Express {
  const app = express();
  app.disable('x-powered-by');
  app.set('query parser', 'simple');
  app.use(requestContext(logger));
  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        if (origin === undefined || environment.CORS_ORIGINS.includes(origin)) callback(null, true);
        else callback(new AppError('AUTHORIZATION_ERROR'));
      },
      credentials: false,
      exposedHeaders: ['X-Request-Id'],
      maxAge: 600,
    }),
  );
  app.use(requestRateLimit(environment.RATE_LIMIT_MAX));
  app.use(express.json({ limit: '100kb', strict: true, inflate: false }));
  app.use('/api/v1', apiRoutes(repository));
  app.use(notFound);
  app.use(errorHandler(logger));
  return app;
}
