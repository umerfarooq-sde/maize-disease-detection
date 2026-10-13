import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import { createGenerationService } from '../../src/modules/generation/generation.service.js';
import { answer, fakeGeneration, prediction, scanDto } from './helpers.js';

test('explanation reads the authorized scan and sends only frozen persisted prediction scalars', async () => {
  const scan = scanDto();
  const userId = randomUUID();
  const key = randomUUID();
  const reads: unknown[][] = [];
  const generated = fakeGeneration();
  const service = createGenerationService(
    {
      async read(...args) {
        reads.push(args);
        return scan;
      },
    },
    generated.client,
  );
  const result = await service.explain(scan.id, userId, key);
  assert.deepEqual(reads, [[scan.id, userId, key]]);
  assert.deepEqual(generated.explanations, [prediction()]);
  assert.equal(Object.isFrozen(generated.explanations[0]), true);
  assert.deepEqual(result.classifierPrediction, prediction());
  const wire = JSON.stringify(generated.explanations);
  for (const privateValue of [
    scan.id,
    userId,
    key,
    'private-signed-url-sentinel',
    'probabilities',
    'image',
  ])
    assert.ok(!wire.includes(privateValue));
});

test('missing/foreign ownership fails before generation and is never replaced with a direct scan lookup', async () => {
  for (const code of ['AUTHENTICATION_ERROR', 'NOT_FOUND'] as const) {
    const generated = fakeGeneration();
    const service = createGenerationService(
      {
        async read() {
          throw new AppError(code);
        },
      },
      generated.client,
    );
    await assert.rejects(
      service.explain(randomUUID(), null),
      (error: unknown) => error instanceof AppError && error.code === code,
    );
    assert.equal(generated.explanations.length, 0);
  }
});

test('pending/processing/failed/missing and legacy incompatible predictions return conflict without provider calls', async () => {
  const generated = fakeGeneration();
  const scan = scanDto();
  const service = createGenerationService(
    {
      async read() {
        return scan;
      },
    },
    generated.client,
  );
  for (const status of ['PENDING', 'PROCESSING', 'FAILED'] as const) {
    scan.status = status;
    await assert.rejects(
      service.explain(scan.id, null, randomUUID()),
      (error: unknown) =>
        error instanceof AppError && error.code === 'SCAN_EXPLANATION_UNAVAILABLE',
    );
  }
  scan.status = 'COMPLETED';
  const stored = scan.prediction;
  assert.ok(stored);
  for (const mutation of [
    { predictedClass: 'unrecognized' },
    { confidence: 1.1 },
    { predictionStatus: null },
    { uncertaintyReason: null },
    { modelVersion: '' },
    { confidenceThreshold: 0.9 },
  ]) {
    scan.prediction = { ...stored, ...mutation } as typeof stored;
    await assert.rejects(
      service.explain(scan.id, null, randomUUID()),
      (error: unknown) =>
        error instanceof AppError && error.code === 'SCAN_EXPLANATION_UNAVAILABLE',
    );
  }
  scan.prediction = null;
  await assert.rejects(
    service.explain(scan.id, null, randomUUID()),
    (error: unknown) => error instanceof AppError && error.code === 'SCAN_EXPLANATION_UNAVAILABLE',
  );
  assert.equal(generated.explanations.length, 0);
});

test('high scores with unconfigured threshold remain LOW_CONFIDENCE and cannot be mutated by a client', async () => {
  const generated = fakeGeneration();
  const scan = scanDto();
  assert.ok(scan.prediction);
  Object.assign(scan.prediction, prediction({ confidence: 0.999 }));
  const service = createGenerationService(
    {
      async read() {
        return scan;
      },
    },
    generated.client,
  );
  const result = await service.explain(scan.id, null, randomUUID());
  assert.equal(result.classifierPrediction?.predictionStatus, 'LOW_CONFIDENCE');
  assert.equal(result.classifierPrediction?.uncertaintyReason, 'THRESHOLD_UNCONFIGURED');
  assert.equal(result.classifierPrediction?.confidenceThreshold, null);
  assert.ok(result.warnings.length);
  generated.client.explain = async (context) => answer({ ...context, confidence: 0.998 });
  await assert.rejects(
    service.explain(scan.id, null, randomUUID()),
    (error: unknown) => error instanceof AppError && error.code === 'GEN_INVALID_RESPONSE',
  );
  assert.equal(scan.prediction.confidence, 0.999);
});

test('general questions cannot inherit a fabricated classifier result from the internal client', async () => {
  const generated = fakeGeneration();
  const service = createGenerationService(
    {
      async read() {
        assert.fail('General ask must not read a scan.');
      },
    },
    generated.client,
  );
  const input = { question: 'What causes common rust?', diseaseLabel: 'Common_Rust' as const };
  assert.equal((await service.ask(input)).classifierPrediction, null);
  assert.deepEqual(generated.asks, [input]);
  generated.client.ask = async () => answer(prediction());
  await assert.rejects(
    service.ask(input),
    (error: unknown) => error instanceof AppError && error.code === 'GEN_INVALID_RESPONSE',
  );
});
