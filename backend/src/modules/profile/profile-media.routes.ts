import { Router, type RequestHandler } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { authenticate } from '../../middleware/authentication.js';
import { authorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import { validateRequest } from '../../validators/request.js';
import type { AuthService } from '../auth/auth.service.js';
import { scanLimits } from '../scans/scan.types.js';
import { profileMediaController } from './profile-media.controller.js';
import type { ProfileMediaService } from './profile-media.service.js';

export function profileMediaRoutes(auth: AuthService, service: ProfileMediaService): Router {
  const router = Router();
  router.use(
    '/profile/avatar',
    authenticate(auth),
    authorize('FARMER'),
    requestRateLimit(10, 15 * 60000),
    (req, response, next) => {
      response.setHeader('Cache-Control', 'no-store');
      if (req.get('x-auth-request') !== '1') throw new AppError('AUTHORIZATION_ERROR');
      if (Object.keys(req.query).length) throw new AppError('VALIDATION_ERROR');
      next();
    },
  );
  const schema = z.strictObject({ expectedRevision: z.string().regex(/^[a-f0-9]{64}$/) });
  const request = validateRequest(
    z.strictObject({ body: schema, params: z.strictObject({}), query: z.strictObject({}) }),
  );
  const parser = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: scanLimits.bytes, files: 1, fields: 1, parts: 2, fieldSize: 128 },
  }).single('image');
  const multipart: RequestHandler = (request, response, next) => {
    parser(request, response, (error: unknown) => {
      if (error)
        next(
          new AppError(
            error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE'
              ? 'PAYLOAD_TOO_LARGE'
              : 'VALIDATION_ERROR',
          ),
        );
      else next();
    });
  };
  let active = 0;
  router.post(
    '/profile/avatar',
    (req, response, next) => {
      if (
        !req.is('multipart/form-data') ||
        (req.get('content-encoding') && req.get('content-encoding') !== 'identity')
      )
        throw new AppError('UNSUPPORTED_MEDIA_TYPE');
      if (!service.enabled || active >= 2) throw new AppError('UPLOAD_UNAVAILABLE');
      active++;
      let released = false;
      const release = () => {
        if (!released) {
          released = true;
          active--;
        }
      };
      response.locals.releaseProfileUpload = release;
      response.once('finish', release);
      response.once('close', () => {
        if (!req.complete) release();
      });
      next();
    },
    multipart,
    request,
    profileMediaController(service, 'upload'),
  );
  router.delete(
    '/profile/avatar',
    (req, _response, next) => {
      if (!req.is('application/json')) throw new AppError('UNSUPPORTED_MEDIA_TYPE');
      next();
    },
    request,
    profileMediaController(service, 'remove'),
  );
  return router;
}
