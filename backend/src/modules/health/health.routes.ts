import { Router } from 'express';
import { z } from 'zod';
import { validateRequest } from '../../validators/request.js';
import { createHealthController } from './health.controller.js';
import type { HealthService } from './health.service.js';

const healthRequest = z.object({
  query: z.object({}).strict(),
  params: z.object({}).strict(),
  body: z.undefined(),
});

export function healthRoutes(service: HealthService): Router {
  const router = Router();
  router.get('/health', validateRequest(healthRequest), createHealthController(service));
  return router;
}
