import { Router } from 'express';
import type { Environment } from '../config/environment.js';
import { authRoutes } from '../modules/auth/auth.routes.js';
import type { AuthService } from '../modules/auth/auth.service.js';
import type { HealthRepository } from '../modules/health/health.repository.js';
import { healthRoutes } from '../modules/health/health.routes.js';
import { createHealthService } from '../modules/health/health.service.js';
import { scanRoutes } from '../modules/scans/scan.routes.js';
import type { ScanService } from '../modules/scans/scan.service.js';

export function apiRoutes(
  repository: HealthRepository,
  environment: Environment,
  authService: AuthService,
  scanService: ScanService,
): Router {
  const router = Router();
  router.use(healthRoutes(createHealthService(repository)));
  router.use('/auth', authRoutes(environment, authService));
  router.use('/scans', scanRoutes(environment, authService, scanService));
  return router;
}
