import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { AppError } from '../../src/errors/app-error.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import type { scanResponse } from '../../src/modules/scans/scan.types.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { fakeInference, fakeStorage, imageFile, memoryScans } from './helpers.js';

type HistoryPayload = {
  success: true;
  requestId: string;
  data: { items: ReturnType<typeof scanResponse>[]; nextCursor: string | null };
};

async function fixture() {
  const auth = memoryRepository();
  const scans = memoryScans();
  const ai = fakeInference();
  const cloud = fakeStorage();
  const authService = createAuthService(testEnvironment, auth.repository);
  const owner = { email: 'owner@example.invalid', password: 'synthetic owner history password' };
  await authService.register(owner);
  const ownerAccount = auth.accounts.get(owner.email);
  assert.ok(ownerAccount);
  const ownerId = ownerAccount.id;
  const ownerToken = (await authService.login(owner)).accessToken;
  const service = createScanService(scans.repository, cloud.storage, silentLogger, ai.client);
  const app = createApp(
    testEnvironment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    service,
  );
  const file = await imageFile();
  async function seed(userId: string | null = ownerId, createdAt = new Date()) {
    const saved = await service.create(file, randomUUID(), userId);
    const row = await scans.repository.findScan(saved.scan.id);
    assert.ok(row);
    row.createdAt = createdAt;
    return row;
  }
  return { app, auth, authService, ownerId, ownerToken, service, scans, ai, cloud, seed };
}

async function history(url: string, token: string, query = '') {
  const response = await fetch(`${url}/api/v1/scans${query}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const payload = (await response.json()) as HistoryPayload;
  assert.equal(payload.success, true);
  assert.equal(payload.requestId, response.headers.get('x-request-id'));
  assert.deepEqual(Object.keys(payload).sort(), ['data', 'requestId', 'success']);
  assert.deepEqual(Object.keys(payload.data).sort(), ['items', 'nextCursor']);
  return payload;
}

async function rejected(response: Response, status: number, code: string) {
  assert.equal(response.status, status);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const payload = (await response.json()) as {
    success: false;
    error: { code: string; message: string };
    requestId: string;
  };
  assert.equal(payload.success, false);
  assert.equal(payload.error.code, code);
  assert.equal(payload.requestId, response.headers.get('x-request-id'));
  assert.ok(!JSON.stringify(payload).includes('stack'));
  return payload;
}

test('farmer history defaults to twenty owned scans and traverses a stable descending cursor', async () => {
  const setup = await fixture();
  const expected: string[] = [];
  for (let index = 0; index < 23; index++) {
    expected.unshift((await setup.seed(setup.ownerId, new Date(1_600_000_000_000 + index))).id);
  }
  await setup.seed(null);
  await setup.seed(randomUUID());
  const inferenceCalls = setup.ai.calls.length;
  await withServer(setup.app, async (url) => {
    const first = await history(url, setup.ownerToken);
    assert.equal(first.data.items.length, 20);
    assert.deepEqual(
      first.data.items.map((scan) => scan.id),
      expected.slice(0, 20),
    );
    assert.equal(first.data.nextCursor, expected[19]);
    const second = await history(url, setup.ownerToken, `?cursor=${first.data.nextCursor}`);
    assert.deepEqual(
      second.data.items.map((scan) => scan.id),
      expected.slice(20),
    );
    assert.equal(second.data.nextCursor, null);
    assert.equal(
      new Set([...first.data.items, ...second.data.items].map((scan) => scan.id)).size,
      23,
    );
    const last = second.data.items.at(-1);
    assert.ok(last);
    const exhausted = await history(url, setup.ownerToken, `?cursor=${last.id}`);
    assert.deepEqual(exhausted.data, { items: [], nextCursor: null });
    assert.equal(setup.ai.calls.length, inferenceCalls);
  });
});

test('history ties use descending scan IDs and new records do not shift an existing cursor page', async () => {
  const setup = await fixture();
  const timestamp = new Date('2020-01-01T00:00:00.000Z');
  const original: string[] = [];
  for (let index = 0; index < 5; index++)
    original.push((await setup.seed(setup.ownerId, timestamp)).id);
  original.sort((left, right) => right.localeCompare(left));
  await withServer(setup.app, async (url) => {
    const first = await history(url, setup.ownerToken, '?limit=2');
    assert.deepEqual(
      first.data.items.map((scan) => scan.id),
      original.slice(0, 2),
    );
    const added = await setup.seed(setup.ownerId, new Date('2020-01-02T00:00:00.000Z'));
    const second = await history(url, setup.ownerToken, `?limit=2&cursor=${first.data.nextCursor}`);
    assert.deepEqual(
      second.data.items.map((scan) => scan.id),
      original.slice(2, 4),
    );
    const third = await history(url, setup.ownerToken, `?limit=2&cursor=${second.data.nextCursor}`);
    assert.deepEqual(
      third.data.items.map((scan) => scan.id),
      original.slice(4),
    );
    assert.equal(third.data.nextCursor, null);
    assert.deepEqual(
      [...first.data.items, ...second.data.items, ...third.data.items].map((scan) => scan.id),
      original,
    );
    assert.equal((await history(url, setup.ownerToken, '?limit=1')).data.items[0]?.id, added.id);
  });
});

test('history authenticates farmers, denies anonymous/admin access and hides foreign cursors', async () => {
  const setup = await fixture();
  const other = { email: 'other@example.invalid', password: 'synthetic other history password' };
  const admin = { email: 'admin@example.invalid', password: 'synthetic admin history password' };
  await setup.authService.register(other);
  await setup.authService.createAdmin(admin);
  const otherId = setup.auth.accounts.get(other.email)?.id;
  assert.ok(otherId);
  const otherToken = (await setup.authService.login(other)).accessToken;
  const adminToken = (await setup.authService.login(admin)).accessToken;
  const ownScan = await setup.seed();
  const foreignScan = await setup.seed(otherId);
  const anonymousScan = await setup.seed(null);
  await withServer(setup.app, async (url) => {
    await rejected(await fetch(`${url}/api/v1/scans`), 401, 'AUTHENTICATION_ERROR');
    await rejected(
      await fetch(`${url}/api/v1/scans`, { headers: { 'Idempotency-Key': randomUUID() } }),
      401,
      'AUTHENTICATION_ERROR',
    );
    await rejected(
      await fetch(`${url}/api/v1/scans`, { headers: { Authorization: 'Bearer invalid' } }),
      401,
      'AUTHENTICATION_ERROR',
    );
    await rejected(
      await fetch(`${url}/api/v1/scans`, { headers: { Authorization: `Bearer ${adminToken}` } }),
      403,
      'AUTHORIZATION_ERROR',
    );
    for (const cursor of [foreignScan.id, anonymousScan.id, randomUUID()]) {
      const failure = await rejected(
        await fetch(`${url}/api/v1/scans?cursor=${cursor}`, {
          headers: { Authorization: `Bearer ${setup.ownerToken}` },
        }),
        404,
        'NOT_FOUND',
      );
      assert.ok(!JSON.stringify(failure).includes(cursor));
    }
    assert.deepEqual(
      (await history(url, setup.ownerToken)).data.items.map((scan) => scan.id),
      [ownScan.id],
    );
    assert.deepEqual(
      (await history(url, otherToken)).data.items.map((scan) => scan.id),
      [foreignScan.id],
    );
  });
});

test('history validates limits/cursors/query ownership and supports an empty page and maximum limit', async () => {
  const setup = await fixture();
  await withServer(setup.app, async (url) => {
    assert.deepEqual((await history(url, setup.ownerToken)).data, { items: [], nextCursor: null });
    assert.deepEqual((await history(url, setup.ownerToken, '?limit=50')).data, {
      items: [],
      nextCursor: null,
    });
    for (const query of [
      'limit=0',
      'limit=-1',
      'limit=51',
      'limit=1.5',
      'limit=bad',
      'limit=',
      'limit=1&limit=2',
      'cursor=bad',
      'cursor=',
      `userId=${randomUUID()}`,
      'include=internal',
    ]) {
      await rejected(
        await fetch(`${url}/api/v1/scans?${query}`, {
          headers: { Authorization: `Bearer ${setup.ownerToken}` },
        }),
        400,
        'VALIDATION_ERROR',
      );
    }
    await rejected(await fetch(`${url}/api/v1/scans?limit=bad`), 401, 'AUTHENTICATION_ERROR');
  });
});

test('history projects completed/failed/processing outcomes safely without retrying inference', async () => {
  const setup = await fixture();
  const complete = await setup.seed();
  setup.ai.client.predict = async () => {
    throw new AppError('INFERENCE_TIMEOUT');
  };
  const failed = await setup.seed();
  const processing = await setup.seed();
  Object.assign(processing, {
    status: 'PROCESSING',
    inferenceAttemptId: randomUUID(),
    errorCode: null,
    finishedAt: null,
  });
  const calls = setup.ai.calls.length;
  await withServer(setup.app, async (url) => {
    const payload = await history(url, setup.ownerToken);
    const completedPublic = payload.data.items.find((scan) => scan.id === complete.id);
    const failedPublic = payload.data.items.find((scan) => scan.id === failed.id);
    const processingPublic = payload.data.items.find((scan) => scan.id === processing.id);
    assert.equal(completedPublic?.prediction?.predictedClass, 'Common_Rust');
    assert.equal(completedPublic?.prediction?.predictionStatus, 'LOW_CONFIDENCE');
    assert.equal(completedPublic?.prediction?.confidenceThreshold, null);
    assert.equal(failedPublic?.status, 'FAILED');
    assert.equal(failedPublic?.prediction, null);
    assert.equal(failedPublic?.analysisError?.code, 'INFERENCE_TIMEOUT');
    assert.equal(processingPublic?.status, 'PROCESSING');
    assert.equal(processingPublic?.prediction, null);
    assert.equal(processingPublic?.analysisError, null);
    const serialized = JSON.stringify(payload);
    for (const privateField of [
      'userId',
      'cloudinaryPublicId',
      'modelVersionId',
      'diseaseId',
      'inferenceAttemptId',
      'requestKeyHash',
      'imageHash',
    ]) {
      assert.ok(!serialized.includes(`"${privateField}"`));
    }
    assert.ok(!serialized.includes(setup.ownerId));
    assert.ok(!serialized.includes(setup.ownerToken));
    assert.equal(setup.ai.calls.length, calls);
    assert.equal(setup.cloud.assets.size, 3);
  });
});

test('history database failures use centralized safe errors without leaking database details', async () => {
  const setup = await fixture();
  setup.scans.repository.history = async () => {
    throw new Error('private-database-url-and-query');
  };
  await withServer(setup.app, async (url) => {
    const response = await fetch(`${url}/api/v1/scans`, {
      headers: { Authorization: `Bearer ${setup.ownerToken}` },
    });
    const failure = await rejected(response, 500, 'INTERNAL_SERVER_ERROR');
    assert.ok(!JSON.stringify(failure).includes('private-database-url-and-query'));
  });
});
