import { Router } from 'express';
import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { modelHealthController } from './model-health.controller.js';
import type { ModelHealthService } from './model-health.service.js';
export function modelHealthRoutes(
  environment: Environment,
  auth: AuthService,
  service: ModelHealthService,
): Router {
  const router = Router();
  router.get(
    '/admin/model-health',
    (_req, res, next) => {
      res.setHeader('Cache-Control', 'no-store');
      next();
    },
    requestRateLimit(environment.ANALYTICS_RATE_LIMIT_MAX),
    authenticate(auth),
    authorize('ADMIN'),
    validateRequest(
      z.strictObject({
        body: z.undefined(),
        params: z.strictObject({}),
        query: z.strictObject({}),
      }),
    ),
    modelHealthController(service),
  );
  return router;
}
