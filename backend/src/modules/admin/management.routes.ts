import { Router } from 'express';
import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { managementController } from './management.controller.js';
import type { ManagementService } from './management.service.js';
import {
  draftDocumentSchema,
  diseaseEditSchema,
  diseaseCreateSchema,
  managedSlug,
} from './management.types.js';

export function managementRoutes(
  environment: Environment,
  auth: AuthService,
  service: ManagementService,
): Router {
  const router = Router();
  const empty = z.strictObject({}),
    id = z.strictObject({ id: z.uuid() });
  router.use(
    '/admin/knowledge',
    (_request, response, next) => {
      response.setHeader('Cache-Control', 'no-store');
      next();
    },
    requestRateLimit(environment.KNOWLEDGE_RATE_LIMIT_MAX),
    authenticate(auth),
    authorize('ADMIN'),
  );
  const request = (body: z.ZodType, params: z.ZodType = empty, query: z.ZodType = empty) =>
    validateRequest(z.strictObject({ body, params, query }));
  router.get(
    '/admin/knowledge/diseases',
    request(z.undefined()),
    managementController(service, 'diseases'),
  );
  router.get(
    '/admin/knowledge/documents',
    request(z.undefined(), empty, z.strictObject({ cursor: z.uuid().optional() })),
    managementController(service, 'documents'),
  );
  router.get(
    '/admin/knowledge/documents/:id',
    request(z.undefined(), id),
    managementController(service, 'document'),
  );
  router.use('/admin/knowledge', (req, _response, next) => {
    if (!['GET', 'HEAD'].includes(req.method) && !req.is('application/json'))
      throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    next();
  });
  router.patch(
    '/admin/knowledge/diseases/:slug',
    request(diseaseEditSchema, z.strictObject({ slug: managedSlug })),
    managementController(service, 'editDisease'),
  );
  router.post(
    '/admin/knowledge/diseases',
    request(diseaseCreateSchema),
    managementController(service, 'createDisease'),
  );
  router.post(
    '/admin/knowledge/documents',
    request(draftDocumentSchema),
    managementController(service, 'createDraft'),
  );
  router.post(
    '/admin/knowledge/documents/:id/index',
    requestRateLimit(environment.KNOWLEDGE_RATE_LIMIT_MAX),
    request(empty, id),
    managementController(service, 'index'),
  );
  router.patch(
    '/admin/knowledge/documents/:id/status',
    request(
      z.strictObject({
        status: z.enum(['ACTIVE', 'ARCHIVED']),
        expectedStatus: z.enum(['DRAFT', 'ACTIVE', 'ARCHIVED']),
      }),
      id,
    ),
    managementController(service, 'status'),
  );
  return router;
}
