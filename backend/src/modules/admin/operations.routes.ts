import { Router } from 'express';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { validateRequest } from '../../validators/request.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { z } from 'zod';
import { analyticsQuery } from '../analytics/analytics.types.js';
import type { AuthService } from '../auth/auth.service.js';
import type { OperationsService } from './operations.service.js';
import { operationsController } from './operations.controller.js';
export const operationsRequest = z.strictObject({
  body: z.undefined(),
  params: z.strictObject({}),
  query: analyticsQuery,
});
export function operationsRoutes(auth: AuthService, service: OperationsService): Router {
  const router = Router();
  router.get(
    '/admin/ai-operations',
    authenticate(auth),
    authorize('ADMIN'),
    requestRateLimit(30),
    validateRequest(operationsRequest),
    operationsController(service),
  );
  return router;
}
