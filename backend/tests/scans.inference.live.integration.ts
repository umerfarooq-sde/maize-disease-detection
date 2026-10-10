import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import { loadEnvironment } from '../src/config/environment.js';
import { createDatabaseClient } from '../src/database/client.js';
import { createAuthRepository } from '../src/modules/auth/auth.repository.js';
import { createAuthService } from '../src/modules/auth/auth.service.js';
import { createHealthRepository } from '../src/modules/health/health.repository.js';
import { createAiInferenceClient } from '../src/modules/inference/inference.client.js';
import { createScanRepository } from '../src/modules/scans/scan.repository.js';
import { createScanService } from '../src/modules/scans/scan.service.js';
import { createImageStorage } from '../src/modules/scans/scan.storage.js';
import { silentLogger, withServer } from './foundation/helpers.js';
import { imageFile } from './scans/helpers.js';

test('real Node -> FastAPI model + Cloudinary + PostgreSQL public scan contract', {
  skip: process.env['RUN_LIVE_SCAN_INFERENCE'] !== 'true',
  timeout: 240000,
}, async () => {
  const environment = loadEnvironment();
  const database = createDatabaseClient(environment.DATABASE_URL, 30000);
  const provider = createImageStorage(environment);
  const uploads = new Set<string>();
  const timings: number[] = [];
  const storage = {
    ...provider,
    async upload(...args: Parameters<typeof provider.upload>) {
      uploads.add(args[1].slice('maizedoctor/scans/'.length));
      return provider.upload(...args);
    },
  };
  const auth = createAuthRepository(database);
  const authService = createAuthService(environment, auth);
  const credentials = {
    email: `phase12-live-${randomUUID()}@example.invalid`,
    password: `synthetic-test-${randomUUID()}`,
  };
  await authService.register(credentials);
  const farmer = await database.user.findUniqueOrThrow({ where: { email: credentials.email } });
  const access = (await authService.login(credentials)).accessToken;
  const app = createApp(
    environment,
    silentLogger,
    createHealthRepository(database),
    auth,
    createScanService(
      createScanRepository(database),
      storage,
      silentLogger,
      createAiInferenceClient(environment),
    ),
  );
  try {
    await withServer(app, async (base) => {
      for (const [format, token] of [
        ['jpeg', undefined],
        ['png', undefined],
        ['webp', undefined],
        ['png', access],
      ] as const) {
        const file = await imageFile(format);
        const key = randomUUID();
        const headers = {
          'X-Auth-Request': '1',
          'Idempotency-Key': key,
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        };
        async function send() {
          const form = new FormData();
          form.append(
            'image',
            new Blob([new Uint8Array(file.buffer)], { type: file.mimetype }),
            file.originalname,
          );
          return fetch(`${base}/api/v1/scans`, { method: 'POST', headers, body: form });
        }
        const created = await send();
        assert.equal(created.status, 201);
        const result = (await created.json()) as {
          success: boolean;
          data: {
            id: string;
            status: string;
            prediction: {
              modelVersion: string;
              preprocessingVersion: string;
              predictionStatus: string;
              uncertaintyReason: string;
              confidenceThreshold: null;
              inferenceDurationMs: number;
              probabilities: Record<string, number>;
            };
          };
        };
        assert.equal(result.success, true);
        assert.equal(result.data.status, 'COMPLETED');
        const prediction = result.data.prediction;
        assert.equal(prediction.modelVersion, environment.AI_MODEL_VERSION);
        assert.equal(prediction.preprocessingVersion, environment.AI_PREPROCESSING_VERSION);
        assert.equal(prediction.predictionStatus, 'LOW_CONFIDENCE');
        assert.equal(prediction.uncertaintyReason, 'THRESHOLD_UNCONFIGURED');
        assert.equal(prediction.confidenceThreshold, null);
        assert.equal(Object.keys(prediction.probabilities).length, 4);
        timings.push(prediction.inferenceDurationMs);
        const saved = await database.scan.findUniqueOrThrow({
          where: { id: result.data.id },
          include: { predictions: { include: { modelVersion: true } } },
        });
        assert.equal(saved.userId, token ? farmer.id : null);
        assert.equal(saved.predictions.length, 1);
        assert.equal(saved.predictions[0]?.modelVersion.version, environment.AI_MODEL_VERSION);
        assert.equal(saved.predictions[0]?.modelVersion.status, 'VALIDATED');
        const replay = await send();
        assert.equal(replay.status, 200);
        assert.deepEqual(((await replay.json()) as typeof result).data, result.data);
        const read = await fetch(`${base}/api/v1/scans/${saved.id}`, { headers });
        assert.equal(read.status, 200);
        assert.deepEqual(((await read.json()) as typeof result).data, result.data);
        const anonymousWithoutKey = await fetch(`${base}/api/v1/scans/${saved.id}`);
        assert.equal(anonymousWithoutKey.status, 401);
      }
      assert.equal(uploads.size, 4);
    });
    console.log(
      JSON.stringify({
        liveInference: 'PASS',
        syntheticImages: 4,
        formats: ['JPEG', 'PNG', 'WebP'],
        anonymousAndFarmer: true,
        representativeInferenceMeanMs: timings.reduce((a, b) => a + b, 0) / timings.length,
        noDatasetReads: true,
        noClassAccuracyClaim: true,
      }),
    );
  } finally {
    const records = await database.scanUpload.findMany({ where: { id: { in: [...uploads] } } });
    for (const row of records) await provider.destroy(row.publicId);
    const ids = records.flatMap((row) => (row.scanId ? [row.scanId] : []));
    await database.scanUpload.deleteMany({ where: { id: { in: [...uploads] } } });
    await database.scanPrediction.deleteMany({ where: { scanId: { in: ids } } });
    await database.scan.deleteMany({ where: { id: { in: ids } } });
    await database.user.delete({ where: { id: farmer.id } });
    await database.$disconnect();
  }
});
