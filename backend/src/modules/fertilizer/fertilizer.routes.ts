import { type RequestHandler, Router } from 'express';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { createFertilizerController } from './fertilizer.controller.js';
import type { FertilizerService } from './fertilizer.service.js';
import {
  fertilizerCalculateRequest,
  fertilizerDraftRequest,
  fertilizerListRequest,
  fertilizerStatusRequest,
} from './fertilizer.validators.js';

export function fertilizerRoutes(
  environment: Environment,
  auth: AuthService,
  service: FertilizerService,
): Router {
  const router = Router();
  const controller = createFertilizerController(service);
  const noStore: RequestHandler = (_request, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    next();
  };
  const limit = requestRateLimit(environment.CALCULATOR_RATE_LIMIT_MAX);
  const jsonOnly: RequestHandler = (request, _response, next) => {
    if (!request.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    next();
  };
  const farmerPath = '/calculators/fertilizer';
  const adminPath = '/admin/calculators/fertilizer';
  router.get(
    `${farmerPath}/rules`,
    noStore,
    limit,
    validateRequest(fertilizerListRequest),
    controller.list,
  );
  router.post(
    `${farmerPath}/calculate`,
    noStore,
    limit,
    jsonOnly,
    validateRequest(fertilizerCalculateRequest),
    controller.calculate,
  );
  router.use(adminPath, noStore, limit, authenticate(auth), authorize('ADMIN'));
  router.get(`${adminPath}/rules`, validateRequest(fertilizerListRequest), controller.drafts);
  router.post(
    `${adminPath}/rules`,
    jsonOnly,
    validateRequest(fertilizerDraftRequest),
    controller.createDraft,
  );
  router.patch(
    `${adminPath}/rules/:ruleId/status`,
    jsonOnly,
    validateRequest(fertilizerStatusRequest),
    controller.changeStatus,
  );
  return router;
}
