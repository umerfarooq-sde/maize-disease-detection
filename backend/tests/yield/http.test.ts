import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { createFertilizerService } from '../../src/modules/fertilizer/fertilizer.service.js';
import { createGenerationService } from '../../src/modules/generation/generation.service.js';
import { createKnowledgeService } from '../../src/modules/knowledge/knowledge.service.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import type { YieldDraftSummary } from '../../src/modules/yield/yield.service.js';
import { createYieldService } from '../../src/modules/yield/yield.service.js';
import type { YieldCatalogue, YieldResult } from '../../src/modules/yield/yield.types.js';
import { memoryRepository } from '../auth/helpers.js';
import { memoryFertilizer } from '../fertilizer/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { fakeGeneration } from '../generation/helpers.js';
import { memoryKnowledge } from '../knowledge/helpers.js';
import { fakeInference, fakeStorage, memoryScans } from '../scans/helpers.js';
import { draft, input, memoryYield } from './helpers.js';

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
  const memory = memoryYield();
  const service = createYieldService(memory.repository);
  const app = createApp(
    environment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    scans,
    createKnowledgeService(knowledge.repository, knowledge.client),
    createGenerationService(scans, generated.client),
    createFertilizerService(memoryFertilizer().repository),
    service,
  );
  return { app, authService, auth, memory, generated, service };
}
async function payload<T>(response: Response, status = 200, code?: string): Promise<T> {
  assert.equal(response.status, status);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const body = (await response.json()) as {
    success: boolean;
    data: T;
    requestId: string;
    error?: { code: string };
  };
  assert.equal(body.success, status < 400);
  assert.equal(body.requestId, response.headers.get('x-request-id'));
  if (code) assert.equal(body.error?.code, code);
  for (const secret of [
    'reviewedBy',
    'parameters',
    'createdById',
    'passwordHash',
    'stack',
    'private-connection',
  ])
    assert.ok(!JSON.stringify(body).includes(secret));
  return body.data;
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
const path = '/calculators/yield';
const admin = '/admin/calculators/yield/configurations';
test('public yield API returns exact conditional results and honest pending configuration without AI', async () => {
  const setup = fixture();
  await withServer(setup.app, async (url) => {
    const catalogue = await payload<YieldCatalogue>(
      await fetch(`${url}/api/v1${path}/configurations`),
    );
    assert.equal(catalogue.status, 'READY');
    const result = await payload<YieldResult>(
      await post(url, `${path}/calculate`, input(setup.memory.record.id)),
    );
    assert.equal(result.expectedYield.value, '25.000');
    assert.equal(result.configuration.source.url, draft().source.url);
    assert.equal(result.configuration.version, 1);
    assert.ok(result.assumptions.length);
    assert.equal(setup.generated.asks.length, 0);
    assert.equal(setup.generated.explanations.length, 0);
    setup.memory.records.length = 0;
    const pending = await payload<YieldCatalogue>(
      await fetch(`${url}/api/v1${path}/configurations`),
    );
    assert.equal(pending.status, 'PENDING_CONFIGURATION');
    assert.deepEqual(pending.items, []);
  });
});
test('yield HTTP validation rejects zero/negative/number areas, forged rates and unsupported units', async () => {
  const setup = fixture();
  const valid = input(setup.memory.record.id);
  await withServer(setup.app, async (url) => {
    for (const invalid of [
      {},
      { ...valid, area: '0' },
      { ...valid, area: '-1' },
      { ...valid, area: 2 },
      { ...valid, outputUnit: 'TON' },
      { ...valid, area: '1e3' },
      { ...valid, expectedYieldKgPerHectare: '90' },
      { ...valid, plantPopulation: 50000 },
      { ...valid, formula: 'eval' },
    ])
      await payload(await post(url, `${path}/calculate`, invalid), 400, 'VALIDATION_ERROR');
    await payload(
      await post(url, `${path}/calculate`, { ...valid, configVersion: 2 }),
      409,
      'YIELD_CONFIGURATION_CHANGED',
    );
    await payload(
      await post(url, `${path}/calculate`, { ...valid, configId: randomUUID() }),
      409,
      'YIELD_CONFIGURATION_CHANGED',
    );
    setup.memory.record.parameters = {};
    await payload(await post(url, `${path}/calculate`, valid), 503, 'YIELD_CONFIGURATION_INVALID');
  });
});
test('yield ADMIN management requires live ADMIN role and stamps its own review identity', async () => {
  const setup = fixture();
  const adminAccount = {
    email: 'yield-admin@example.invalid',
    password: 'synthetic correct horse battery staple',
  };
  const farmer = { email: 'yield-farmer@example.invalid', password: adminAccount.password };
  await setup.authService.createAdmin(adminAccount);
  await setup.authService.register(farmer);
  const adminGrant = await setup.authService.login(adminAccount);
  const farmerGrant = await setup.authService.login(farmer);
  await withServer(setup.app, async (url) => {
    for (const [token, status] of [
      [undefined, 401],
      ['invalid', 401],
      [farmerGrant.accessToken, 403],
    ] as const) {
      await payload(
        await fetch(`${url}/api/v1${admin}`, {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        }),
        status,
      );
      await payload(await post(url, admin, draft(), token), status);
      await payload(
        await post(
          url,
          `${admin}/${setup.memory.record.id}/status`,
          { status: 'ACTIVE' },
          token,
          'PATCH',
        ),
        status,
      );
    }
    for (const invalid of [
      { ...draft(), reviewedBy: randomUUID() },
      { ...draft(), expectedYieldKgPerHectare: '-1' },
      { ...draft(), reviewNote: 'short' },
      { ...draft(), source: { ...draft().source, citation: '' } },
      { ...draft(), formula: 'arbitrary' },
      { ...draft(), quantityDecimalPlaces: 7 },
    ])
      await payload(
        await post(url, admin, invalid, adminGrant.accessToken),
        400,
        'VALIDATION_ERROR',
      );
    const created = await payload<YieldDraftSummary>(
      await post(url, admin, { ...draft(), version: 2 }, adminGrant.accessToken),
      201,
    );
    assert.equal(created.status, 'DRAFT');
    assert.equal(created.validForActivation, true);
    assert.equal(setup.memory.writes[0]?.actorId, setup.auth.accounts.get(adminAccount.email)?.id);
    await payload(
      await post(
        url,
        `${admin}/${created.id}/status`,
        { status: 'ACTIVE' },
        adminGrant.accessToken,
        'PATCH',
      ),
    );
    await payload(
      await post(url, `${path}/calculate`, input(setup.memory.record.id)),
      409,
      'YIELD_CONFIGURATION_CHANGED',
    );
    await payload(
      await post(
        url,
        `${admin}/${created.id}/status`,
        { status: 'INACTIVE', expectedYieldKgPerHectare: '100' },
        adminGrant.accessToken,
        'PATCH',
      ),
      400,
    );
  });
});
test('yield endpoints enforce JSON, rate limits and safe database failures', async () => {
  const setup = fixture(2);
  await withServer(setup.app, async (url) => {
    await payload(
      await fetch(`${url}/api/v1${path}/calculate`, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain' },
        body: 'x',
      }),
      415,
    );
    await payload(await fetch(`${url}/api/v1${path}/configurations`));
    await payload(await fetch(`${url}/api/v1${path}/configurations`), 429, 'RATE_LIMITED');
  });
  const broken = fixture();
  broken.memory.repository.find = async () => {
    throw new Error('private-connection');
  };
  await withServer(broken.app, async (url) => {
    await payload(
      await post(url, `${path}/calculate`, input(broken.memory.record.id)),
      500,
      'INTERNAL_SERVER_ERROR',
    );
  });
});
