import { type RequestHandler, Router } from 'express';
import type { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import type { AuthService } from '../auth/auth.service.js';
import { createAnalyticsController } from './analytics.controller.js';
import type { AnalyticsService } from './analytics.service.js';
import { activityQuery, analyticsQuery } from './analytics.types.js';

export function analyticsRoutes(
  environment: Environment,
  auth: AuthService,
  service: AnalyticsService,
): Router {
  const router = Router();
  const controller = createAnalyticsController(service);
  const validate =
    (schema: z.ZodType): RequestHandler =>
    (request, response, next) => {
      const result = schema.safeParse(request.query);
      if (!result.success) throw new AppError('VALIDATION_ERROR');
      response.locals.validated = result.data;
      next();
    };
  router.use(
    '/analytics',
    (_request, response, next) => {
      response.setHeader('Cache-Control', 'no-store');
      next();
    },
    requestRateLimit(environment.ANALYTICS_RATE_LIMIT_MAX),
    authenticate(auth),
    authorize('FARMER'),
  );
  router.get('/analytics/scans', validate(analyticsQuery), controller.summary);
  router.get('/analytics/scans/activity', validate(activityQuery), controller.activity);
  return router;
}
