import type { RequestHandler } from 'express';
import type { z } from 'zod';
import { AppError } from '../errors/app-error.js';

// Schemas describe { body, params, query }. Parsed/coerced values live in locals:
// Express 5's request.query is a getter and must not be reassigned.
export function validateRequest(schema: z.ZodType): RequestHandler {
  return async (request, response, next) => {
    const body: unknown = request.body;
    const result = await schema.safeParseAsync({
      body,
      params: request.params,
      query: request.query,
    });
    if (!result.success) {
      throw new AppError(
        'VALIDATION_ERROR',
        result.error.issues.map((issue) => ({
          path: issue.path.map(String).join('.'),
          code: issue.code,
        })),
      );
    }
    response.locals.validated = result.data;
    next();
  };
}
