// Native phone launcher probes. Only allowlisted, non-secret JSON leaves this process.
import { loadEnvironment } from '../backend/src/config/environment.js';
import { createDatabaseClient } from '../backend/src/database/client.js';
import { createHealthRepository } from '../backend/src/modules/health/health.repository.js';
import { redisQuotaStore } from '../backend/src/infrastructure/quotas.js';

let stage = 'CONFIGURATION';
const started = performance.now();

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new Error('INVALID_HEALTH_RESPONSE');
  return value as Record<string, unknown>;
}

async function main() {
  const config = loadEnvironment();
  if (config.NODE_ENV !== 'development') throw new Error('DEVELOPMENT_CONFIGURATION_REQUIRED');
  if (!['127.0.0.1', 'localhost', '::1'].includes(config.HOST))
    throw new Error('LOOPBACK_NODE_BIND_REQUIRED');
  const ai = new URL(config.AI_SERVICE_URL);
  if (ai.protocol !== 'http:' || !['127.0.0.1', 'localhost', '[::1]'].includes(ai.hostname))
    throw new Error('LOOPBACK_AI_ORIGIN_REQUIRED');
  const origin = `http://${config.HOST === '::1' ? '[::1]' : config.HOST}:${config.PORT}`;
  if (process.argv[2] === 'config') {
    return {
      origin,
      port: config.PORT,
      aiOrigin: ai.origin,
      modelVersion: config.AI_MODEL_VERSION,
      preprocessingVersion: config.AI_PREPROCESSING_VERSION,
      redisRequired: Boolean(config.REDIS_URL),
      operationsConfigured: Boolean(config.OPERATIONS_TOKEN),
      cloudinaryConfigured: Boolean(config.CLOUDINARY_API_SECRET),
      shutdownSeconds: config.SHUTDOWN_TIMEOUT_MS / 1000,
    };
  }
  if (process.argv[2] === 'dependencies') {
    const database = createDatabaseClient(config.DATABASE_URL);
    const quota = config.REDIS_URL ? redisQuotaStore(config.REDIS_URL, { warn() {} }) : undefined;
    try {
      const health = createHealthRepository(database);
      stage = 'DATABASE_QUERY';
      await health.checkDatabase();
      stage = 'MODEL_REGISTRY';
      await health.checkModelVersion?.(config.AI_MODEL_VERSION, config.AI_PREPROCESSING_VERSION);
      stage = 'PGVECTOR';
      const vector = await database.$queryRaw<Array<{ present: boolean }>>`
        SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname='vector') AS present`;
      if (!vector[0]?.present) throw new Error('PGVECTOR_UNAVAILABLE');
      stage = 'REDIS';
      await quota?.start();
      if (quota && !quota.ready()) throw new Error('CONFIGURED_REDIS_UNAVAILABLE');
      return {
        database: 'up',
        modelRegistry: 'compatible',
        pgvector: 'installed',
        redis: quota ? 'up' : 'not_configured',
      };
    } finally {
      await quota?.close();
      await database.$disconnect();
    }
  }
  if (process.argv[2] !== 'health') throw new Error('UNKNOWN_PROBE');
  stage = 'NODE_HEALTH';
  const response = await fetch(`${origin}/api/v1/health`, {
    redirect: 'error',
    signal: AbortSignal.timeout(15000),
  });
  const result = record(await response.json());
  const data = record(result.data);
  if (
    !response.ok ||
    result.success !== true ||
    data.service !== 'maizedoctor-backend' ||
    data.status !== 'ok' ||
    record(data.checks).database !== 'up'
  )
    throw new Error('NODE_HEALTH_NOT_READY');
  stage = 'AI_SERVICE';
  const aiResponse = await fetch(`${config.AI_SERVICE_URL}/api/v1/model-health`, {
    headers: { Authorization: `Bearer ${config.AI_SERVICE_TOKEN}` },
    redirect: 'error',
    signal: AbortSignal.timeout(10000),
  });
  const aiBody = record(await aiResponse.json());
  const aiData = record(aiBody.data);
  if (
    !aiResponse.ok ||
    aiBody.success !== true ||
    aiData.status !== 'ready' ||
    aiData.modelVersion !== config.AI_MODEL_VERSION ||
    aiData.preprocessingVersion !== config.AI_PREPROCESSING_VERSION
  )
    throw new Error('NODE_AI_AUTH_OR_MODEL_NOT_READY');
  if (config.OPERATIONS_TOKEN) {
    stage = 'NODE_READINESS';
    const ready = await fetch(`${origin}/internal/ready`, {
      headers: { 'X-Operations-Token': config.OPERATIONS_TOKEN },
      redirect: 'error',
      signal: AbortSignal.timeout(20000),
    });
    const body = record(await ready.json());
    const checks = record(body.checks);
    if (
      !ready.ok ||
      body.ready !== true ||
      !['database', 'redis', 'ai', 'modelRegistry'].every((key) => checks[key] === true)
    )
      throw new Error('NODE_DEPENDENCIES_NOT_READY');
  }
  return {
    status: 'ready',
    database: 'up',
    protectedReadiness: config.OPERATIONS_TOKEN ? 'passed' : 'not_configured',
  };
}

try {
  console.log(JSON.stringify({ ok: true, data: await main() }));
} catch (error) {
  // Driver/validation messages can contain submitted values. Expose codes only.
  const code =
    error instanceof Error && /^[A-Z_]{3,80}$/.test(error.message)
      ? error.message
      : 'BACKEND_PROBE_FAILED';
  const message = error instanceof Error ? error.message.toLowerCase() : '';
  const category = /timeout|timed out/.test(message)
    ? 'TIMEOUT'
    : /enotfound|eai_again/.test(message)
      ? 'DNS'
      : /certificate|tls|ssl/.test(message)
        ? 'TLS'
        : /econnrefused|connection|econnreset/.test(message)
          ? 'CONNECTION'
          : /authentication|28p01/.test(message)
            ? 'AUTHENTICATION'
            : 'UNAVAILABLE';
  console.log(
    JSON.stringify({
      ok: false,
      code,
      stage,
      category,
      elapsedMs: Math.round(performance.now() - started),
    }),
  );
  process.exitCode = 1;
}
