import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import {
  createModelHealthClient,
  createModelHealthService,
} from '../../src/modules/admin/model-health.service.js';
import { modelHealthSchema, type ModelHealth } from '../../src/modules/admin/model-health.types.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { diseaseLabels } from '../../src/modules/inference/inference.types.js';
import { memoryRepository } from '../auth/helpers.js';
import {
  silentLogger,
  testEnvironment as baseEnvironment,
  withServer,
} from '../foundation/helpers.js';

const testEnvironment = {
  ...baseEnvironment,
  AI_MODEL_VERSION: 'test-model-v1',
  AI_PREPROCESSING_VERSION: '1.0.0',
};

export function liveSnapshot(): ModelHealth {
  return {
    ready: true,
    modelVersion: testEnvironment.AI_MODEL_VERSION,
    preprocessingVersion: testEnvironment.AI_PREPROCESSING_VERSION,
    confidencePolicy: 'UNCONFIGURED',
    development: {
      architecture: 'mobilenet_v3_small',
      datasetVersion: 'test-only-index-v1',
      experimentId: 'test-only',
      indexFingerprint: 'a'.repeat(64),
      trainedAt: null,
      evaluation: {
        class_names: [...diseaseLabels],
        sample_count: 4,
        accuracy: 1,
        macro_precision: 1,
        macro_recall: 1,
        macro_f1: 1,
        per_class: diseaseLabels.map((label) => ({
          label,
          support: 1,
          precision: 1,
          recall: 1,
          f1: 1,
          specificity: 1,
        })),
        confusion_matrix: [
          [1, 0, 0, 0],
          [0, 1, 0, 0],
          [0, 0, 1, 0],
          [0, 0, 0, 1],
        ],
      },
    },
    runtime: {
      scope: 'PROCESS_SINCE_START',
      since: '2026-10-15T00:00:00+00:00',
      requests: 3,
      inFlight: 1,
      successes: 1,
      failures: 1,
      lowConfidence: 1,
      lowConfidenceRate: 1,
      meanLatencyMs: 12,
      predictionDistribution: {
        Common_Rust: 0,
        Gray_Leaf_Spot: 0,
        Healthy: 1,
        Northern_Corn_Leaf_Blight: 0,
      },
    },
  };
}
test('registry promotion, loaded research version and offline/runtime evidence remain distinct', async () => {
  for (const productionVersions of [[], [testEnvironment.AI_MODEL_VERSION], ['one', 'two']]) {
    const service = createModelHealthService(
      {
        async registry() {
          return { models: [], productionVersions };
        },
      },
      testEnvironment,
      async () => liveSnapshot(),
    );
    const result = await service.summary();
    assert.equal(
      result.registry.status,
      productionVersions.length === 0
        ? 'NOT_PROMOTED'
        : productionVersions.length === 1
          ? 'SINGLE_PRODUCTION'
          : 'MULTIPLE_PRODUCTION',
    );
    assert.equal(result.service.matchesProduction, productionVersions.length === 1);
    assert.equal(result.service.data?.development?.evaluation.sample_count, 4);
    assert.equal(result.service.data?.runtime.requests, 3);
    assert.equal(result.service.data?.runtime.since, '2026-10-15T00:00:00.000Z');
    assert.equal(result.drift, 'NOT_AVAILABLE_NO_GROUND_TRUTH');
  }
});
test('unavailable, incompatible and malformed probes never disclose errors or substitute runtime accuracy', async () => {
  const repository = {
    async registry() {
      return { models: [], productionVersions: [] };
    },
  };
  const probes = [
    async () => {
      throw new Error('private-service-token');
    },
    async () => ({ ...liveSnapshot(), modelVersion: 'another-version' }),
    async () => ({ ...liveSnapshot(), runtime: { ...liveSnapshot().runtime, requests: 999 } }),
  ];
  for (const probe of probes) {
    const result = await createModelHealthService(repository, testEnvironment, probe).summary();
    assert.equal(result.service.data, null);
    assert.equal(result.service.status, probe === probes[1] ? 'INCOMPATIBLE' : 'UNAVAILABLE');
    assert.ok(!JSON.stringify(result).includes('private-service-token'));
  }
  assert.equal(
    modelHealthSchema.safeParse({
      ...liveSnapshot(),
      runtime: { ...liveSnapshot().runtime, lowConfidenceRate: 0 },
    }).success,
    false,
  );
  const stopped = {
    ...liveSnapshot(),
    ready: false,
    modelVersion: null,
    preprocessingVersion: null,
    development: null,
  };
  const notLoaded = await createModelHealthService(
    repository,
    testEnvironment,
    async () => stopped,
  ).summary();
  assert.equal(notLoaded.service.status, 'NOT_LOADED');
  assert.equal(notLoaded.service.data?.development, null);
});
test('fixed-origin bounded client uses authenticated GET and rejects malformed replies/redirects', async () => {
  const environment = {
    ...testEnvironment,
    AI_SERVICE_URL: 'http://127.0.0.1:8000',
    AI_SERVICE_TOKEN: 'synthetic-private-token',
  };
  const valid = await createModelHealthClient(environment, async (url, init) => {
    assert.equal(String(url), 'http://127.0.0.1:8000/api/v1/model-dashboard');
    assert.equal(init?.method, 'GET');
    assert.equal(init?.body, undefined);
    assert.equal(init?.redirect, 'manual');
    assert.equal(new Headers(init?.headers).get('Authorization'), 'Bearer synthetic-private-token');
    return Response.json({
      success: true,
      data: liveSnapshot(),
      meta: { requestId: randomUUID() },
    });
  })();
  assert.equal(valid.runtime.failures, 1);
  for (const response of [
    new Response(null, { status: 302 }),
    Response.json({ success: true, data: {} }),
    new Response('x'.repeat(131073), { headers: { 'Content-Type': 'application/json' } }),
  ]) {
    await assert.rejects(createModelHealthClient(environment, async () => response)());
  }
});
test('model-health endpoint denies all non-Admin sessions before probing and validates filters', async () => {
  const auth = memoryRepository();
  const service = createAuthService(testEnvironment, auth.repository);
  const credentials = {
    email: 'health-admin@example.invalid',
    password: 'synthetic test password',
  };
  await service.createAdmin(credentials);
  const admin = await service.login(credentials);
  await service.register({ ...credentials, email: 'health-farmer@example.invalid' });
  const farmer = await service.login({ ...credentials, email: 'health-farmer@example.invalid' });
  let calls = 0;
  const health = createModelHealthService(
    {
      async registry() {
        calls++;
        return { models: [], productionVersions: [] };
      },
    },
    testEnvironment,
    async () => liveSnapshot(),
  );
  const app = createApp(
    testEnvironment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    undefined,
    undefined,
    undefined,
    undefined,
    undefined,
    undefined,
    undefined,
    undefined,
    health,
  );
  await withServer(app, async (base) => {
    for (const [token, status] of [
      [undefined, 401],
      ['invalid', 401],
      [farmer.accessToken, 403],
    ] as const) {
      assert.equal(
        (
          await fetch(`${base}/api/v1/admin/model-health`, {
            headers: token ? { Authorization: `Bearer ${token}` } : {},
          })
        ).status,
        status,
      );
    }
    assert.equal(calls, 0);
    const headers = { Authorization: `Bearer ${admin.accessToken}` };
    assert.equal(
      (await fetch(`${base}/api/v1/admin/model-health?unexpected=1`, { headers })).status,
      400,
    );
    const result = await fetch(`${base}/api/v1/admin/model-health`, { headers });
    assert.equal(result.status, 200);
    assert.equal(result.headers.get('cache-control'), 'no-store');
    assert.equal(calls, 1);
    await service.logout(admin.refreshToken);
    assert.equal((await fetch(`${base}/api/v1/admin/model-health`, { headers })).status, 401);
  });
});
