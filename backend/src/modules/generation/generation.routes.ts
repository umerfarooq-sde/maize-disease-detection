import { type RequestHandler, Router } from 'express';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { optionallyAuthenticate } from '../../middleware/authentication.js';
import { optionallyAuthorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest, withRequestSchema } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { createGenerationController } from './generation.controller.js';
import type { GenerationService } from './generation.service.js';
import { askRequest, explanationRequest } from './generation.validators.js';

export function generationRoutes(
  environment: Environment,
  auth: AuthService,
  service: GenerationService,
): Router {
  const router = Router();
  const controller = createGenerationController(service);
  const noStore: RequestHandler = (_request, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    next();
  };
  const limit = requestRateLimit(environment.GENERATION_RATE_LIMIT_MAX);
  const jsonOnly: RequestHandler = (request, _response, next) => {
    if (!request.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    next();
  };
  router.post(
    '/knowledge/ask',
    noStore,
    limit,
    jsonOnly,
    validateRequest(askRequest),
    controller.ask,
  );
  router.post(
    '/scans/:scanId/explanation',
    noStore,
    optionallyAuthenticate(auth),
    optionallyAuthorize('FARMER'),
    limit,
    jsonOnly,
    withRequestSchema(explanationRequest, (request, response, next) => {
      const parsed = explanationRequest.safeParse({
        body: request.body as unknown,
        params: request.params,
        query: request.query,
        key: request.get('idempotency-key'),
      });
      if (!parsed.success) throw new AppError('VALIDATION_ERROR');
      response.locals.validated = parsed.data;
      next();
    }),
    controller.explain,
  );
  return router;
}
