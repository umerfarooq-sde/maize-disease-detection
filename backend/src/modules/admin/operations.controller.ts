import type { RequestHandler } from 'express';
import type { z } from 'zod';
import type { operationsRequest } from './operations.routes.js';
import { sendSuccess } from '../../utils/respond.js';
import type { OperationsService } from './operations.service.js';
export function operationsController(service: OperationsService): RequestHandler {
  return async (_request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    const query = (response.locals.validated as z.infer<typeof operationsRequest>).query;
    sendSuccess(response, await service.summaryQuery(query));
  };
}
