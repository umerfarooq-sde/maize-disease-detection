import type { RequestHandler } from 'express';
import { rateLimit } from 'express-rate-limit';
import { AppError } from '../errors/app-error.js';
import type { DistributedQuota } from '../infrastructure/quotas.js';

export function requestRateLimit(limit: number, windowMs = 60000): RequestHandler {
  const local = rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    // Use the socket address; configure trusted proxies only when deployment is known.
    handler(_request, _response, next) {
      next(new AppError('RATE_LIMITED'));
    },
  });
  return (request, response, next) => {
    const distributed = request.app.locals.distributedQuota as DistributedQuota | undefined;
    if (!distributed) return local(request, response, next);
    return void distributed.admit(request, response, limit, windowMs).then(() => next(), next);
  };
}
