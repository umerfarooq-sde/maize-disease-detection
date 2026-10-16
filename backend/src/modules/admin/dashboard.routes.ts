import { Router } from 'express';
import { z } from 'zod';
import { withRequestSchema } from '../../validators/request.js';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { analyticsQuery } from '../analytics/analytics.types.js';
import type { AuthService } from '../auth/auth.service.js';
import { createDashboardController } from './dashboard.controller.js';
import type { DashboardService } from './dashboard.service.js';

export function dashboardRoutes(
  environment: Environment,
  auth: AuthService,
  service: DashboardService,
): Router {
  const router = Router();
  router.get(
    '/admin/dashboard',
    (_request, response, next) => {
      response.setHeader('Cache-Control', 'no-store');
      next();
    },
    requestRateLimit(environment.ANALYTICS_RATE_LIMIT_MAX),
    authenticate(auth),
    authorize('ADMIN'),
    withRequestSchema(z.object({ query: analyticsQuery }), (request, response, next) => {
      const parsed = analyticsQuery.safeParse(request.query);
      if (!parsed.success) throw new AppError('VALIDATION_ERROR');
      response.locals.validated = parsed.data;
      next();
    }),
    createDashboardController(service),
  );
  return router;
}
