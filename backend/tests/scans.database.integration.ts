import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createDatabaseClient } from '../src/database/client.js';
import { AppError } from '../src/errors/app-error.js';
import { createScanRepository } from '../src/modules/scans/scan.repository.js';
import { createScanService } from '../src/modules/scans/scan.service.js';
import { scanLimits } from '../src/modules/scans/scan.types.js';
import { assertSqlRejects, rollbackFixture } from './database-support.js';
import { silentLogger } from './foundation/helpers.js';
import { fakeStorage, imageFile } from './scans/helpers.js';

test('PostgreSQL scan persistence, idempotency race, compensation and journal constraints', {
  timeout: 180000,
}, async (t) => {
  const database = createDatabaseClient(undefined, 30000);
  const repository = createScanRepository(database);
  const { storage, assets } = fakeStorage();
  const service = createScanService(repository, storage, silentLogger);
  const ids = new Set<string>();
  const scanIds = new Set<string>();
  const farmer = await database.user.create({
    data: {
      email: `phase7-${randomUUID()}@example.invalid`,
      passwordHash: '$argon2id$synthetic_fixture_not_for_login',
      role: 'FARMER',
    },
  });
  const file = await imageFile();
  const upload = storage.upload;
  storage.upload = async (image, publicId) => {
    ids.add(publicId.slice('maizedoctor/scans/'.length));
    return upload(image, publicId);
  };
  try {
    await t.test('anonymous scans have nullable ownership and actual upload metadata', async () => {
      const key = randomUUID();
      const first = await service.create(file, key, null);
      scanIds.add(first.scan.id);
      const scan = await database.scan.findUniqueOrThrow({ where: { id: first.scan.id } });
      assert.equal(scan.userId, null);
      assert.equal(scan.status, 'FAILED');
      assert.equal(scan.errorCode, 'INFERENCE_UNAVAILABLE');
      assert.equal(scan.imageBytes, file.buffer.length);
      assert.ok(scan.uploadedAt instanceof Date);
      assert.equal((await service.create(file, key, null)).scan.id, scan.id);
    });
    await t.test(
      'authenticated farmer scans reference the existing farmer; no predictions are fabricated',
      async () => {
        const result = await service.create(file, randomUUID(), farmer.id);
        scanIds.add(result.scan.id);
        assert.equal(
          (await database.scan.findUniqueOrThrow({ where: { id: result.scan.id } })).userId,
          farmer.id,
        );
        assert.equal(await database.scanPrediction.count({ where: { scanId: result.scan.id } }), 0);
      },
    );
    await t.test('parallel claims admit one uploader across database connections', async () => {
      const keyHash = randomUUID().replaceAll('-', '').padEnd(64, 'a');
      const imageHash = 'b'.repeat(64);
      const results = await Promise.all(
        Array.from({ length: 6 }, () => repository.claim(keyHash, imageHash, randomUUID())),
      );
      for (const result of results) ids.add(result.record.id);
      assert.equal(results.filter((r) => r.claimed).length, 1);
      assert.equal(new Set(results.map((r) => r.record.id)).size, 1);
    });
    await t.test(
      'failed scan insert rolls back the transaction and deletes the accepted image',
      async () => {
        await assert.rejects(
          service.create(file, randomUUID(), randomUUID()),
          (error: unknown) => error instanceof AppError && error.code === 'UPLOAD_FAILED',
        );
        const failed = await database.scanUpload.findFirstOrThrow({
          where: { id: { in: [...ids] }, state: 'FAILED' },
        });
        assert.equal(failed.scanId, null);
        assert.ok(!assets.has(failed.publicId));
      },
    );
    await t.test(
      'cleanup and completion use exclusive conditional claims; completed uploads cannot be claimed',
      async () => {
        const candidates = await repository.cleanupCandidates(
          new Date(Date.now() + scanLimits.cleanupDelayMs + 60000),
        );
        const own = candidates.find((r) => ids.has(r.id));
        assert.ok(own);
        const before = new Date(Date.now() + 60000);
        assert.equal(await repository.claimCleanup(own.id, before), true);
        // A real timestamp in the future would defeat the lease; normal workers use
        // a past cutoff. Verify a second worker cannot claim a fresh CLEANING row.
        assert.equal(
          await repository.claimCleanup(own.id, new Date(Date.now() - scanLimits.cleanupDelayMs)),
          false,
        );
        const completed = await database.scanUpload.findFirstOrThrow({
          where: { id: { in: [...ids] }, state: 'COMPLETED' },
        });
        assert.equal(await repository.claimCleanup(completed.id, before), false);
        await storage.destroy(own.publicId);
        await repository.finishCleanup(own.id);
      },
    );
    await t.test(
      'database enforces journal identity, state/link pairing and immutable scan upload timestamp',
      async () => {
        const completed = await database.scanUpload.findFirstOrThrow({
          where: { id: { in: [...ids] }, state: 'COMPLETED' },
        });
        await assert.rejects(
          database.$transaction(async (tx) => {
            await assertSqlRejects(
              tx,
              "UPDATE scan_uploads SET state='FAILED' WHERE id=$1::uuid",
              [completed.id],
              '23514',
            );
            await assertSqlRejects(
              tx,
              "UPDATE scan_uploads SET public_id='other/asset' WHERE id=$1::uuid",
              [completed.id],
              '23514',
            );
            await assertSqlRejects(
              tx,
              "UPDATE scans SET uploaded_at=uploaded_at+interval '1 second' WHERE id=$1::uuid",
              [completed.scanId],
              '23514',
            );
            throw rollbackFixture;
          }),
          (error: unknown) => error === rollbackFixture,
        );
      },
    );
  } finally {
    // Only this run's generated upload IDs, scans and farmer are removed.
    const records = await database.scanUpload.findMany({ where: { id: { in: [...ids] } } });
    for (const record of records) if (record.scanId) scanIds.add(record.scanId);
    await database.scanUpload.deleteMany({ where: { id: { in: [...ids] } } });
    await database.scan.deleteMany({ where: { id: { in: [...scanIds] } } });
    await database.user.delete({ where: { id: farmer.id } });
    await database.$disconnect();
  }
});
