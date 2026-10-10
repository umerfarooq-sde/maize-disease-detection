import { type RequestHandler, Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { optionallyAuthenticate } from '../../middleware/authentication.js';
import { optionallyAuthorize } from '../../middleware/authorization.js';
import { requestRateLimit } from '../../middleware/rate-limit.js';
import type { AuthService } from '../auth/auth.service.js';
import { createScanController, readScanController } from './scan.controller.js';
import type { ScanService } from './scan.service.js';
import { scanLimits } from './scan.types.js';
import { scanRequest } from './scan.validation.js';

export function scanRoutes(
  environment: Environment,
  auth: AuthService,
  service: ScanService,
): Router {
  const router = Router();
  const readRequest = z.strictObject({
    params: z.strictObject({ scanId: z.uuid() }),
    query: z.strictObject({}),
    key: scanRequest.shape.key.optional(),
  });
  router.get(
    '/:scanId',
    requestRateLimit(60),
    optionallyAuthenticate(auth),
    optionallyAuthorize('FARMER'),
    (request, response, next) => {
      response.setHeader('Cache-Control', 'no-store');
      const parsed = readRequest.safeParse({
        params: request.params,
        query: request.query,
        key: request.get('idempotency-key'),
      });
      if (!parsed.success) throw new AppError('VALIDATION_ERROR');
      response.locals.validated = parsed.data;
      next();
    },
    readScanController(service),
  );
  const parser = multer({
    storage: multer.memoryStorage(),
    limits: {
      fileSize: scanLimits.bytes,
      files: 1,
      fields: 0,
      parts: 1,
      fieldNameSize: 100,
      headerPairs: 50,
    },
  }).single('image');
  let active = 0;
  const guard: RequestHandler = (request, response, next) => {
    response.setHeader('Cache-Control', 'no-store');
    if (request.get('x-auth-request') !== '1') throw new AppError('AUTHORIZATION_ERROR');
    if (
      !request.is('multipart/form-data') ||
      (request.get('content-encoding') && request.get('content-encoding') !== 'identity')
    )
      throw new AppError('UNSUPPORTED_MEDIA_TYPE');
    const parsed = scanRequest.safeParse({
      params: request.params,
      query: request.query,
      key: request.get('idempotency-key'),
    });
    if (!parsed.success) throw new AppError('VALIDATION_ERROR');
    response.locals.validated = parsed.data;
    if (!service.enabled || active >= 2) throw new AppError('UPLOAD_UNAVAILABLE');
    active++;
    let released = false;
    const release = () => {
      if (!released) {
        released = true;
        active--;
      }
    };
    response.once('finish', release);
    response.locals.releaseUpload = release;
    // A disconnected client must not free a slot while decoding/storage continues.
    response.once('close', () => {
      if (!request.complete) release();
    });
    next();
  };
  const multipart: RequestHandler = (request, response, next) => {
    parser(request, response, (error: unknown) => {
      if (error) {
        response.locals.releaseUpload?.();
        next(
          new AppError(
            error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE'
              ? 'PAYLOAD_TOO_LARGE'
              : 'VALIDATION_ERROR',
          ),
        );
      } else next();
    });
  };
  router.post(
    '/',
    requestRateLimit(environment.SCAN_RATE_LIMIT_MAX, 15 * 60_000),
    optionallyAuthenticate(auth),
    optionallyAuthorize('FARMER'),
    guard,
    multipart,
    createScanController(service),
  );
  return router;
}
