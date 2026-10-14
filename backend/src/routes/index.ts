import { Router } from 'express';
import type { Environment } from '../config/environment.js';
import { dashboardRoutes } from '../modules/admin/dashboard.routes.js';
import type { DashboardService } from '../modules/admin/dashboard.service.js';
import { analyticsRoutes } from '../modules/analytics/analytics.routes.js';
import type { AnalyticsService } from '../modules/analytics/analytics.service.js';
import { authRoutes } from '../modules/auth/auth.routes.js';
import type { AuthService } from '../modules/auth/auth.service.js';
import { fertilizerRoutes } from '../modules/fertilizer/fertilizer.routes.js';
import type { FertilizerService } from '../modules/fertilizer/fertilizer.service.js';
import { generationRoutes } from '../modules/generation/generation.routes.js';
import type { GenerationService } from '../modules/generation/generation.service.js';
import type { HealthRepository } from '../modules/health/health.repository.js';
import { healthRoutes } from '../modules/health/health.routes.js';
import { createHealthService } from '../modules/health/health.service.js';
import { knowledgeRoutes } from '../modules/knowledge/knowledge.routes.js';
import type { KnowledgeService } from '../modules/knowledge/knowledge.service.js';
import { scanRoutes } from '../modules/scans/scan.routes.js';
import type { ScanService } from '../modules/scans/scan.service.js';
import { yieldRoutes } from '../modules/yield/yield.routes.js';
import type { YieldService } from '../modules/yield/yield.service.js';

export function apiRoutes(
  repository: HealthRepository,
  environment: Environment,
  authService: AuthService,
  scanService: ScanService,
  knowledgeService: KnowledgeService,
  generationService: GenerationService,
  fertilizerService: FertilizerService,
  yieldService: YieldService,
  analyticsService: AnalyticsService,
  dashboardService: DashboardService,
): Router {
  const router = Router();
  router.use(healthRoutes(createHealthService(repository)));
  router.use('/auth', authRoutes(environment, authService));
  router.use('/scans', scanRoutes(environment, authService, scanService));
  router.use(knowledgeRoutes(environment, knowledgeService));
  router.use(generationRoutes(environment, authService, generationService));
  router.use(fertilizerRoutes(environment, authService, fertilizerService));
  router.use(yieldRoutes(environment, authService, yieldService));
  router.use(analyticsRoutes(environment, authService, analyticsService));
  router.use(dashboardRoutes(environment, authService, dashboardService));
  return router;
}
