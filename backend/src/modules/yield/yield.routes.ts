import { type RequestHandler, Router } from 'express';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { createYieldController } from './yield.controller.js';
import type { YieldService } from './yield.service.js';
import {
  yieldCalculateRequest,
  yieldDraftRequest,
  yieldListRequest,
  yieldStatusRequest,
} from './yield.types.js';

export function yieldRoutes(
  environment: Environment,
  auth: AuthService,
  service: YieldService,
): Router {
  const router = Router();
  const controller = createYieldController(service);
  const noStore: RequestHandler = (_request, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    next();
  };
  const jsonOnly: RequestHandler = (request, _response, next) => {
    if (!request.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    next();
  };
  const limit = requestRateLimit(environment.CALCULATOR_RATE_LIMIT_MAX);
  const path = '/calculators/yield';
  router.use(path, noStore, limit);
  router.get(`${path}/configurations`, validateRequest(yieldListRequest), controller.list);
  router.post(
    `${path}/calculate`,
    jsonOnly,
    validateRequest(yieldCalculateRequest),
    controller.calculate,
  );
  const admin = '/admin/calculators/yield/configurations';
  router.use(admin, noStore, limit, authenticate(auth), authorize('ADMIN'));
  router.get(admin, validateRequest(yieldListRequest), controller.drafts);
  router.post(admin, jsonOnly, validateRequest(yieldDraftRequest), controller.createDraft);
  router.patch(
    `${admin}/:configId/status`,
    jsonOnly,
    validateRequest(yieldStatusRequest),
    controller.changeStatus,
  );
  return router;
}
