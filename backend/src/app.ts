import cors from 'cors';
import { createPrivacyRepository } from './modules/privacy/privacy.repository.js';
import { createPrivacyService, type PrivacyService } from './modules/privacy/privacy.service.js';
import express, { type Express } from 'express';
import helmet from 'helmet';
import type { Logger } from 'pino';
import type { Environment } from './config/environment.js';
import { getDatabaseClient } from './database/client.js';
import { createSpecificationRepository } from './modules/calculators/model-specification.repository.js';
import {
  createSpecificationService,
  type SpecificationService,
} from './modules/calculators/model-specification.service.js';
import { AppError } from './errors/app-error.js';
import { errorHandler, notFound } from './middleware/error-handler.js';
import { requestRateLimit } from './middleware/rate-limit.js';
import { createDistributedQuota, redisQuotaStore } from './infrastructure/quotas.js';
import { installOperations } from './infrastructure/metrics.js';
import { requestContext } from './middleware/request-context.js';
import { createDashboardRepository } from './modules/admin/dashboard.repository.js';
import { operationsFor } from './modules/admin/operations.service.js';
import { createReferenceRepository } from './modules/knowledge/media.repository.js';
import {
  createReferenceService,
  type ReferenceService,
} from './modules/knowledge/media.service.js';
import {
  observeInference,
  observeKnowledge,
  observeGeneration,
} from './modules/admin/operations.observers.js';
import { createModelHealthRepository } from './modules/admin/model-health.repository.js';
import {
  createModelHealthClient,
  createModelHealthService,
  type ModelHealthService,
} from './modules/admin/model-health.service.js';
import { createManagementIndexer } from './modules/admin/management.client.js';
import { createManagementRepository } from './modules/admin/management.repository.js';
import {
  createManagementService,
  type ManagementService,
} from './modules/admin/management.service.js';
import {
  createDashboardService,
  type DashboardService,
} from './modules/admin/dashboard.service.js';
import { createAnalyticsRepository } from './modules/analytics/analytics.repository.js';
import {
  type AnalyticsService,
  createAnalyticsService,
} from './modules/analytics/analytics.service.js';
import { type AuthRepository, createAuthRepository } from './modules/auth/auth.repository.js';
import { createAuthService } from './modules/auth/auth.service.js';
import { createFertilizerRepository } from './modules/fertilizer/fertilizer.repository.js';
import { createProductRepository } from './modules/fertilizer/catalogue.repository.js';
import {
  createProductService,
  type ProductService,
} from './modules/fertilizer/catalogue.service.js';
import {
  createFertilizerService,
  type FertilizerService,
} from './modules/fertilizer/fertilizer.service.js';
import { createGenerationClient } from './modules/generation/generation.client.js';
import {
  createGenerationService,
  type GenerationService,
} from './modules/generation/generation.service.js';
import type { HealthRepository } from './modules/health/health.repository.js';
import { createAiInferenceClient } from './modules/inference/inference.client.js';
import { createKnowledgeClient } from './modules/knowledge/knowledge.client.js';
import { createKnowledgeRepository } from './modules/knowledge/knowledge.repository.js';
import {
  createKnowledgeService,
  type KnowledgeService,
} from './modules/knowledge/knowledge.service.js';
import { createScanRepository } from './modules/scans/scan.repository.js';
import { createScanService, type ScanService } from './modules/scans/scan.service.js';
import { createImageStorage } from './modules/scans/scan.storage.js';
import { createYieldRepository } from './modules/yield/yield.repository.js';
import { createYieldService, type YieldService } from './modules/yield/yield.service.js';
import { apiRoutes } from './routes/index.js';
import { createProfileMediaRepository } from './modules/profile/profile-media.repository.js';
import {
  createProfileMediaService,
  type ProfileMediaService,
} from './modules/profile/profile-media.service.js';
import { createProfileRepository } from './modules/profile/profile.repository.js';
import { createProfileService, type ProfileService } from './modules/profile/profile.service.js';
import { createAccountsRepository } from './modules/admin/accounts.repository.js';
import { createAccountsService, type AccountsService } from './modules/admin/accounts.service.js';

export function createApp(
  environment: Environment,
  logger: Logger,
  repository: HealthRepository,
  authRepository: AuthRepository = createAuthRepository(
    getDatabaseClient(environment.DATABASE_URL),
  ),
  scanService: ScanService = createScanService(
    createScanRepository(getDatabaseClient(environment.DATABASE_URL)),
    createImageStorage(environment),
    logger,
    observeInference(
      createAiInferenceClient(environment),
      operationsFor(getDatabaseClient(environment.DATABASE_URL), logger),
    ),
  ),
  knowledgeService: KnowledgeService = createKnowledgeService(
    createKnowledgeRepository(getDatabaseClient(environment.DATABASE_URL)),
    observeKnowledge(
      createKnowledgeClient(environment),
      operationsFor(getDatabaseClient(environment.DATABASE_URL), logger),
    ),
  ),
  generationService: GenerationService = createGenerationService(
    scanService,
    observeGeneration(
      createGenerationClient(environment),
      operationsFor(getDatabaseClient(environment.DATABASE_URL), logger),
    ),
  ),
  fertilizerService: FertilizerService = createFertilizerService(
    createFertilizerRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
  yieldService: YieldService = createYieldService(
    createYieldRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
  analyticsService: AnalyticsService = createAnalyticsService(
    createAnalyticsRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
  dashboardService: DashboardService = createDashboardService(
    createDashboardRepository(getDatabaseClient(environment.DATABASE_URL)),
    environment,
  ),
  managementService: ManagementService = createManagementService(
    createManagementRepository(getDatabaseClient(environment.DATABASE_URL)),
    createManagementIndexer(environment),
  ),
  modelHealthService: ModelHealthService = createModelHealthService(
    createModelHealthRepository(getDatabaseClient(environment.DATABASE_URL)),
    environment,
    createModelHealthClient(environment),
  ),
  profileService: ProfileService = createProfileService(
    createProfileRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
  accountsService: AccountsService = createAccountsService(
    createAccountsRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
  profileMediaService: ProfileMediaService = createProfileMediaService(
    createProfileMediaRepository(getDatabaseClient(environment.DATABASE_URL)),
    createImageStorage(environment, 'profiles'),
  ),
  referenceService: ReferenceService = createReferenceService(
    createReferenceRepository(getDatabaseClient(environment.DATABASE_URL), logger),
    createImageStorage(environment, 'references'),
  ),
  specificationService: SpecificationService = createSpecificationService(
    createSpecificationRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
  productService: ProductService = createProductService(
    createProductRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
  privacyService: PrivacyService = createPrivacyService(
    createPrivacyRepository(getDatabaseClient(environment.DATABASE_URL)),
  ),
): Express {
  const app = express();
  if (environment.TRUST_PROXY)
    app.set(
      'trust proxy',
      environment.TRUST_PROXY.split(',').map((value) => value.trim()),
    );
  const quota = environment.REDIS_URL
    ? createDistributedQuota(environment, redisQuotaStore(environment.REDIS_URL, logger), logger)
    : undefined;
  app.locals.distributedQuota = quota;
  app.locals.startInfrastructure = async () => {
    await quota?.start();
  };
  app.locals.stopInfrastructure = async () => {
    await quota?.close();
  };
  installOperations(app, environment, repository, quota);
  app.locals.recoverScans = () => scanService.recoverStale();
  app.locals.flushOperationalEvents = () =>
    operationsFor(getDatabaseClient(environment.DATABASE_URL), logger).close();
  app.locals.telemetryOperationalState = () =>
    operationsFor(getDatabaseClient(environment.DATABASE_URL), logger).operationalState();
  app.disable('x-powered-by');
  app.set('query parser', 'simple');
  app.use(requestContext(logger));
  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        if (origin === undefined || environment.CORS_ORIGINS.includes(origin)) callback(null, true);
        else callback(new AppError('AUTHORIZATION_ERROR'));
      },
      credentials: true,
      exposedHeaders: ['X-Request-Id'],
      maxAge: 600,
    }),
  );
  app.use(requestRateLimit(environment.RATE_LIMIT_MAX));
  app.use(express.json({ limit: '100kb', strict: true, inflate: false }));
  const v1Router = apiRoutes(
    repository,
    environment,
    createAuthService(environment, authRepository),
    scanService,
    knowledgeService,
    generationService,
    fertilizerService,
    yieldService,
    analyticsService,
    dashboardService,
    managementService,
    modelHealthService,
    profileService,
    accountsService,
    profileMediaService,
    operationsFor(getDatabaseClient(environment.DATABASE_URL), logger),
    referenceService,
    specificationService,
    productService,
    privacyService,
  );
  app.locals.contractRouter = v1Router;
  app.use('/api/v1', v1Router);
  app.use(notFound);
  app.use(errorHandler(logger));
  return app;
}
