import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { accountsController } from './accounts.controller.js';
import type { AccountsService } from './accounts.service.js';
import { auditQuery, farmerQuery, statusPatch } from './accounts.types.js';

export function accountsRoutes(auth: AuthService, service: AccountsService): Router {
  const router = Router();
  const guard = [
    (
      _request: import('express').Request,
      response: import('express').Response,
      next: import('express').NextFunction,
    ) => {
      response.setHeader('Cache-Control', 'no-store');
      next();
    },
    requestRateLimit(60),
    authenticate(auth),
    authorize('ADMIN'),
  ];
  const empty = z.strictObject({});
  const request = (body: z.ZodType, params: z.ZodType, query: z.ZodType) =>
    validateRequest(z.strictObject({ body, params, query }));
  router.get(
    '/admin/farmers',
    ...guard,
    request(z.undefined(), empty, farmerQuery),
    accountsController(service, 'farmers'),
  );
  router.get(
    '/admin/audit-logs',
    ...guard,
    request(z.undefined(), empty, auditQuery),
    accountsController(service, 'audits'),
  );
  router.patch(
    '/admin/farmers/:id/status',
    ...guard,
    (req, _response, next) => {
      if (req.get('x-auth-request') !== '1') throw new AppError('AUTHORIZATION_ERROR');
      if (!req.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
      next();
    },
    request(statusPatch, z.strictObject({ id: z.uuid() }), empty),
    accountsController(service, 'status'),
  );
  return router;
}
