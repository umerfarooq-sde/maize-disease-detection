import type { RequestHandler } from 'express';
import type { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { AnalyticsService } from './analytics.service.js';
import type { activityQuery, analyticsQuery } from './analytics.types.js';

export function createAnalyticsController(service: AnalyticsService): {
  summary: RequestHandler;
  activity: RequestHandler;
} {
  return {
    summary: async (_request, response) => {
      const actor = response.locals.principal;
      if (!actor) throw new AppError('AUTHENTICATION_ERROR');
      const query = response.locals.validated as z.infer<typeof analyticsQuery>;
      sendSuccess(response, await service.summary(actor.userId, query));
    },
    activity: async (_request, response) => {
      const actor = response.locals.principal;
      if (!actor) throw new AppError('AUTHENTICATION_ERROR');
      const query = response.locals.validated as z.infer<typeof activityQuery>;
      sendSuccess(response, await service.activity(actor.userId, query));
    },
  };
}
