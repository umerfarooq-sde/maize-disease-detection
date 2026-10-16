import { Router } from 'express';
import { z } from 'zod';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import { AppError } from '../../errors/app-error.js';
import type { AuthService } from '../auth/auth.service.js';
import type { ProductService } from './catalogue.service.js';
import { productController } from './catalogue.controller.js';
import { productWrite, productStatus } from './catalogue.types.js';
export function productRoutes(auth: AuthService, service: ProductService): Router {
  const router = Router(),
    path = '/admin/fertilizers',
    id = z.strictObject({ id: z.uuid() });
  router.use(
    path,
    authenticate(auth),
    authorize('ADMIN'),
    requestRateLimit(30),
    (req, _res, next) => {
      if (!['GET', 'HEAD'].includes(req.method) && !req.is('application/json'))
        throw new AppError('UNSUPPORTED_MEDIA_TYPE');
      next();
    },
  );
  const schema = (body: z.ZodType, params: z.ZodType = z.strictObject({})) =>
    z.strictObject({ body, params, query: z.strictObject({}) });
  router.get(
    path,
    validateRequest(
      z.strictObject({
        body: z.undefined(),
        params: z.strictObject({}),
        query: z.strictObject({ cursor: z.uuid().optional() }),
      }),
    ),
    productController(service, 'list'),
  );
  router.post(path, validateRequest(schema(productWrite)), productController(service, 'create'));
  router.patch(
    `${path}/:id`,
    validateRequest(schema(productWrite, id)),
    productController(service, 'edit'),
  );
  router.patch(
    `${path}/:id/status`,
    validateRequest(schema(productStatus, id)),
    productController(service, 'status'),
  );
  return router;
}
