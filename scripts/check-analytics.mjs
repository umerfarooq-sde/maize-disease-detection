import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdirSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { createApp } from '../backend/dist/app.js';
import { loadEnvironment } from '../backend/dist/config/environment.js';
import { createLogger } from '../backend/dist/config/logger.js';
import { createDatabaseClient } from '../backend/dist/database/client.js';
import { Prisma } from '../backend/dist/generated/prisma/client.js';
import { analyticsSummarySql, createAnalyticsRepository } from '../backend/dist/modules/analytics/analytics.repository.js';
import { createAnalyticsService } from '../backend/dist/modules/analytics/analytics.service.js';
import { resolveAnalyticsRange } from '../backend/dist/modules/analytics/analytics.types.js';
import { createAuthRepository } from '../backend/dist/modules/auth/auth.repository.js';
import { createAuthService } from '../backend/dist/modules/auth/auth.service.js';
import { createFertilizerRepository } from '../backend/dist/modules/fertilizer/fertilizer.repository.js';
import { createFertilizerService } from '../backend/dist/modules/fertilizer/fertilizer.service.js';
import { createGenerationClient } from '../backend/dist/modules/generation/generation.client.js';
import { createGenerationService } from '../backend/dist/modules/generation/generation.service.js';
import { createHealthRepository } from '../backend/dist/modules/health/health.repository.js';
import { createKnowledgeClient } from '../backend/dist/modules/knowledge/knowledge.client.js';
import { createKnowledgeRepository } from '../backend/dist/modules/knowledge/knowledge.repository.js';
import { createKnowledgeService } from '../backend/dist/modules/knowledge/knowledge.service.js';
import { createScanRepository } from '../backend/dist/modules/scans/scan.repository.js';
import { createScanService } from '../backend/dist/modules/scans/scan.service.js';
import { createYieldRepository } from '../backend/dist/modules/yield/yield.repository.js';
import { createYieldService } from '../backend/dist/modules/yield/yield.service.js';

// Opt-in synthetic PostgreSQL/API/Flutter contract. Every fixture write is private
// to ONE rollback transaction. No actual user data, model bytes, image, ML or AI call.
const environment = { ...loadEnvironment(), ANALYTICS_RATE_LIMIT_MAX: 1000 };
const database = createDatabaseClient(environment.DATABASE_URL, 30000);
const logger = createLogger({ LOG_LEVEL: 'silent' });
const rollback = new Error('ROLLBACK_SYNTHETIC_ANALYTICS_FIXTURE');
const range = { from: '2020-01-01', to: '2020-01-02' };
const labels = ['Common_Rust', 'Gray_Leaf_Spot', 'Healthy', 'Northern_Corn_Leaf_Blight'];
let server; let stage = 'inventory';
const inventory = async () => Promise.all([database.user.count(), database.authSession.count(), database.scan.count(),
  database.scanPrediction.count(), database.modelVersion.count(), database.history.count(), database.auditLog.count()]);
try {
  const before = await inventory();
  await assert.rejects(database.$transaction(async (transaction) => {
    const fixture = new Proxy(transaction, { get(target, key, receiver) {
      if (key === '$transaction') return (operation) => operation(transaction);
      return Reflect.get(target, key, receiver);
    } });
    const auth = createAuthRepository(fixture); const authService = createAuthService(environment, auth);
    const accounts = {}; const ids = {};
    stage = 'private accounts';
    for (const role of ['OWNER', 'OTHER', 'EMPTY', 'ADMIN']) {
      const account = { email: `synthetic-phase19-${randomUUID()}@example.invalid`, password: `synthetic-fixture-${randomUUID()}` };
      if (role === 'ADMIN') await authService.createAdmin(account); else await authService.register(account);
      accounts[role] = account; ids[role] = (await transaction.user.findUniqueOrThrow({ where: { email: account.email } })).id;
    }
    const models = [];
    for (const mapping of [labels, labels, ['Legacy_Condition', 'Legacy_Other']]) {
      const version = `phase19-synthetic-${randomUUID()}`;
      models.push(await transaction.modelVersion.create({ data: { version, architecture: 'SYNTHETIC_METADATA_ONLY',
        artifactUri: `synthetic://${version}`, artifactSha256: '0'.repeat(64), datasetVersion: 'SYNTHETIC_NO_DATASET',
        preprocessingVersion: 'SYNTHETIC_NO_PREPROCESSING', classLabels: mapping, trainingConfig: { synthetic: true } } }));
    }
    async function scan(userId, timestamp, status = 'PENDING') {
      const id = randomUUID();
      await transaction.$executeRaw`
        INSERT INTO scans (id,user_id,image_url,cloudinary_public_id,image_mime_type,image_bytes,uploaded_at,status,
                           error_code,finished_at,created_at,updated_at)
        VALUES (${id}::uuid,${userId}::uuid,'https://example.invalid/synthetic-analytics.png',${`synthetic-phase19/${id}`},
                'image/png',128,${timestamp}::timestamptz,${status}::"ScanStatus",
                ${status === 'FAILED' ? 'INFERENCE_FAILED' : null},
                CASE WHEN ${status} IN ('COMPLETED','FAILED') THEN ${timestamp}::timestamptz + interval '3 seconds' ELSE NULL END,
                ${timestamp}::timestamptz,${timestamp}::timestamptz)
      `;
      return id;
    }
    async function prediction(scanId, model, label, status = null, id = randomUUID(), timestamp = '2020-01-02T00:00:01Z') {
      const probability = model.classLabels.length === 4 ? 0.7 : 0.8;
      const other = model.classLabels.length === 4 ? 0.1 : 0.2;
      await transaction.scanPrediction.create({ data: { id, scanId, modelVersionId: model.id, predictedClass: label,
        confidence: probability, probabilities: Object.fromEntries(model.classLabels.map((item) => [item, item === label ? probability : other])),
        createdAt: new Date(timestamp), ...(status ? { predictionStatus: status,
          uncertaintyReason: status === 'LOW_CONFIDENCE' ? 'THRESHOLD_UNCONFIGURED' : null,
          confidenceThreshold: status === 'CONFIDENT' ? 0.5 : null, inferenceDurationMs: 0, inferredAt: new Date(timestamp) } : {}) } });
    }
    stage = 'synthetic statuses and historical predictions';
    const healthy = await scan(ids.OWNER, '2020-01-01T00:00:00Z', 'COMPLETED');
    await prediction(healthy, models[0], 'Healthy', 'LOW_CONFIDENCE', randomUUID(), '2020-01-01T00:00:01Z');
    const multi = await scan(ids.OWNER, '2020-01-01T12:00:00Z', 'COMPLETED');
    const predictionIds = [randomUUID(), randomUUID()].sort();
    await prediction(multi, models[0], 'Healthy', 'LOW_CONFIDENCE', predictionIds[0], '2020-01-01T12:00:01Z');
    await prediction(multi, models[1], 'Common_Rust', 'CONFIDENT', predictionIds[1], '2020-01-01T12:00:01Z');
    const missing = await scan(ids.OWNER, '2020-01-01T13:00:00Z', 'COMPLETED');
    const pending = await scan(ids.OWNER, '2020-01-01T14:00:00Z');
    const failed = await scan(ids.OWNER, '2020-01-01T23:59:59.999999Z', 'FAILED');
    await prediction(failed, models[0], 'Healthy'); // Historical row must not count while scan is failed.
    const gray = await scan(ids.OWNER, '2020-01-02T00:00:00.000550Z', 'COMPLETED');
    await prediction(gray, models[0], 'Gray_Leaf_Spot'); // Legacy certainty metadata remains unavailable.
    const legacy = await scan(ids.OWNER, '2020-01-02T00:00:00.000750Z', 'COMPLETED');
    await prediction(legacy, models[2], 'Legacy_Condition', 'LOW_CONFIDENCE');
    const processing = await scan(ids.OWNER, '2020-01-02T00:00:00.000950Z', 'PROCESSING');
    const foreign = await scan(ids.OTHER, '2020-01-02T12:00:00Z');
    const anonymous = await scan(null, '2020-01-02T13:00:00Z');
    const beforeFrom = await scan(ids.OWNER, '2019-12-31T23:59:59.999999Z');
    await scan(ids.OWNER, '2020-01-03T00:00:00Z');
    stage = 'aggregate ownership and boundaries';
    const repository = createAnalyticsRepository(fixture);
    const service = createAnalyticsService(repository);
    const summary = await service.summary(ids.OWNER, range);
    assert.deepEqual(summary.totals, { totalScans: 8, completedScans: 5, pendingScans: 1, processingScans: 1, failedScans: 1,
      withPrediction: 4, completedWithoutPrediction: 1, healthyPredictions: 1, diseasePredictions: 2, otherPredictions: 1 });
    assert.deepEqual(summary.uncertainty, { lowConfidence: 2, confident: 1, unavailable: 1 });
    assert.deepEqual(summary.daily, [{ date: '2020-01-01', count: 5 }, { date: '2020-01-02', count: 3 }]);
    assert.equal((await service.summary(ids.EMPTY, range)).totals.totalScans, 0);
    assert.equal((await service.summary(ids.OWNER, { from: '2020-01-02', to: '2020-01-02' })).totals.totalScans, 3);
    const expected = [processing, legacy, gray, failed, pending, missing, multi, healthy];
    const seen = []; let cursor;
    for (let pageIndex = 0; pageIndex < 4; pageIndex++) {
      const page = await service.activity(ids.OWNER, { ...range, limit: 2, cursor });
      seen.push(...page.items.map((item) => item.id)); cursor = page.nextCursor ?? undefined;
    }
    assert.deepEqual(seen, expected); assert.equal(cursor, undefined);
    for (const invalid of [foreign, anonymous, beforeFrom, randomUUID()])
      assert.equal(await repository.activity(ids.OWNER, resolveAnalyticsRange(range, new Date()), 2, invalid), null);
    assert.equal((await createScanRepository(fixture).findScan(multi)).predictions[0].predictedClass, 'Common_Rust');
    stage = 'query plan under unrelated and out-of-window volume';
    for (const [owner, count, timestamp] of [[ids.OTHER, 4000, '2020-01-02'], [null, 2000, '2020-01-02'], [ids.OWNER, 1000, '2019-01-01']]) {
      await transaction.$executeRaw`
        INSERT INTO scans (user_id,image_url,cloudinary_public_id,image_mime_type,image_bytes,uploaded_at,status,created_at,updated_at)
        SELECT ${owner}::uuid,'https://example.invalid/synthetic-volume.png','synthetic-phase19/' || gen_random_uuid()::text,
               'image/png',128,${timestamp}::timestamptz,'PENDING',${timestamp}::timestamptz,${timestamp}::timestamptz
        FROM generate_series(1,${count}::int)
      `;
    }
    const planRows = await transaction.$queryRaw(Prisma.sql`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ${analyticsSummarySql(ids.OWNER, resolveAnalyticsRange(range, new Date()))}`);
    const plan = planRows[0]['QUERY PLAN'][0]; const indexes = new Set();
    function walk(node) { if (node['Index Name']) indexes.add(node['Index Name']); for (const child of node.Plans ?? []) walk(child); }
    walk(plan.Plan);
    assert.equal((await service.summary(ids.OWNER, range)).totals.totalScans, 8);
    const evidence = { synthetic: true, bulkExcludedScans: 7000, eligibleScans: 8,
      aggregateStatements: 1, maximumDailyRows: 366, maximumDistributionRows: 5,
      executionTimeMs: plan['Execution Time'], planningTimeMs: plan['Planning Time'], indexes: [...indexes] };
    mkdirSync(new URL('../.cache/phase19/', import.meta.url), { recursive: true });
    writeFileSync(new URL('../.cache/phase19/query-plan.json', import.meta.url), JSON.stringify(evidence, null, 2) + '\n');
    console.log(JSON.stringify(evidence));
    const scans = createScanService(createScanRepository(fixture), {
      enabled: false, async upload() { throw new Error('No upload in analytics checks.'); },
      async destroy() { throw new Error('No cloud asset in analytics checks.'); },
    }, logger);
    const app = createApp(environment, logger, createHealthRepository(fixture), auth, scans,
      createKnowledgeService(createKnowledgeRepository(fixture), createKnowledgeClient(environment)),
      createGenerationService(scans, createGenerationClient(environment)),
      createFertilizerService(createFertilizerRepository(fixture)), createYieldService(createYieldRepository(fixture)), service);
    server = createServer(app); await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port; assert.ok(Number.isInteger(port));
    stage = 'real Flutter authenticated analytics contract';
    const args = ['test', '--no-pub', '--reporter', 'expanded', 'test/integration/analytics_test.dart',
      '--dart-define=RUN_LIVE_ANALYTICS_CHECK=true', `--dart-define=API_BASE_URL=http://127.0.0.1:${port}/api/v1`];
    const allowed = new Set(['PATH', 'PATHEXT', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA',
      'TEMP', 'TMP', 'HOME', 'PUB_CACHE', 'FLUTTER_ROOT', 'ANDROID_HOME', 'ANDROID_SDK_ROOT', 'JAVA_HOME', 'CI', 'TERM',
      'NO_COLOR', 'FLUTTER_SUPPRESS_ANALYTICS', 'DART_SUPPRESS_ANALYTICS']);
    const childEnvironment = Object.fromEntries(Object.entries(process.env).filter(([key]) => allowed.has(key.toUpperCase())));
    for (const role of ['OWNER', 'EMPTY', 'ADMIN']) {
      childEnvironment[`ANALYTICS_${role}_EMAIL`] = accounts[role].email;
      childEnvironment[`ANALYTICS_${role}_PASSWORD`] = accounts[role].password;
    }
    const windows = process.platform === 'win32';
    const child = spawn(windows ? 'cmd.exe' : 'flutter', windows ? ['/d', '/s', '/c', `flutter.bat ${args.join(' ')}`] : args, {
      cwd: fileURLToPath(new URL('../mobile', import.meta.url)), windowsHide: true,
      env: { ...childEnvironment, ANALYTICS_FOREIGN_CURSOR: foreign, ANALYTICS_ANONYMOUS_CURSOR: anonymous }, stdio: ['ignore', 'pipe', 'pipe'],
    });
    child.stdout.on('data', (data) => process.stdout.write(data)); child.stderr.on('data', (data) => process.stderr.write(data));
    const deadline = setTimeout(() => child.kill(), 300000);
    try { const [code] = await once(child, 'exit'); assert.equal(code, 0, 'Live Flutter analytics contract'); }
    finally { clearTimeout(deadline); }
    console.log('PASS: real aggregate/status/latest-model/UTC/microsecond/cursor/ownership/query-plan and Flutter API contracts.');
    throw rollback;
  }, { maxWait: 10000, timeout: 600000, isolationLevel: 'RepeatableRead' }), (error) => error === rollback);
  assert.deepEqual(await inventory(), before);
  console.log('PASS: every synthetic account/session/scan/prediction/model record rolled back; existing user data and anonymous ownership unchanged.');
} catch (error) {
  console.error(`Analytics contract failed at ${stage}; connection values and credentials are not logged.`);
  if (error instanceof assert.AssertionError) console.error(error.message);
  process.exitCode = 1;
} finally {
  if (server) await new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); });
  await database.$disconnect();
}
