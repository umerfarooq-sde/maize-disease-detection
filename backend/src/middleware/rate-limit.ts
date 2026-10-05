import type { RequestHandler } from 'express';
import { rateLimit } from 'express-rate-limit';
import { AppError } from '../errors/app-error.js';

export function requestRateLimit(limit: number, windowMs = 60000): RequestHandler {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    // Use the socket address; configure trusted proxies only when deployment is known.
    handler(_request, _response, next) {
      next(new AppError('RATE_LIMITED'));
    },
  });
}
