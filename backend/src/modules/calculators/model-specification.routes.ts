import { Router } from 'express';
import { z } from 'zod';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { validateRequest } from '../../validators/request.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { AppError } from '../../errors/app-error.js';
import type { AuthService } from '../auth/auth.service.js';
import { modelSpecification } from './model-specification.types.js';
import { specificationController } from './model-specification.controller.js';
import type { SpecificationService } from './model-specification.service.js';
export function specificationRoutes(auth: AuthService, service: SpecificationService): Router {
  const router = Router(),
    path = '/admin/calculators/model-specifications';
  router.use(path, authenticate(auth), authorize('ADMIN'), requestRateLimit(30));
  const schema = (body: z.ZodType) =>
    z.strictObject({ body, params: z.strictObject({}), query: z.strictObject({}) });
  router.get(path, validateRequest(schema(z.undefined())), specificationController(service));
  router.post(
    path,
    (req, _res, next) => {
      if (!req.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
      next();
    },
    validateRequest(schema(modelSpecification)),
    specificationController(service, true),
  );
  return router;
}
