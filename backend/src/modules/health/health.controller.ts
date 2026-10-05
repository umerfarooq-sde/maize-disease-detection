import type { RequestHandler } from 'express';
import { sendSuccess } from '../../utils/respond.js';
import type { HealthService } from './health.service.js';

export function createHealthController(service: HealthService): RequestHandler {
  return async (_request, response) => {
    const health = await service.getHealth();
    response.setHeader('Cache-Control', 'no-store');
    sendSuccess(response, health, health.status === 'ok' ? 200 : 503);
  };
}
