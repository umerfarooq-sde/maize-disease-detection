import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import { scanLimits } from '../../src/modules/scans/scan.types.js';
import { silentLogger } from '../foundation/helpers.js';
import { fakeInference, fakeStorage, imageFile, memoryScans } from './helpers.js';

const errorCode = (code: string) => (error: unknown) =>
  error instanceof AppError && error.code === code;

test('anonymous and farmer inference save unchanged bytes, low confidence and immutable versions', async () => {
  const memory = memoryScans();
  const cloud = fakeStorage();
  const ai = fakeInference();
  const service = createScanService(memory.repository, cloud.storage, silentLogger, ai.client);
  const file = await imageFile();
  for (const userId of [null, randomUUID()]) {
    const key = randomUUID();
    const first = await service.create(file, key, userId);
    assert.equal(first.scan.status, 'COMPLETED');
    assert.equal(first.scan.prediction?.modelVersion, ai.result.modelVersion);
    assert.equal(first.scan.prediction?.preprocessingVersion, '1.0.0');
    assert.equal(first.scan.prediction?.predictionStatus, 'LOW_CONFIDENCE');
    assert.equal(first.scan.prediction?.confidenceThreshold, null);
    assert.equal(first.scan.analysisError, null);
    assert.ok(first.scan.finishedAt);
    assert.equal(
      [...memory.records.values()].find((r) => r.scanId === first.scan.id)?.scan?.userId,
      userId,
    );
    assert.equal((await service.create(file, key, userId)).scan.id, first.scan.id);
  }
  assert.equal(ai.calls.length, 2);
  assert.equal(cloud.assets.size, 2);
  assert.ok(ai.calls.every((image) => image.bytes === file.buffer));
});

for (const code of [
  'INFERENCE_UNAVAILABLE',
  'INFERENCE_TIMEOUT',
  'INFERENCE_FAILED',
  'INFERENCE_INVALID_RESPONSE',
  'INVALID_IMAGE',
] as const) {
  test(`${code} preserves saved image and scan; same-key retry does not upload again`, async () => {
    const memory = memoryScans();
    const cloud = fakeStorage();
    const ai = fakeInference();
    const predict = ai.client.predict;
    ai.client.predict = async () => {
      throw new AppError(code);
    };
    const service = createScanService(memory.repository, cloud.storage, silentLogger, ai.client);
    const file = await imageFile();
    const key = randomUUID();
    const failed = await service.create(file, key, null);
    assert.equal(failed.scan.status, 'FAILED');
    assert.equal(failed.scan.analysisError?.code, code);
    assert.equal(failed.scan.prediction, null);
    assert.equal(cloud.assets.size, 1);
    assert.equal([...memory.records.values()][0]?.state, 'COMPLETED');
    ai.client.predict = predict;
    const retry = await service.create(file, key, null);
    assert.equal(retry.scan.status, 'COMPLETED');
    assert.equal(retry.scan.id, failed.scan.id);
    assert.equal(retry.replayed, true);
    assert.equal(cloud.assets.size, 1);
    assert.equal([...memory.records.values()][0]?.scan?.predictions.length, 1);
  });
}

test('persistence failure and lost commit acknowledgement never destroy saved assets/outcomes', async () => {
  const memory = memoryScans();
  const cloud = fakeStorage();
  const ai = fakeInference();
  const original = memory.repository.completeInference;
  memory.repository.completeInference = async () => {
    throw new Error('private database failure');
  };
  const service = createScanService(memory.repository, cloud.storage, silentLogger, ai.client);
  const file = await imageFile();
  const key = randomUUID();
  const failed = await service.create(file, key, null);
  assert.equal(failed.scan.status, 'FAILED');
  assert.equal(failed.scan.analysisError?.code, 'INFERENCE_PERSISTENCE_FAILED');
  assert.equal(cloud.assets.size, 1);
  memory.repository.completeInference = async (...args) => {
    await original(...args);
    throw new Error('Reply lost');
  };
  const saved = await service.create(file, key, null);
  assert.equal(saved.scan.status, 'COMPLETED');
  assert.equal(saved.scan.id, failed.scan.id);
  assert.equal(cloud.assets.size, 1);
  assert.equal([...memory.records.values()][0]?.scan?.predictions.length, 1);
});

test('database outage after storage leaves a durable scan and safe retryable error', async () => {
  const memory = memoryScans();
  const cloud = fakeStorage();
  const ai = fakeInference();
  memory.repository.startInference = async () => {
    throw new Error('private database URL');
  };
  const service = createScanService(memory.repository, cloud.storage, silentLogger, ai.client);
  await assert.rejects(
    service.create(await imageFile(), randomUUID(), null),
    errorCode('SCAN_PROCESSING_UNAVAILABLE'),
  );
  assert.equal(cloud.assets.size, 1);
  assert.equal([...memory.records.values()][0]?.scan?.status, 'PENDING');
  assert.equal(
    await service.recoverStale(new Date(Date.now() + scanLimits.inferenceLeaseMs + 1000)),
    1,
  );
  assert.equal([...memory.records.values()][0]?.scan?.status, 'FAILED');
});

test('concurrent same-key replay sees processing and causes one inference', async () => {
  const memory = memoryScans();
  const cloud = fakeStorage();
  const ai = fakeInference();
  let release: () => void = () => {};
  let ready: () => void = () => {};
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const started = new Promise<void>((resolve) => {
    ready = resolve;
  });
  const predict = ai.client.predict;
  ai.client.predict = async (image) => {
    ready();
    await gate;
    return predict(image);
  };
  const service = createScanService(memory.repository, cloud.storage, silentLogger, ai.client);
  const file = await imageFile();
  const key = randomUUID();
  const running = service.create(file, key, null);
  await started;
  try {
    assert.equal((await service.create(file, key, null)).scan.status, 'PROCESSING');
  } finally {
    release();
  }
  assert.equal((await running).scan.status, 'COMPLETED');
  assert.equal(ai.calls.length, 1);
  assert.equal(cloud.assets.size, 1);
});

test('expired inference attempt is fenced from completing or failing a later retry', async () => {
  const memory = memoryScans();
  const cloud = fakeStorage();
  const ai = fakeInference();
  const service = createScanService(memory.repository, cloud.storage, silentLogger);
  const saved = await service.create(await imageFile(), randomUUID(), null);
  const oldAttempt = await memory.repository.startInference(saved.scan.id);
  assert.ok(oldAttempt);
  const scan = await memory.repository.findScan(saved.scan.id);
  assert.ok(scan);
  scan.updatedAt = new Date(Date.now() - scanLimits.inferenceLeaseMs - 1000);
  assert.equal(await service.recoverStale(), 1);
  const newAttempt = await memory.repository.startInference(scan.id);
  assert.ok(newAttempt);
  await assert.rejects(memory.repository.completeInference(scan.id, oldAttempt, ai.result));
  await memory.repository.failInference(scan.id, 'INFERENCE_FAILED', undefined, oldAttempt);
  assert.equal(scan.status, 'PROCESSING');
  assert.equal(scan.inferenceAttemptId, newAttempt);
  await memory.repository.completeInference(scan.id, newAttempt, ai.result);
  assert.equal(scan.status, 'COMPLETED');
  assert.equal(scan.predictions.length, 1);
});

test('invalid images never reach Cloudinary, database claim or inference', async () => {
  const memory = memoryScans();
  const cloud = fakeStorage();
  const ai = fakeInference();
  const service = createScanService(memory.repository, cloud.storage, silentLogger, ai.client);
  const file = await imageFile();
  await assert.rejects(
    service.create(
      { ...file, buffer: Buffer.concat([file.buffer, Buffer.from('trailing')]) },
      randomUUID(),
      null,
    ),
    errorCode('INVALID_IMAGE'),
  );
  assert.equal(memory.records.size, 0);
  assert.equal(cloud.assets.size, 0);
  assert.equal(ai.calls.length, 0);
});
