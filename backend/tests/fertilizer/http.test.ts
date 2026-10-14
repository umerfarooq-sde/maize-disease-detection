import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { parseEnvironment } from '../../src/config/environment.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { createFertilizerService } from '../../src/modules/fertilizer/fertilizer.service.js';
import type {
  FertilizerCatalogue,
  FertilizerResult,
} from '../../src/modules/fertilizer/fertilizer.types.js';
import { createGenerationService } from '../../src/modules/generation/generation.service.js';
import { createKnowledgeService } from '../../src/modules/knowledge/knowledge.service.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { fakeGeneration } from '../generation/helpers.js';
import { memoryKnowledge } from '../knowledge/helpers.js';
import { fakeInference, fakeStorage, memoryScans } from '../scans/helpers.js';
import { fertilizerInput, memoryFertilizer } from './helpers.js';

function fixture(limit = 1000) {
  const environment = { ...testEnvironment, CALCULATOR_RATE_LIMIT_MAX: limit };
  const auth = memoryRepository();
  const authService = createAuthService(environment, auth.repository);
  const scans = createScanService(
    memoryScans().repository,
    fakeStorage().storage,
    silentLogger,
    fakeInference().client,
  );
  const knowledge = memoryKnowledge();
  const generated = fakeGeneration();
  const fertilizer = memoryFertilizer();
  const service = createFertilizerService(fertilizer.repository);
  const app = createApp(
    environment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    scans,
    createKnowledgeService(knowledge.repository, knowledge.client),
    createGenerationService(scans, generated.client),
    service,
  );
  return { app, auth, authService, fertilizer, service, generated, knowledge };
}

async function payload<T>(response: Response, status = 200, code?: string) {
  assert.equal(response.status, status);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const body = (await response.json()) as {
    success: boolean;
    requestId: string;
    data: T;
    error?: { code: string; message: string };
  };
  assert.equal(body.success, status < 400);
  assert.equal(body.requestId, response.headers.get('x-request-id'));
  assert.deepEqual(
    Object.keys(body).sort(),
    status < 400 ? ['data', 'requestId', 'success'] : ['error', 'requestId', 'success'],
  );
  if (code) assert.equal(body.error?.code, code);
  for (const privateField of [
    'reviewedBy',
    'passwordHash',
    'createdById',
    'parameters',
    'stack',
    'private-database-secret',
  ])
    assert.ok(!JSON.stringify(body).includes(privateField));
  return body;
}
function post(url: string, path: string, body: unknown, token?: string, method = 'POST') {
  return fetch(`${url}/api/v1${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}
const publicPath = '/calculators/fertilizer';
const adminPath = '/admin/calculators/fertilizer/rules';

test('guest calculator returns exact deterministic quantities, source, versions and assumptions without AI', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    const catalogue = await payload<FertilizerCatalogue>(
      await fetch(`${url}/api/v1${publicPath}/rules`),
    );
    assert.equal(catalogue.data.status, 'READY');
    assert.equal(catalogue.data.items[0]?.rateKgPerHectare, '10');
    const input = fertilizerInput(setup.fertilizer.rule.id);
    const result = await payload<FertilizerResult>(
      await post(url, `${publicPath}/calculate`, input),
    );
    assert.deepEqual(result.data.input, input);
    assert.equal(result.data.quantity.value, '15.000');
    assert.equal(result.data.quantity.unit, 'KG');
    assert.equal(result.data.rule.version, 1);
    assert.equal(result.data.rule.config.version, 1);
    assert.deepEqual(result.data.rule.source, setup.fertilizer.draft.rule.source);
    assert.ok(result.data.assumptions.length);
    const grams = await payload<FertilizerResult>(
      await post(url, `${publicPath}/calculate`, { ...input, outputUnit: 'G' }),
    );
    assert.equal(grams.data.quantity.value, '15000.000');
    const acres = await payload<FertilizerResult>(
      await post(url, `${publicPath}/calculate`, { ...input, area: '1', areaUnit: 'ACRE' }),
    );
    assert.equal(acres.data.normalizedArea.value, '0.40468564224');
    assert.equal(acres.data.quantity.unroundedValue, '4.0468564224');
    setup.fertilizer.records.rules.length = 0;
    const pending = await payload<FertilizerCatalogue>(
      await fetch(`${url}/api/v1${publicPath}/rules`),
    );
    assert.equal(pending.data.status, 'PENDING_RULES');
    assert.deepEqual(pending.data.items, []);
    assert.equal(setup.generated.asks.length, 0);
    assert.equal(setup.generated.explanations.length, 0);
    assert.equal(setup.knowledge.searches.length, 0);
  });
});

test('calculator rejects missing, negative, impossible, mixed/ambiguous units and numeric coercion', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    const valid = fertilizerInput(setup.fertilizer.rule.id);
    const invalid: unknown[] = [
      {},
      { ...valid, area: undefined },
      { ...valid, area: 1 },
      ...[
        '',
        '0',
        '0.000000',
        '-1',
        '-0.1',
        '1e2',
        '1,5',
        '1,000',
        '01',
        'Infinity',
        'NaN',
        '1000000.000001',
        '1.1234567',
        '9'.repeat(1000),
      ].map((area) => ({ ...valid, area })),
      { ...valid, areaUnit: 'acre' },
      { ...valid, areaUnit: 'M2' },
      { ...valid, outputUnit: 'TONNE' },
      { ...valid, outputUnit: 'g' },
      { ...valid, ruleId: 'unknown' },
      { ...valid, ruleVersion: 0 },
      { ...valid, ruleVersion: '1' },
      { ...valid, ruleVersion: 1.1 },
      { ...valid, configVersion: 2147483648 },
      { ...valid, configVersion: -1 },
      { ...valid, rateKgPerHectare: '999' },
      { ...valid, crop: 'WHEAT' },
      { ...valid, userId: randomUUID() },
      { ...valid, geminiResult: '100' },
    ];
    for (const body of invalid)
      await payload(await post(url, `${publicPath}/calculate`, body), 400, 'VALIDATION_ERROR');
    assert.equal(setup.fertilizer.reads.length, 0);
    await payload(
      await post(url, `${publicPath}/calculate?ruleVersion=2`, valid),
      400,
      'VALIDATION_ERROR',
    );
    await payload(
      await fetch(`${url}/api/v1${publicPath}/rules?include=draft`),
      400,
      'VALIDATION_ERROR',
    );
    const boundary = await payload<FertilizerResult>(
      await post(url, `${publicPath}/calculate`, { ...valid, area: '1000000', outputUnit: 'G' }),
    );
    assert.equal(boundary.data.quantity.value, '10000000000.000');
  });
});

test('stale versions and incompatible active rules return reload/safe-unavailable errors', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    const valid = fertilizerInput(setup.fertilizer.rule.id);
    for (const input of [
      { ...valid, ruleId: randomUUID() },
      { ...valid, ruleVersion: 2 },
      { ...valid, configVersion: 2 },
    ])
      await payload(
        await post(url, `${publicPath}/calculate`, input),
        409,
        'FERTILIZER_CONFIGURATION_CHANGED',
      );
    setup.fertilizer.rule.parameters = {};
    await payload(
      await post(url, `${publicPath}/calculate`, valid),
      503,
      'FERTILIZER_CONFIGURATION_INVALID',
    );
    const catalogue = await payload<FertilizerCatalogue>(
      await fetch(`${url}/api/v1${publicPath}/rules`),
    );
    assert.equal(catalogue.data.status, 'PENDING_RULES');
    assert.deepEqual(catalogue.data.items, []);
  });
});

test('only authenticated ADMIN can create reviewed drafts and control status; actor is server-owned', async () => {
  const setup = fixture();
  const admin = {
    email: 'admin-fertilizer@example.invalid',
    password: 'correct horse battery staple',
  };
  const farmer = { email: 'farmer-fertilizer@example.invalid', password: admin.password };
  await setup.authService.createAdmin(admin);
  await setup.authService.register(farmer);
  const adminGrant = await setup.authService.login(admin);
  const farmerGrant = await setup.authService.login(farmer);
  const actorId = setup.auth.accounts.get(admin.email)?.id;
  assert.ok(actorId);
  await withServer(setup.app, async (url) => {
    const draft = setup.fertilizer.draft;
    const statusPath = `${adminPath}/${setup.fertilizer.rule.id}/status`;
    for (const [token, status, code] of [
      [undefined, 401, 'AUTHENTICATION_ERROR'],
      ['invalid', 401, 'AUTHENTICATION_ERROR'],
      [farmerGrant.accessToken, 403, 'AUTHORIZATION_ERROR'],
    ] as const) {
      await payload(
        await fetch(`${url}/api/v1${adminPath}`, {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        }),
        status,
        code,
      );
      await payload(await post(url, adminPath, draft, token), status, code);
      await payload(
        await post(url, statusPath, { status: 'ACTIVE' }, token, 'PATCH'),
        status,
        code,
      );
    }
    assert.equal(setup.fertilizer.writes.length, 0);
    assert.equal(setup.fertilizer.changes.length, 0);
    const created = await payload<{ id: string; status: string }>(
      await post(url, adminPath, draft, adminGrant.accessToken),
      201,
    );
    assert.equal(created.data.status, 'DRAFT');
    assert.equal(setup.fertilizer.writes[0]?.actorId, actorId);
    assert.equal(setup.fertilizer.writes[0]?.requestId, created.requestId);
    await payload(
      await post(url, adminPath, { ...draft, reviewedBy: randomUUID() }, adminGrant.accessToken),
      400,
      'VALIDATION_ERROR',
    );
    await payload(
      await post(
        url,
        adminPath,
        { ...draft, rule: { ...draft.rule, source: { ...draft.rule.source, citation: '' } } },
        adminGrant.accessToken,
      ),
      400,
      'VALIDATION_ERROR',
    );
    for (const percentageField of [
      'nitrogenPercent',
      'phosphorusPercent',
      'potassiumPercent',
    ] as const) {
      for (const invalidPercentage of ['abc', '1e2', '', '100.01']) {
        await payload(
          await post(
            url,
            adminPath,
            {
              ...draft,
              product: { ...draft.product, [percentageField]: invalidPercentage },
            },
            adminGrant.accessToken,
          ),
          400,
          'VALIDATION_ERROR',
        );
      }
    }
    assert.equal(setup.fertilizer.writes.length, 1);
    await payload(
      await post(url, statusPath, { status: 'DRAFT' }, adminGrant.accessToken, 'PATCH'),
      400,
      'VALIDATION_ERROR',
    );
    await payload(
      await post(
        url,
        statusPath,
        { status: 'ACTIVE', rateKgPerHectare: '900' },
        adminGrant.accessToken,
        'PATCH',
      ),
      400,
      'VALIDATION_ERROR',
    );
    await payload(
      await post(url, statusPath, { status: 'INACTIVE' }, adminGrant.accessToken, 'PATCH'),
    );
    assert.equal(setup.fertilizer.changes[0]?.actorId, actorId);
    const reactivated = await payload<{ status: string }>(
      await post(url, statusPath, { status: 'ACTIVE' }, adminGrant.accessToken, 'PATCH'),
    );
    assert.equal(reactivated.data.status, 'ACTIVE');
    const listing = await payload<{ items: unknown[]; limit: number }>(
      await fetch(`${url}/api/v1${adminPath}`, {
        headers: { Authorization: `Bearer ${adminGrant.accessToken}` },
      }),
    );
    assert.equal(listing.data.limit, 100);
    assert.equal(listing.data.items.length, 1);
  });
});

test('calculator enforces JSON and one shared feature rate limit', async () => {
  const setup = fixture(2);
  await withServer(setup.app, async (url) => {
    await payload(
      await fetch(`${url}/api/v1${publicPath}/calculate`, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain' },
        body: '1.5',
      }),
      415,
      'UNSUPPORTED_MEDIA_TYPE',
    );
    await payload(await fetch(`${url}/api/v1${publicPath}/rules`));
    await payload(
      await post(url, `${publicPath}/calculate`, fertilizerInput(setup.fertilizer.rule.id)),
      429,
      'RATE_LIMITED',
    );
    assert.equal(setup.fertilizer.reads.length, 1);
  });
});

test('database errors are centralized without raw credentials or stack traces', async () => {
  const setup = fixture();
  setup.fertilizer.repository.catalogue = async () => {
    throw new Error('private-database-secret');
  };
  await withServer(setup.app, async (url) => {
    await payload(await fetch(`${url}/api/v1${publicPath}/rules`), 500, 'INTERNAL_SERVER_ERROR');
  });
});

test('calculator rate configuration is bounded and separate from Gemini settings', () => {
  assert.equal(testEnvironment.CALCULATOR_RATE_LIMIT_MAX, 30);
  for (const invalid of ['0', '-1', '1001', 'invalid'])
    assert.throws(
      () =>
        parseEnvironment({
          DATABASE_URL: testEnvironment.DATABASE_URL,
          JWT_SECRET: testEnvironment.JWT_SECRET,
          JWT_REFRESH_SECRET: testEnvironment.JWT_REFRESH_SECRET,
          CALCULATOR_RATE_LIMIT_MAX: invalid,
        }),
      /CALCULATOR_RATE_LIMIT_MAX/,
    );
});
