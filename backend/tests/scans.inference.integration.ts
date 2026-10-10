import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createDatabaseClient } from '../src/database/client.js';
import { registerModelVersion } from '../src/modules/inference/model.repository.js';
import type { ApprovedModel } from '../src/modules/inference/model-registration.js';
import { createScanRepository } from '../src/modules/scans/scan.repository.js';
import { createScanService } from '../src/modules/scans/scan.service.js';
import { scanResponse } from '../src/modules/scans/scan.types.js';
import { assertSqlRejects, rollbackFixture } from './database-support.js';
import { silentLogger } from './foundation/helpers.js';
import { fakeInference, fakeStorage, imageFile } from './scans/helpers.js';

test('PostgreSQL inference transactions, version identity, ownership and recovery', {
  timeout: 240000,
}, async (t) => {
  const database = createDatabaseClient(undefined, 30000);
  const repository = createScanRepository(database);
  const cloud = fakeStorage();
  const inference = fakeInference();
  const version = `fixture-${randomUUID()}`;
  inference.result.modelVersion = version;
  const model: ApprovedModel = {
    version,
    architecture: 'mobilenet_v3_small',
    artifactUri: `sha256:${'a'.repeat(64)}`,
    artifactSha256: 'a'.repeat(64),
    datasetVersion: 'synthetic-only',
    preprocessingVersion: '1.0.0',
    classLabels: ['Common_Rust', 'Gray_Leaf_Spot', 'Healthy', 'Northern_Corn_Leaf_Blight'],
    status: 'VALIDATED',
    trainingConfig: {
      metadataSha256: 'b'.repeat(64),
      experimentId: 'synthetic-fixture',
      seed: 1,
      hyperparameters: {},
      preprocessingHash: 'c'.repeat(64),
      preprocessing: {},
      manifestFingerprint: 'd'.repeat(64),
      researchPolicy: {
        permitted_use: 'non-commercial academic/FYP research only',
        commercial_clearance: false,
        raw_image_redistribution: false,
      },
    },
  };
  const farmer = await database.user.create({
    data: {
      email: `phase12-${randomUUID()}@example.invalid`,
      passwordHash: '$argon2id$synthetic_fixture_not_for_login',
      role: 'FARMER',
    },
  });
  const uploads = new Set<string>();
  const scans = new Set<string>();
  const originalUpload = cloud.storage.upload;
  cloud.storage.upload = async (image, publicId) => {
    uploads.add(publicId.slice('maizedoctor/scans/'.length));
    return originalUpload(image, publicId);
  };
  const service = createScanService(repository, cloud.storage, silentLogger, inference.client);
  const file = await imageFile();
  async function pending() {
    const result = await createScanService(repository, cloud.storage, silentLogger).create(
      file,
      randomUUID(),
      null,
    );
    scans.add(result.scan.id);
    return result.scan.id;
  }
  try {
    await t.test(
      'controlled registration is idempotent and refuses immutable replacement',
      async () => {
        const saved = await registerModelVersion(database, model);
        assert.equal(saved.status, 'VALIDATED');
        assert.equal((await registerModelVersion(database, model)).id, saved.id);
        await assert.rejects(
          registerModelVersion(database, { ...model, artifactSha256: 'e'.repeat(64) }),
        );
        assert.equal(
          (await database.modelVersion.findUniqueOrThrow({ where: { version } })).artifactSha256,
          model.artifactSha256,
        );
      },
    );
    await t.test(
      'anonymous and farmer predictions persist exact public metadata atomically',
      async () => {
        for (const userId of [null, farmer.id]) {
          const key = randomUUID();
          const result = await service.create(file, key, userId);
          scans.add(result.scan.id);
          assert.equal(result.scan.status, 'COMPLETED');
          assert.equal(result.scan.prediction?.modelVersion, version);
          assert.equal(result.scan.prediction?.preprocessingVersion, '1.0.0');
          assert.equal(result.scan.prediction?.predictionStatus, 'LOW_CONFIDENCE');
          assert.equal(result.scan.prediction?.confidenceThreshold, null);
          const stored = await repository.findScan(result.scan.id);
          assert.ok(stored);
          assert.equal(stored.userId, userId);
          assert.equal(stored.inferenceAttemptId, null);
          assert.equal(stored.predictions.length, 1);
          assert.deepEqual(stored.predictions[0]?.probabilities, {
            Common_Rust: 0.8,
            Gray_Leaf_Spot: 0.1,
            Healthy: 0.05,
            Northern_Corn_Leaf_Blight: 0.05,
          });
          assert.ok(stored.predictions[0]?.inferredAt instanceof Date);
          assert.equal((await service.create(file, key, userId)).scan.id, result.scan.id);
          assert.equal(
            await database.scanPrediction.count({ where: { scanId: result.scan.id } }),
            1,
          );
          assert.equal(
            (await service.read(result.scan.id, userId, userId ? undefined : key)).id,
            result.scan.id,
          );
          await assert.rejects(
            service.read(result.scan.id, userId ? randomUUID() : null, randomUUID()),
          );
        }
      },
    );
    await t.test(
      'unknown model rolls back prediction and completed state; asset survives retry',
      async () => {
        const key = randomUUID();
        inference.result.modelVersion = `missing-${randomUUID()}`;
        const result = await service.create(file, key, null);
        scans.add(result.scan.id);
        assert.equal(result.scan.status, 'FAILED');
        assert.equal(result.scan.analysisError?.code, 'INFERENCE_PERSISTENCE_FAILED');
        assert.equal(await database.scanPrediction.count({ where: { scanId: result.scan.id } }), 0);
        assert.ok((await repository.findScan(result.scan.id))?.cloudinaryPublicId);
        inference.result.modelVersion = version;
        assert.equal((await service.create(file, key, null)).scan.status, 'COMPLETED');
      },
    );
    await t.test(
      'conditional leases fence stale writers and retain successful outcomes',
      async () => {
        const id = await pending();
        const old = await repository.startInference(id);
        assert.ok(old);
        assert.equal(await repository.startInference(id), null);
        await repository.failInference(id, 'INFERENCE_INTERRUPTED', undefined, old);
        const current = await repository.startInference(id);
        assert.ok(current);
        assert.notEqual(old, current);
        await assert.rejects(repository.completeInference(id, old, inference.result));
        await repository.failInference(id, 'INFERENCE_FAILED', undefined, old);
        assert.equal((await repository.findScan(id))?.status, 'PROCESSING');
        await repository.completeInference(id, current, inference.result);
        await repository.failInference(id, 'INFERENCE_FAILED', undefined, current);
        const completed = await repository.findScan(id);
        assert.ok(completed);
        assert.equal(scanResponse(completed).status, 'COMPLETED');
        assert.equal(await database.scanPrediction.count({ where: { scanId: id } }), 1);
      },
    );
    await t.test('SQL enforces coherent outcome and processing lease constraints', async () => {
      const id = [...scans][0];
      assert.ok(id);
      await assert.rejects(
        database.$transaction(async (tx) => {
          await assertSqlRejects(
            tx,
            'UPDATE scans SET inference_attempt_id=$2::uuid WHERE id=$1::uuid',
            [id, randomUUID()],
            '23514',
          );
          await assertSqlRejects(
            tx,
            "INSERT INTO scan_predictions (id,scan_id,model_version_id,predicted_class,confidence,prediction_status,inferred_at,inference_duration_ms) SELECT $1::uuid,$2::uuid,id,'Common_Rust',0.8,'CONFIDENT',now(),10 FROM model_versions WHERE version=$3",
            [randomUUID(), id, version],
            '23514',
          );
          throw rollbackFixture;
        }),
        (error: unknown) => error === rollbackFixture,
      );
    });
    await t.test('stale recovery uses DB time and only completed upload journals', async () => {
      const id = randomUUID();
      const uploadId = randomUUID();
      const past = new Date(Date.now() - 600000);
      scans.add(id);
      uploads.add(uploadId);
      await database.scan.create({
        data: {
          id,
          userId: null,
          imageUrl: 'https://example.invalid/synthetic.png',
          cloudinaryPublicId: `maizedoctor/scans/${uploadId}`,
          imageMimeType: 'image/png',
          imageBytes: file.buffer.length,
          uploadedAt: past,
          createdAt: past,
          updatedAt: past,
          status: 'PROCESSING',
          inferenceAttemptId: randomUUID(),
        },
      });
      await database.scanUpload.create({
        data: {
          id: uploadId,
          requestKeyHash: uploadId.replaceAll('-', '').padEnd(64, 'f'),
          imageHash: 'f'.repeat(64),
          publicId: `maizedoctor/scans/${uploadId}`,
          scanId: id,
          state: 'COMPLETED',
        },
      });
      assert.ok((await repository.failStaleInference(new Date(Date.now() - 120000))) >= 1);
      const recovered = await repository.findScan(id);
      assert.equal(recovered?.status, 'FAILED');
      assert.equal(recovered?.errorCode, 'INFERENCE_INTERRUPTED');
      assert.equal(recovered?.inferenceAttemptId, null);
      assert.ok(recovered?.finishedAt && recovered.finishedAt >= recovered.createdAt);
      assert.equal(
        (await database.scanUpload.findUniqueOrThrow({ where: { id: uploadId } })).state,
        'COMPLETED',
      );
    });
  } finally {
    const records = await database.scanUpload.findMany({ where: { id: { in: [...uploads] } } });
    for (const row of records) if (row.scanId) scans.add(row.scanId);
    await database.scanUpload.deleteMany({ where: { id: { in: [...uploads] } } });
    await database.scanPrediction.deleteMany({ where: { scanId: { in: [...scans] } } });
    await database.scan.deleteMany({ where: { id: { in: [...scans] } } });
    await database.modelVersion.deleteMany({ where: { version } });
    await database.user.delete({ where: { id: farmer.id } });
    await database.$disconnect();
  }
});
