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

type ScanPayload = {
  success: true;
  data: ReturnType<typeof scanResponse>;
  requestId: string;
};

function fixture() {
  const auth = memoryRepository();
  const scans = memoryScans();
  const cloud = fakeStorage();
  const ai = fakeInference();
  const environment = { ...testEnvironment, SCAN_RATE_LIMIT_MAX: 100 };
  const authService = createAuthService(environment, auth.repository);
  const app = createApp(
    environment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    createScanService(scans.repository, cloud.storage, silentLogger, ai.client),
  );
  return { app, auth, authService, scans, cloud, ai };
}

async function postScan(url: string, key: string, token?: string) {
  const file = await imageFile();
  const form = new FormData();
  form.append('image', new Blob([new Uint8Array(file.buffer)], { type: 'image/png' }), 'leaf.png');
  return fetch(`${url}/api/v1/scans`, {
    method: 'POST',
    headers: {
      'Idempotency-Key': key,
      'X-Auth-Request': '1',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: form,
  });
}

async function failure(response: Response, status: number, code: string) {
  assert.equal(response.status, status);
  const payload = (await response.json()) as {
    success: false;
    error: { code: string; message: string };
    requestId: string;
  };
  assert.equal(payload.success, false);
  assert.equal(payload.error.code, code);
  assert.equal(payload.requestId, response.headers.get('x-request-id'));
  assert.deepEqual(Object.keys(payload).sort(), ['error', 'requestId', 'success']);
  assert.ok(!JSON.stringify(payload).includes('stack'));
  return payload;
}

test('anonymous completed scan POST and private-key GET preserve one safe public prediction', async () => {
  const { app, scans, cloud, ai } = fixture();
  const key = randomUUID();
  const sensitiveFixtureToken = 'synthetic-internal-ai-token-not-for-public-response';
  const checkpointSha256 = 'a'.repeat(64);
  Object.assign(ai.result, { aiServiceToken: sensitiveFixtureToken, checkpointSha256 });
  await withServer(app, async (url) => {
    const created = await postScan(url, key);
    assert.equal(created.status, 201);
    const payload = (await created.json()) as ScanPayload;
    assert.deepEqual(Object.keys(payload).sort(), ['data', 'requestId', 'success']);
    assert.equal(payload.success, true);
    assert.equal(payload.requestId, created.headers.get('x-request-id'));
    assert.equal(payload.data.status, 'COMPLETED');
    assert.deepEqual(Object.keys(payload.data).sort(), [
      'analysisError',
      'createdAt',
      'finishedAt',
      'id',
      'image',
      'prediction',
      'status',
    ]);
    assert.equal(payload.data.analysisError, null);
    assert.ok(payload.data.finishedAt);
    assert.deepEqual(payload.data.prediction, {
      predictedClass: 'Common_Rust',
      confidence: 0.8,
      probabilities: {
        Common_Rust: 0.8,
        Gray_Leaf_Spot: 0.1,
        Healthy: 0.05,
        Northern_Corn_Leaf_Blight: 0.05,
      },
      modelVersion: ai.result.modelVersion,
      preprocessingVersion: '1.0.0',
      predictionStatus: 'LOW_CONFIDENCE',
      uncertaintyReason: 'THRESHOLD_UNCONFIGURED',
      confidenceThreshold: null,
      inferenceDurationMs: 12.5,
      inferredAt: payload.data.prediction?.inferredAt,
    });
    assert.ok(payload.data.prediction?.inferredAt);
    assert.deepEqual(Object.keys(payload.data.image).sort(), [
      'bytes',
      'mimeType',
      'uploadedAt',
      'url',
    ]);
    assert.equal(payload.data.image.mimeType, 'image/png');
    assert.equal(created.headers.get('cache-control'), 'no-store');

    const read = await fetch(`${url}/api/v1/scans/${payload.data.id}`, {
      headers: { 'Idempotency-Key': key },
    });
    assert.equal(read.status, 200);
    assert.equal(read.headers.get('cache-control'), 'no-store');
    const persisted = (await read.json()) as ScanPayload;
    assert.deepEqual(persisted.data, payload.data);
    assert.equal(persisted.requestId, read.headers.get('x-request-id'));
    assert.notEqual(persisted.requestId, payload.requestId);

    const replay = await postScan(url, key);
    assert.equal(replay.status, 200);
    assert.deepEqual(((await replay.json()) as ScanPayload).data, payload.data);
    assert.equal(ai.calls.length, 1);
    assert.equal(cloud.assets.size, 1);
    assert.equal(scans.records.size, 1);
    const scan = [...scans.records.values()][0]?.scan;
    assert.ok(scan);
    assert.equal(scan.userId, null);
    assert.equal(scan.predictions.length, 1);
    const serialized = JSON.stringify(persisted);
    for (const privateValue of [
      key,
      sensitiveFixtureToken,
      checkpointSha256,
      scan.predictions[0]?.id,
      scan.predictions[0]?.modelVersionId,
    ]) {
      assert.ok(privateValue);
      assert.ok(!serialized.includes(privateValue));
    }
    for (const privateField of [
      'userId',
      'cloudinaryPublicId',
      'modelVersionId',
      'diseaseId',
      'inferenceAttemptId',
      'requestKeyHash',
      'imageHash',
      'checkpointSha256',
      'aiServiceToken',
    ]) {
      assert.ok(!serialized.includes(`"${privateField}"`));
    }
  });
});

test('farmer scan reads enforce current ownership against other farmers, guests, admins and invalid tokens', async () => {
  const { app, auth, authService, ai } = fixture();
  const farmer = { email: 'owner@example.invalid', password: 'synthetic owner password' };
  const other = { email: 'other@example.invalid', password: 'synthetic other password' };
  const admin = { email: 'admin@example.invalid', password: 'synthetic admin password' };
  await authService.register(farmer);
  await authService.register(other);
  await authService.createAdmin(admin);
  const farmerToken = (await authService.login(farmer)).accessToken;
  const otherToken = (await authService.login(other)).accessToken;
  const adminToken = (await authService.login(admin)).accessToken;
  const key = randomUUID();
  await withServer(app, async (url) => {
    const created = await postScan(url, key, farmerToken);
    assert.equal(created.status, 201);
    const payload = (await created.json()) as ScanPayload;
    const endpoint = `${url}/api/v1/scans/${payload.data.id}`;
    const read = await fetch(endpoint, { headers: { Authorization: `Bearer ${farmerToken}` } });
    assert.equal(read.status, 200);
    assert.deepEqual(((await read.json()) as ScanPayload).data, payload.data);
    await failure(
      await fetch(endpoint, { headers: { Authorization: `Bearer ${otherToken}` } }),
      404,
      'NOT_FOUND',
    );
    await failure(await fetch(endpoint), 401, 'AUTHENTICATION_ERROR');
    await failure(await fetch(endpoint, { headers: { 'Idempotency-Key': key } }), 404, 'NOT_FOUND');
    await failure(
      await fetch(endpoint, { headers: { Authorization: `Bearer ${adminToken}` } }),
      403,
      'AUTHORIZATION_ERROR',
    );
    await failure(
      await fetch(endpoint, { headers: { Authorization: 'Bearer invalid' } }),
      401,
      'AUTHENTICATION_ERROR',
    );
    const absent = await fetch(`${url}/api/v1/scans/${randomUUID()}`, {
      headers: { Authorization: `Bearer ${farmerToken}` },
    });
    await failure(absent, 404, 'NOT_FOUND');
    assert.equal(ai.calls.length, 1);
    const serialized = JSON.stringify(payload);
    for (const privateValue of [
      farmerToken,
      otherToken,
      adminToken,
      auth.accounts.get(farmer.email)?.id,
    ]) {
      assert.ok(privateValue);
      assert.ok(!serialized.includes(privateValue));
    }
  });
});

test('anonymous reads require the original private key and do not become farmer-owned', async () => {
  const { app, authService, ai } = fixture();
  const farmer = { email: 'farmer@example.invalid', password: 'synthetic farmer password' };
  await authService.register(farmer);
  const farmerToken = (await authService.login(farmer)).accessToken;
  const key = randomUUID();
  await withServer(app, async (url) => {
    const created = await postScan(url, key);
    const scan = ((await created.json()) as ScanPayload).data;
    const endpoint = `${url}/api/v1/scans/${scan.id}`;
    await failure(await fetch(endpoint), 401, 'AUTHENTICATION_ERROR');
    await failure(
      await fetch(endpoint, { headers: { 'Idempotency-Key': randomUUID() } }),
      404,
      'NOT_FOUND',
    );
    await failure(
      await fetch(endpoint, { headers: { 'Idempotency-Key': 'untrusted-non-uuid-key' } }),
      400,
      'VALIDATION_ERROR',
    );
    await failure(
      await fetch(endpoint, {
        headers: { 'Idempotency-Key': key, Authorization: 'Bearer invalid' },
      }),
      401,
      'AUTHENTICATION_ERROR',
    );
    await failure(
      await fetch(endpoint, {
        headers: { 'Idempotency-Key': key, Authorization: `Bearer ${farmerToken}` },
      }),
      404,
      'NOT_FOUND',
    );
    const authorized = await fetch(endpoint, { headers: { 'Idempotency-Key': key } });
    assert.equal(authorized.status, 200);
    assert.deepEqual(((await authorized.json()) as ScanPayload).data, scan);
    assert.equal(ai.calls.length, 1);
  });
});

test('scan read API validates UUID and rejects all query parameters without invoking inference', async () => {
  const { app, ai } = fixture();
  const key = randomUUID();
  await withServer(app, async (url) => {
    const created = await postScan(url, key);
    const scan = ((await created.json()) as ScanPayload).data;
    for (const path of [
      'not-a-uuid',
      '00000000-0000-0000-0000-00000000000x',
      `${scan.id}?userId=${randomUUID()}`,
      `${scan.id}?include=internal`,
      `${scan.id}?top_k=4`,
    ]) {
      await failure(
        await fetch(`${url}/api/v1/scans/${path}`, { headers: { 'Idempotency-Key': key } }),
        400,
        'VALIDATION_ERROR',
      );
    }
    const unknown = await fetch(`${url}/api/v1/scans/${randomUUID()}`, {
      headers: { 'Idempotency-Key': key },
    });
    await failure(unknown, 404, 'NOT_FOUND');
    assert.equal(ai.calls.length, 1);
  });
});

test('persisted inference failures are safely readable without repeating upload or AI calls', async () => {
  const { app, scans, cloud, ai } = fixture();
  let attempts = 0;
  ai.client.predict = async () => {
    attempts++;
    throw new AppError('INFERENCE_TIMEOUT');
  };
  const key = randomUUID();
  await withServer(app, async (url) => {
    const created = await postScan(url, key);
    assert.equal(created.status, 201);
    const payload = (await created.json()) as ScanPayload;
    assert.equal(payload.data.status, 'FAILED');
    assert.equal(payload.data.prediction, null);
    assert.equal(payload.data.analysisError?.code, 'INFERENCE_TIMEOUT');
    assert.ok(payload.data.finishedAt);
    for (let index = 0; index < 3; index++) {
      const read = await fetch(`${url}/api/v1/scans/${payload.data.id}`, {
        headers: { 'Idempotency-Key': key },
      });
      assert.equal(read.status, 200);
      assert.equal(read.headers.get('cache-control'), 'no-store');
      assert.deepEqual(((await read.json()) as ScanPayload).data, payload.data);
    }
    assert.equal(attempts, 1);
    assert.equal(cloud.assets.size, 1);
    assert.equal(scans.records.size, 1);
    assert.equal([...scans.records.values()][0]?.scan?.predictions.length, 0);
  });
});
