import { Router } from 'express';
import type { HealthRepository } from '../modules/health/health.repository.js';
import { healthRoutes } from '../modules/health/health.routes.js';
import { createHealthService } from '../modules/health/health.service.js';

export function apiRoutes(repository: HealthRepository): Router {
  const router = Router();
  router.use(healthRoutes(createHealthService(repository)));
  return router;
}
