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
import { createYieldRepository } from '../backend/dist/modules/yield/yield.repository.js';
import { createYieldService } from '../backend/dist/modules/yield/yield.service.js';

// Synthetic development contract, only while production yield configuration is empty.
// All account/config/session/audit writes are private to one outer rollback transaction.
// No AI/provider/cloud/source fetching, raw dataset access or real yield approval.
const environment = { ...loadEnvironment(), CALCULATOR_RATE_LIMIT_MAX: 100 };
const database = createDatabaseClient(environment.DATABASE_URL, 30000);
const logger = createLogger({ LOG_LEVEL: 'silent' });
const rollback = new Error('ROLLBACK_SYNTHETIC_YIELD_FIXTURE');
let server;
let stage = 'inventory';
const inventory = async () => Promise.all([
  database.calculatorConfig.count({ where: { kind: 'YIELD' } }), database.user.count(),
  database.authSession.count(), database.auditLog.count(), database.history.count(),
  database.calculatorConfig.count({ where: { kind: 'FERTILIZER' } }),
]);
try {
  const before = await inventory();
  assert.equal(before[0], 0, 'Run this development check before real yield configurations are published.');
  await assert.rejects(database.$transaction(async (transaction) => {
    const fixture = new Proxy(transaction, { get(target, key, receiver) {
      if (key === '$transaction') return (operation) => operation(transaction);
      return Reflect.get(target, key, receiver);
    } });
    const auth = createAuthRepository(fixture);
    const authService = createAuthService(environment, auth);
    const accounts = {};
    stage = 'fixture authentication';
    for (const role of ['ADMIN', 'FARMER']) {
      const account = { email: `synthetic-phase18-${randomUUID()}@example.invalid`, password: `synthetic-fixture-${randomUUID()}` };
      if (role === 'ADMIN') await authService.createAdmin(account); else await authService.register(account);
      accounts[role] = account;
    }
    const administrator = await transaction.user.findUniqueOrThrow({ where: { email: accounts.ADMIN.email } });
    const scans = createScanService(createScanRepository(fixture), {
      enabled: false, async upload() { throw new Error('No image upload in yield checks.'); },
      async destroy() { throw new Error('No cloud asset in yield checks.'); },
    }, logger);
    const app = createApp(environment, logger, createHealthRepository(fixture), auth, scans,
      createKnowledgeService(createKnowledgeRepository(fixture), createKnowledgeClient(environment)),
      createGenerationService(scans, createGenerationClient(environment)),
      createFertilizerService(createFertilizerRepository(fixture)), createYieldService(createYieldRepository(fixture)));
    server = createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port; assert.ok(Number.isInteger(port));
    const base = `http://127.0.0.1:${port}/api/v1`;
    async function request(path, { method = 'GET', body, token, status = 200 } = {}) {
      const response = await fetch(base + path, { method, redirect: 'error', signal: AbortSignal.timeout(30000),
        headers: { 'X-Auth-Request': '1', ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
      assert.equal(response.status, status, `HTTP ${method} ${path}`);
      const result = await response.json(); return status < 400 ? result.data : result.error;
    }
    const path = '/calculators/yield'; const admin = '/admin/calculators/yield/configurations';
    stage = 'pending catalogue and role protection';
    assert.equal((await request(`${path}/configurations`)).status, 'PENDING_CONFIGURATION');
    await request(admin, { status: 401 });
    const token = (await request('/auth/login', { method: 'POST', body: accounts.ADMIN })).accessToken;
    const draft = { version: 1, title: 'SYNTHETIC dimensional test; not agricultural advice',
      expectedYieldKgPerHectare: '50', applicability: 'Synthetic tests only; no field applicability.',
      assumptions: ['Arithmetic fixture only; not agricultural advice.'],
      source: { title: 'Synthetic source fixture', publisher: 'Test suite', url: 'https://example.invalid/synthetic-yield',
        citation: 'Synthetic arithmetic fixture; not agricultural advice or authoritative yield data.' },
      quantityDecimalPlaces: 3, reviewNote: 'Synthetic private test attestation only; no real agronomic approval.' };
    stage = 'reviewed draft and atomic activation';
    const created = await request(admin, { method: 'POST', body: draft, token, status: 201 });
    assert.equal(created.status, 'DRAFT');
    assert.equal((await request(`${path}/configurations`)).items.length, 0);
    await request(admin, { method: 'POST', body: draft, token, status: 409 });
    const persisted = await transaction.calculatorConfig.findUniqueOrThrow({ where: { id: created.id } });
    assert.equal(persisted.parameters.approval.reviewedBy, administrator.id);
    assert.equal(persisted.sourceReference, draft.source.url);
    await request(`${admin}/${created.id}/status`, { method: 'PATCH', body: { status: 'ACTIVE' }, token });
    stage = 'real immutable payload and active-version guards';
    async function sqlRejects(sql, values, expectedCode) {
      await transaction.$executeRawUnsafe('SAVEPOINT yield_guard');
      try {
        await assert.rejects(transaction.$executeRawUnsafe(sql, ...values), (error) => {
          const code = error.meta?.code ?? error.meta?.driverAdapterError?.cause?.originalCode;
          assert.equal(code, expectedCode); return true;
        });
      } finally {
        await transaction.$executeRawUnsafe('ROLLBACK TO SAVEPOINT yield_guard');
        await transaction.$executeRawUnsafe('RELEASE SAVEPOINT yield_guard');
      }
    }
    await sqlRejects("UPDATE calculator_configs SET parameters='{}'::jsonb WHERE id=$1::uuid", [created.id], '23514');
    await sqlRejects(`INSERT INTO calculator_configs (kind,config_key,version,parameters,unit,source_reference,status)
      VALUES ('YIELD','maize-area-yield',99,'{}','kg/ha','SYNTHETIC TEST','ACTIVE')`, [], '23505');
    const input = { area: '2', areaUnit: 'ACRE', outputUnit: 'KG', configId: created.id, configVersion: 1 };
    assert.equal((await request(`${path}/calculate`, { method: 'POST', body: input })).expectedYield.value, '40.469');
    stage = 'Flutter to Node to real PostgreSQL';
    const args = ['test', '--no-pub', '--reporter', 'expanded', 'test/integration/yield_test.dart',
      '--dart-define=RUN_LIVE_YIELD_CHECK=true', `--dart-define=API_BASE_URL=${base}`];
    const allowed = new Set(['PATH', 'PATHEXT', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'USERPROFILE',
      'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'HOME', 'PUB_CACHE', 'FLUTTER_ROOT',
      'ANDROID_HOME', 'ANDROID_SDK_ROOT', 'JAVA_HOME', 'CI', 'TERM', 'NO_COLOR',
      'FLUTTER_SUPPRESS_ANALYTICS', 'DART_SUPPRESS_ANALYTICS']);
    const childEnvironment = Object.fromEntries(Object.entries(process.env).filter(([key]) => allowed.has(key.toUpperCase())));
    const windows = process.platform === 'win32';
    const child = spawn(windows ? 'cmd.exe' : 'flutter', windows ? ['/d', '/s', '/c', `flutter.bat ${args.join(' ')}`] : args, {
      cwd: fileURLToPath(new URL('../mobile', import.meta.url)), windowsHide: true,
      env: { ...childEnvironment, YIELD_FIXTURE_CONFIG_ID: created.id,
        YIELD_FIXTURE_EMAIL: accounts.FARMER.email, YIELD_FIXTURE_PASSWORD: accounts.FARMER.password },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    child.stdout.on('data', (data) => process.stdout.write(data)); child.stderr.on('data', (data) => process.stderr.write(data));
    const deadline = setTimeout(() => child.kill(), 300000);
    try { const [code] = await once(child, 'exit'); assert.equal(code, 0, 'Live Flutter yield contract'); }
    finally { clearTimeout(deadline); }
    stage = 'version replacement and retirement';
    const replacement = await request(admin, { method: 'POST', body: { ...draft, version: 2, expectedYieldKgPerHectare: '25', quantityDecimalPlaces: 2 }, token, status: 201 });
    await request(`${admin}/${replacement.id}/status`, { method: 'PATCH', body: { status: 'ACTIVE' }, token });
    await request(`${path}/calculate`, { method: 'POST', body: input, status: 409 });
    const v2 = await request(`${path}/calculate`, { method: 'POST', body: { ...input, configId: replacement.id, configVersion: 2 } });
    assert.equal(v2.expectedYield.value, '20.23'); assert.equal(v2.configuration.version, 2);
    const old = await transaction.calculatorConfig.findUniqueOrThrow({ where: { id: created.id } });
    assert.equal(old.status, 'INACTIVE'); assert.deepEqual(old.parameters, persisted.parameters);
    await request(`${admin}/${replacement.id}/status`, { method: 'PATCH', body: { status: 'INACTIVE' }, token });
    assert.equal((await request(`${path}/configurations`)).status, 'PENDING_CONFIGURATION');
    assert.equal(await transaction.auditLog.count({ where: { actorId: administrator.id, entityType: 'yield_configuration' } }), 5);
    console.log('PASS: Node/Prisma/PostgreSQL draft/source/review/audit/immutable payload/one-active/version retirement; real Flutter guest/farmer exact-unit contract.');
    throw rollback;
  }, { maxWait: 10000, timeout: 600000, isolationLevel: 'RepeatableRead' }), (error) => error === rollback);
  assert.deepEqual(await inventory(), before);
  console.log('PASS: all synthetic configuration/account/session/audit writes rolled back; production yield configuration remains empty/PENDING_CONFIGURATION.');
} catch {
  console.error(`Yield contract failed at ${stage}; connection values and credentials are not logged.`); process.exitCode = 1;
} finally {
  if (server) await new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); });
  await database.$disconnect();
}
