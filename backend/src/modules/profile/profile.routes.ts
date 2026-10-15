import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { profileController } from './profile.controller.js';
import type { ProfileService } from './profile.service.js';
import { profilePatch } from './profile.types.js';

export function profileRoutes(auth: AuthService, service: ProfileService): Router {
  const router = Router();
  router.all(
    '/profile',
    (_request, response, next) => {
      response.setHeader('Cache-Control', 'no-store');
      next();
    },
    requestRateLimit(60),
    authenticate(auth),
    authorize('FARMER'),
  );
  const request = (body: z.ZodType) =>
    validateRequest(
      z.strictObject({ body, params: z.strictObject({}), query: z.strictObject({}) }),
    );
  router.get('/profile', request(z.undefined()), profileController(service, 'read'));
  router.patch(
    '/profile',
    (req, _response, next) => {
      if (req.get('x-auth-request') !== '1') throw new AppError('AUTHORIZATION_ERROR');
      if (!req.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
      next();
    },
    request(profilePatch),
    profileController(service, 'patch'),
  );
  return router;
}
