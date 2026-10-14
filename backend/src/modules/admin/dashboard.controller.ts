import type { RequestHandler } from 'express';
import { sendSuccess } from '../../utils/respond.js';
import type { DashboardService } from './dashboard.service.js';

export function createDashboardController(service: DashboardService): RequestHandler {
  return async (_request, response) => {
    const query = response.locals.validated as { from?: string; to?: string };
    sendSuccess(response, await service.summary(query));
  };
}
