import { type RequestHandler, Router } from 'express';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import { createAuthController } from './auth.controller.js';
import type { AuthService } from './auth.service.js';
import { emptyPostRequest, loginRequest, meRequest, registerRequest } from './auth.validators.js';

// Non-simple custom header + JSON forces browser preflight, complementing exact
// Origin validation and SameSite=Strict. Native clients must send this header too.
const requireAuthRequest: RequestHandler = (request, _response, next) => {
  if (request.get('x-auth-request') !== '1') throw new AppError('AUTHORIZATION_ERROR');
  if (!request.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
  next();
};
export function authRoutes(environment: Environment, service: AuthService): Router {
  const router = Router();
  const controller = createAuthController(environment, service);
  const credentialLimit = requestRateLimit(environment.AUTH_RATE_LIMIT_MAX, 15 * 60000);
  const sessionLimit = requestRateLimit(30);
  router.use((_request, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    next();
  });
  router.post(
    '/register',
    credentialLimit,
    requireAuthRequest,
    validateRequest(registerRequest),
    controller.register,
  );
  router.post(
    '/login',
    credentialLimit,
    requireAuthRequest,
    validateRequest(loginRequest),
    controller.login,
  );
  router.post(
    '/refresh',
    sessionLimit,
    requireAuthRequest,
    validateRequest(emptyPostRequest),
    controller.refresh,
  );
  router.post(
    '/logout',
    sessionLimit,
    requireAuthRequest,
    validateRequest(emptyPostRequest),
    controller.logout,
  );
  router.get(
    '/me',
    validateRequest(meRequest),
    authenticate(service),
    authorize('FARMER', 'ADMIN'),
    controller.me,
  );
  return router;
}
