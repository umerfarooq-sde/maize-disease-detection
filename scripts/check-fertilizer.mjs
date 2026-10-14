import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { createApp } from '../backend/dist/app.js';
import { loadEnvironment } from '../backend/dist/config/environment.js';
import { createLogger } from '../backend/dist/config/logger.js';
import { createDatabaseClient } from '../backend/dist/database/client.js';
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

// Opt-in development contract for the current empty recommendation catalogue.
// Every synthetic account/rule/config/audit write belongs to ONE outer rollback
// transaction. Other clients cannot see them. No recommendation is ever committed.
// No AI, Cloudinary, dataset access or source-URL fetch is performed.
const environment = { ...loadEnvironment(), CALCULATOR_RATE_LIMIT_MAX: 100 };
const database = createDatabaseClient(environment.DATABASE_URL, 30000);
const rollback = new Error('ROLLBACK_SYNTHETIC_CALCULATOR_FIXTURE');
const logger = createLogger({ LOG_LEVEL: 'silent' });
let stage = 'connect';
let server;
const inventory = async () => Promise.all([
  database.fertilizer.count(), database.fertilizerRule.count(),
  database.calculatorConfig.count({ where: { kind: 'FERTILIZER' } }),
]);
try {
  const before = await inventory();
  assert.deepEqual(before, [0, 0, 0], 'Use this check only before real recommendations are published.');
  stage = 'rollback fixture';
  await assert.rejects(database.$transaction(async (transaction) => {
    // Bind all real repositories/HTTP requests to this same private transaction.
    // Nested metadata operations run within it instead of opening/committing one.
    const fixtureDatabase = new Proxy(transaction, {
      get(target, property, receiver) {
        if (property === '$transaction') return (operation) => operation(transaction);
        return Reflect.get(target, property, receiver);
      },
    });
    const auth = createAuthRepository(fixtureDatabase);
    const authService = createAuthService(environment, auth);
    const credentials = {};
    for (const role of ['ADMIN', 'FARMER']) {
      const account = {
        email: `synthetic-phase17-${randomUUID()}@example.invalid`,
        password: `synthetic-fixture-${randomUUID()}`,
      };
      if (role === 'ADMIN') await authService.createAdmin(account);
      else await authService.register(account);
      credentials[role] = account;
    }
    const administrator = await transaction.user.findUniqueOrThrow({
      where: { email: credentials.ADMIN.email },
    });
    const storage = {
      enabled: false,
      async upload() { throw new Error('Calculator checks never upload images.'); },
      async destroy() { throw new Error('Calculator checks never create cloud assets.'); },
    };
    const scans = createScanService(createScanRepository(fixtureDatabase), storage, logger);
    const fertilizer = createFertilizerService(createFertilizerRepository(fixtureDatabase));
    const app = createApp(environment, logger, createHealthRepository(fixtureDatabase), auth, scans,
      createKnowledgeService(createKnowledgeRepository(fixtureDatabase), createKnowledgeClient(environment)),
      createGenerationService(scans, createGenerationClient(environment)), fertilizer);
    server = createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    assert.ok(Number.isInteger(port));
    const base = `http://127.0.0.1:${port}/api/v1`;
    async function request(path, { method = 'GET', body, token, status = 200 } = {}) {
      const response = await fetch(base + path, {
        method, redirect: 'error', signal: AbortSignal.timeout(30000),
        headers: {
          'X-Auth-Request': '1',
          ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
      });
      assert.equal(response.status, status, `HTTP ${method} ${path}`);
      const result = await response.json();
      return status < 400 ? result.data : result.error;
    }
    const prefix = '/admin/calculators/fertilizer/rules';
    stage = 'pending catalogue and RBAC';
    assert.equal((await request('/calculators/fertilizer/rules')).status, 'PENDING_RULES');
    await request(prefix, { status: 401 });
    const admin = await request('/auth/login', { method: 'POST', body: credentials.ADMIN });
    const token = admin.accessToken;
    const marker = randomUUID();
    const draft = {
      product: {
        slug: `synthetic-phase17-${marker}`, name: 'SYNTHETIC arithmetic fixture; NOT agricultural advice',
        description: 'Only visible inside the private rolled-back test transaction.',
        nitrogenPercent: '0', phosphorusPercent: '0', potassiumPercent: '0',
        applicationMethod: null, precautions: [],
        sourceReference: 'https://example.invalid/synthetic-product',
      },
      rule: {
        ruleKey: 'synthetic-test-only', version: 1, title: 'Synthetic arithmetic fixture only',
        rateKgPerHectare: '50', applicability: 'No field applicability; synthetic test only.',
        assumptions: ['Synthetic arithmetic fixture; not agricultural advice.'],
        source: { title: 'Synthetic source fixture', publisher: 'Synthetic test publisher',
          url: 'https://example.invalid/synthetic-rate',
          citation: 'Synthetic fixture; not agricultural advice or an approved fertilizer recommendation.' },
        reviewNote: 'Synthetic isolated test attestation; no actual agronomic approval is implied.',
      },
      config: { version: 1, quantityDecimalPlaces: 3 },
    };
    stage = 'draft, immutable identity and activation';
    const created = await request(prefix, { method: 'POST', body: draft, token, status: 201 });
    assert.equal(created.status, 'DRAFT');
    assert.equal((await request('/calculators/fertilizer/rules')).items.length, 0);
    await request(prefix, { method: 'POST', body: draft, token, status: 409 });
    const persisted = await transaction.fertilizerRule.findUniqueOrThrow({ where: { id: created.id } });
    assert.equal(persisted.parameters.approval.reviewedBy, administrator.id);
    assert.equal(persisted.parameters.source.citation, draft.rule.source.citation);
    await request(`${prefix}/${created.id}/status`, { method: 'PATCH', body: { status: 'ACTIVE' }, token });
    const catalogue = await request('/calculators/fertilizer/rules');
    assert.equal(catalogue.items.length, 1);
    const active = catalogue.items[0];
    assert.equal(active.id, created.id);
    const input = { area: '2', areaUnit: 'ACRE', outputUnit: 'KG', ruleId: active.id,
      ruleVersion: 1, configVersion: 1 };
    assert.equal((await request('/calculators/fertilizer/calculate', { method: 'POST', body: input })).quantity.value, '40.469');
    await request('/calculators/fertilizer/calculate', { method: 'POST', body: { ...input, rateKgPerHectare: '900' }, status: 400 });
    stage = 'Flutter to Node to real PostgreSQL';
    const args = ['test', '--no-pub', '--reporter', 'expanded', 'test/integration/fertilizer_test.dart',
      '--dart-define=RUN_LIVE_FERTILIZER_CHECK=true', `--dart-define=API_BASE_URL=${base}`];
    const allowed = new Set(['PATH', 'PATHEXT', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'USERPROFILE',
      'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'HOME', 'PUB_CACHE', 'FLUTTER_ROOT',
      'ANDROID_HOME', 'ANDROID_SDK_ROOT', 'JAVA_HOME', 'CI', 'TERM', 'NO_COLOR',
      'FLUTTER_SUPPRESS_ANALYTICS', 'DART_SUPPRESS_ANALYTICS']);
    const childEnvironment = Object.fromEntries(Object.entries(process.env)
      .filter(([key]) => allowed.has(key.toUpperCase())));
    const windows = process.platform === 'win32';
    const child = spawn(windows ? 'cmd.exe' : 'flutter',
      windows ? ['/d', '/s', '/c', `flutter.bat ${args.join(' ')}`] : args, {
        cwd: fileURLToPath(new URL('../mobile', import.meta.url)), windowsHide: true,
        env: { ...childEnvironment,
          FERTILIZER_FIXTURE_RULE_ID: created.id,
          FERTILIZER_FIXTURE_FARMER_EMAIL: credentials.FARMER.email,
          FERTILIZER_FIXTURE_FARMER_PASSWORD: credentials.FARMER.password },
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    child.stdout.on('data', (data) => process.stdout.write(data));
    child.stderr.on('data', (data) => process.stderr.write(data));
    const deadline = setTimeout(() => child.kill(), 300000);
    try {
      const [code] = await once(child, 'exit');
      assert.equal(code, 0, 'Live Flutter calculator contract');
    } finally { clearTimeout(deadline); }
    stage = 'version replacement and product drift';
    const next = structuredClone(draft);
    next.rule.version = 2;
    next.rule.rateKgPerHectare = '25';
    next.config.version = 2;
    next.config.quantityDecimalPlaces = 2;
    const replacement = await request(prefix, { method: 'POST', body: next, token, status: 201 });
    await request(`${prefix}/${replacement.id}/status`, { method: 'PATCH', body: { status: 'ACTIVE' }, token });
    await request('/calculators/fertilizer/calculate', { method: 'POST', body: input, status: 409 });
    const current = (await request('/calculators/fertilizer/rules')).items[0];
    assert.equal(current.version, 2);
    assert.equal(current.config.version, 2);
    const v2input = { ...input, ruleId: replacement.id, ruleVersion: 2, configVersion: 2 };
    assert.equal((await request('/calculators/fertilizer/calculate', { method: 'POST', body: v2input })).quantity.value, '20.23');
    const old = await transaction.fertilizerRule.findUniqueOrThrow({ where: { id: created.id } });
    assert.equal(old.status, 'INACTIVE');
    assert.deepEqual(old.parameters, persisted.parameters);
    await transaction.fertilizer.update({ where: { id: old.fertilizerId }, data: { name: 'Changed product must invalidate its immutable rule snapshot' } });
    assert.equal((await request('/calculators/fertilizer/rules')).status, 'PENDING_RULES');
    await request('/calculators/fertilizer/calculate', { method: 'POST', body: v2input, status: 503 });
    await transaction.fertilizer.update({ where: { id: old.fertilizerId }, data: { name: draft.product.name } });
    await request(`${prefix}/${replacement.id}/status`, { method: 'PATCH', body: { status: 'INACTIVE' }, token });
    assert.equal((await request('/calculators/fertilizer/rules')).status, 'PENDING_RULES');
    const audit = await transaction.auditLog.findMany({ where: { actorId: administrator.id, entityType: 'fertilizer_rule' } });
    assert.equal(audit.length, 5);
    assert.deepEqual(new Set(audit.map((entry) => entry.action)), new Set(['CREATE', 'ACTIVATE', 'DEACTIVATE']));
    console.log('PASS: real HTTP/Prisma/PostgreSQL draft/publication/source/audit/immutable replacement/drift checks; guest/farmer Flutter exact-unit contract.');
    throw rollback;
  }, { maxWait: 10000, timeout: 600000, isolationLevel: 'RepeatableRead' }),
  (error) => error === rollback);
  assert.deepEqual(await inventory(), before);
  console.log('PASS: all synthetic writes rolled back; production catalogue remains empty/PENDING_RULES.');
} catch {
  console.error(`Fertilizer contract failed at ${stage}; connection values and credentials are not logged.`);
  process.exitCode = 1;
} finally {
  if (server) await new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); });
  await database.$disconnect();
}
