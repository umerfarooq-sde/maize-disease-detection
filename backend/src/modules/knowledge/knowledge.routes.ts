import { type RequestHandler, Router } from 'express';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import { createKnowledgeController } from './knowledge.controller.js';
import type { KnowledgeService } from './knowledge.service.js';
import {
  diseaseDetailRequest,
  diseaseListRequest,
  knowledgeSearchRequest,
} from './knowledge.validators.js';

export function knowledgeRoutes(environment: Environment, service: KnowledgeService): Router {
  const router = Router();
  const controller = createKnowledgeController(service);
  const noStore: RequestHandler = (_request, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    next();
  };
  const limit = requestRateLimit(environment.KNOWLEDGE_RATE_LIMIT_MAX);
  const jsonOnly: RequestHandler = (request, _response, next) => {
    if (!request.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    next();
  };
  router.get('/diseases', noStore, limit, validateRequest(diseaseListRequest), controller.list);
  router.get(
    '/diseases/:slug',
    noStore,
    limit,
    validateRequest(diseaseDetailRequest),
    controller.detail,
  );
  router.post(
    '/knowledge/search',
    noStore,
    limit,
    jsonOnly,
    validateRequest(knowledgeSearchRequest),
    controller.search,
  );
  return router;
}
