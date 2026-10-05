import { randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import type { RequestHandler } from 'express';
import type { Logger } from 'pino';

export function requestContext(logger: Logger): RequestHandler {
  return (request, response, next) => {
    // Generate our own ID rather than trusting an arbitrary client-supplied header.
    const requestId = randomUUID();
    const started = performance.now();
    response.locals.requestId = requestId;
    response.setHeader('X-Request-Id', requestId);
    response.on('finish', () => {
      // Log the registered route pattern only; URL params and query strings may contain secrets.
      const route: unknown = request.route;
      const path =
        typeof route === 'object' &&
        route !== null &&
        'path' in route &&
        typeof route.path === 'string'
          ? route.path
          : '[unmatched]';
      logger.info(
        {
          requestId,
          method: request.method,
          route: path,
          status: response.statusCode,
          durationMs: Math.round(performance.now() - started),
        },
        'Request completed',
      );
    });
    next();
  };
}
