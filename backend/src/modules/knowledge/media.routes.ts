import { Router, type RequestHandler } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import { AppError } from '../../errors/app-error.js';
import type { AuthService } from '../auth/auth.service.js';
import type { ReferenceService } from './media.service.js';
import type { PrivateImageReader } from '../scans/private-image.js';
import { referenceController } from './media.controller.js';
import { referenceMetadata, referenceEdit, referenceStatus } from './media.types.js';
import { managedSlug } from '../admin/management.types.js';
import { scanLimits } from '../scans/scan.types.js';
export const referenceRequest = (body: z.ZodType, params: z.ZodType = z.strictObject({})) =>
  z.strictObject({ body, params, query: z.strictObject({}) });
export function referenceRoutes(
  auth: AuthService,
  service: ReferenceService,
  readImage: PrivateImageReader,
): Router {
  const router = Router(),
    id = z.strictObject({ id: z.uuid() }),
    slug = z.strictObject({ slug: managedSlug });
  router.get(
    '/diseases/:slug/images',
    requestRateLimit(60),
    validateRequest(referenceRequest(z.undefined(), slug)),
    referenceController(service, 'list', false, readImage),
  );
  router.get(
    '/disease-images/:id/image',
    requestRateLimit(60),
    validateRequest(referenceRequest(z.undefined(), id)),
    referenceController(service, 'image', false, readImage),
  );
  router.use(
    '/admin/disease-images',
    authenticate(auth),
    authorize('ADMIN'),
    requestRateLimit(30),
    (req, res, next) => {
      res.setHeader('Cache-Control', 'no-store');
      if (!['GET', 'HEAD'].includes(req.method) && req.get('x-auth-request') !== '1')
        throw new AppError('AUTHORIZATION_ERROR');
      next();
    },
  );
  router.get(
    '/admin/disease-images/:slug/items',
    validateRequest(referenceRequest(z.undefined(), slug)),
    referenceController(service, 'list', true, readImage),
  );
  router.get(
    '/admin/disease-images/:id/image',
    validateRequest(referenceRequest(z.undefined(), id)),
    referenceController(service, 'image', true, readImage),
  );
  let active = 0;
  const parser = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: scanLimits.bytes, files: 1, fields: 1, parts: 2, fieldSize: 16384 },
  }).single('image');
  const multipart: RequestHandler = (req, res, next) => {
    if (
      !req.is('multipart/form-data') ||
      (req.get('content-encoding') && req.get('content-encoding') !== 'identity')
    )
      throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    if (active >= 2) throw new AppError('RATE_LIMITED');
    active++;
    let released = false;
    const release = () => {
      if (!released) {
        released = true;
        active--;
      }
    };
    res.locals.releaseReferenceUpload = release;
    res.once('close', release);
    parser(req, res, (error) => {
      if (error) {
        release();
        next(
          new AppError(
            error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE'
              ? 'PAYLOAD_TOO_LARGE'
              : 'VALIDATION_ERROR',
          ),
        );
        return;
      }
      try {
        if (Object.keys(req.body as object).length !== 1 || typeof req.body.metadata !== 'string')
          throw new Error();
        req.body = JSON.parse(req.body.metadata);
        next();
      } catch {
        release();
        next(new AppError('VALIDATION_ERROR'));
      }
    });
  };
  router.post(
    '/admin/disease-images',
    multipart,
    validateRequest(referenceRequest(referenceMetadata)),
    referenceController(service, 'upload', true, readImage),
  );
  const json: RequestHandler = (req, _res, next) => {
    if (!req.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    next();
  };
  router.patch(
    '/admin/disease-images/:id',
    json,
    validateRequest(referenceRequest(referenceEdit, id)),
    referenceController(service, 'edit', true, readImage),
  );
  router.patch(
    '/admin/disease-images/:id/status',
    json,
    validateRequest(referenceRequest(referenceStatus, id)),
    referenceController(service, 'status', true, readImage),
  );
  return router;
}
