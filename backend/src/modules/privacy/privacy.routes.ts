import { Router, type RequestHandler } from 'express';
import { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import { privacyController as controller } from './privacy.controller.js';
import type { AuthService } from '../auth/auth.service.js';
import type { PrivacyService } from './privacy.service.js';

export function privacyRoutes(auth: AuthService, service: PrivacyService) {
  const router = Router();
  const guard = [authenticate(auth), authorize('FARMER'), requestRateLimit(10)];
  const input = validateRequest(
    z.strictObject({ body: z.undefined(), params: z.strictObject({}), query: z.strictObject({}) }),
  );
  const noStore: RequestHandler = (_req, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    next();
  };
  router.get('/profile/data-deletion', noStore, ...guard, input, controller(service, 'read'));
  router.post(
    '/profile/data-deletion',
    noStore,
    ...guard,
    (request, _response, next) => {
      if (request.get('x-auth-request') !== '1') throw new AppError('AUTHORIZATION_ERROR');
      next();
    },
    validateRequest(
      z.strictObject({
        body: z.strictObject({}),
        params: z.strictObject({}),
        query: z.strictObject({}),
      }),
    ),
    controller(service, 'request'),
  );
  return router;
}
