import { timingSafeEqual } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import type { Express, RequestHandler } from 'express';
import { collectDefaultMetrics, Counter, Gauge, Histogram, Registry } from 'prom-client';
import type { Environment } from '../config/environment.js';
import type { HealthRepository } from '../modules/health/health.repository.js';
import type { DistributedQuota } from './quotas.js';
import { createModelHealthClient } from '../modules/admin/model-health.service.js';

export const databaseRegistry = new Registry();
export const databaseQuery = new Histogram({
  name: 'maizedoctor_database_query_seconds',
  help: 'Prisma query duration; SQL and parameters are never exported.',
  registers: [databaseRegistry],
});
export const databaseAcquisition = new Histogram({
  name: 'maizedoctor_database_acquisition_seconds',
  help: 'Node connection checkout wall time.',
  labelNames: ['outcome'],
  registers: [databaseRegistry],
});
export const databaseFailures = new Counter({
  name: 'maizedoctor_database_failures_total',
  help: 'Safe Node driver failures.',
  labelNames: ['stage'],
  registers: [databaseRegistry],
});
export const databasePool = new Gauge({
  name: 'maizedoctor_database_pool_connections',
  help: 'Process-local Node pool state.',
  labelNames: ['state'],
  registers: [databaseRegistry],
});

export function installOperations(
  app: Express,
  environment: Environment,
  health: HealthRepository,
  quota?: DistributedQuota,
) {
  const registry = new Registry();
  collectDefaultMetrics({ register: registry, prefix: 'maizedoctor_' });
  const modelHealth = createModelHealthClient(environment);
  const requests = new Counter({
    name: 'maizedoctor_http_requests_total',
    help: 'HTTP completions; no request content.',
    labelNames: ['method', 'route', 'status'],
    registers: [registry],
  });
  const latency = new Histogram({
    name: 'maizedoctor_http_duration_seconds',
    help: 'HTTP duration.',
    labelNames: ['method', 'route'],
    registers: [registry],
    buckets: [0.05, 0.1, 0.5, 1, 2, 5, 10, 30, 60, 120],
  });
  const errors = new Counter({
    name: 'maizedoctor_errors_total',
    help: 'Application failure categories.',
    labelNames: ['code'],
    registers: [registry],
  });
  const rss = new Gauge({
    name: 'maizedoctor_node_resident_bytes',
    help: 'Node resident bytes.',
    registers: [registry],
  });
  const ready = new Gauge({
    name: 'maizedoctor_dependency_ready',
    help: 'Latest readiness observation; absent before first check.',
    labelNames: ['dependency'],
    registers: [registry],
  });
  const pending = new Gauge({
    name: 'maizedoctor_node_telemetry_pending',
    help: 'Bounded best-effort writer queue plus active write.',
    registers: [registry],
  });
  const dropped = new Gauge({
    name: 'maizedoctor_node_telemetry_dropped',
    help: 'Observed process-local event loss; restart resets this observation.',
    registers: [registry],
  });
  app.locals.recordOperationalError = (code: string) => errors.inc({ code });
  const authenticate: RequestHandler = (request, response, next) => {
    const provided = request.header('X-Operations-Token') ?? '';
    const expected = environment.OPERATIONS_TOKEN;
    if (
      !expected ||
      Buffer.byteLength(provided) !== Buffer.byteLength(expected) ||
      !timingSafeEqual(Buffer.from(provided), Buffer.from(expected))
    ) {
      response.status(404).end();
      return;
    }
    next();
  };
  app.get('/internal/metrics', authenticate, async (_request, response) => {
    rss.set(process.memoryUsage().rss);
    const state = app.locals.telemetryOperationalState?.() as
      | { dropped: number; pending: number }
      | undefined;
    if (state) {
      pending.set(state.pending);
      dropped.set(state.dropped);
    }
    response
      .type(registry.contentType)
      .send((await registry.metrics()) + (await databaseRegistry.metrics()));
  });
  app.get('/internal/ready', authenticate, async (_request, response) => {
    const redis = quota?.ready() ?? environment.NODE_ENV !== 'production';
    // Independent probes share their existing deadlines; sequential acquisition
    // would unnecessarily add two database waits to the model-service deadline.
    const [databaseResult, aiResult, registryResult] = await Promise.allSettled([
      health.checkDatabase(),
      (async () => {
        if (!environment.AI_SERVICE_URL) return true;
        const result = await modelHealth();
        return (
          result.ready &&
          result.modelVersion === environment.AI_MODEL_VERSION &&
          result.preprocessingVersion === environment.AI_PREPROCESSING_VERSION
        );
      })(),
      (async () => {
        if (!environment.AI_SERVICE_URL) return true;
        if (!health.checkModelVersion) return false;
        await health.checkModelVersion(
          environment.AI_MODEL_VERSION,
          environment.AI_PREPROCESSING_VERSION,
        );
        return true;
      })(),
    ]);
    const database = databaseResult.status === 'fulfilled';
    const ai = aiResult.status === 'fulfilled' && aiResult.value;
    const modelRegistry = registryResult.status === 'fulfilled' && registryResult.value;
    ready.set({ dependency: 'database' }, Number(database));
    ready.set({ dependency: 'redis' }, Number(redis));
    ready.set({ dependency: 'ai' }, Number(ai));
    ready.set({ dependency: 'model_registry' }, Number(modelRegistry));
    response.status(database && redis && ai && modelRegistry ? 200 : 503).json({
      ready: database && redis && ai && modelRegistry,
      checks: { database, redis, ai, modelRegistry },
    });
  });
  app.use((request, response, next) => {
    const started = performance.now();
    response.once('finish', () => {
      const method = ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS', 'HEAD'].includes(
        request.method,
      )
        ? request.method
        : 'OTHER';
      const route = request.route ? String(request.route.path) : 'unmatched';
      requests.inc({ method, route, status: String(response.statusCode) });
      latency.observe({ method, route }, (performance.now() - started) / 1000);
    });
    next();
  });
}
