import type { RequestHandler } from 'express';
import { sendSuccess } from '../../utils/respond.js';
import type { ModelHealthService } from './model-health.service.js';
export function modelHealthController(service: ModelHealthService): RequestHandler {
  return async (_request, response) => {
    sendSuccess(response, await service.summary());
  };
}
