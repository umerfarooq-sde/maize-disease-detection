import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import { loadEnvironment } from '../src/config/environment.js';
import { createDatabaseClient } from '../src/database/client.js';
import { createAuthRepository } from '../src/modules/auth/auth.repository.js';
import { createHealthRepository } from '../src/modules/health/health.repository.js';
import { createScanRepository } from '../src/modules/scans/scan.repository.js';
import { createScanService } from '../src/modules/scans/scan.service.js';
import { createImageStorage } from '../src/modules/scans/scan.storage.js';
import { silentLogger, withServer } from './foundation/helpers.js';
import { imageFile } from './scans/helpers.js';

test('real Node -> Cloudinary authenticated asset -> PostgreSQL, replay and fixture deletion', {
  skip: process.env['RUN_LIVE_SCAN_UPLOAD'] !== 'true',
  timeout: 180000,
}, async () => {
  const environment = loadEnvironment();
  const database = createDatabaseClient(environment.DATABASE_URL, 30000);
  const storage = createImageStorage(environment);
  const key = randomUUID();
  const keyHash = createHash('sha256').update(`anonymous:${key}`).digest('hex');
  const keyHashes = [keyHash];
  const app = createApp(
    environment,
    silentLogger,
    createHealthRepository(database),
    createAuthRepository(database),
    createScanService(createScanRepository(database), storage, silentLogger),
  );
  try {
    await withServer(app, async (baseUrl) => {
      const file = await imageFile();
      async function send(uploadFile = file, requestKey = key) {
        const form = new FormData();
        form.append(
          'image',
          new Blob([new Uint8Array(uploadFile.buffer)], { type: uploadFile.mimetype }),
          uploadFile.originalname,
        );
        return fetch(`${baseUrl}/api/v1/scans`, {
          method: 'POST',
          headers: { 'Idempotency-Key': requestKey, 'X-Auth-Request': '1' },
          body: form,
        });
      }
      const response = await send();
      assert.equal(response.status, 201);
      const replay = await send();
      assert.equal(replay.status, 200);
      const record = await database.scanUpload.findUniqueOrThrow({
        where: { requestKeyHash: keyHash },
        include: { scan: true },
      });
      assert.equal(record.state, 'COMPLETED');
      assert.equal(record.scan?.userId, null);
      assert.equal(record.scan?.imageBytes, file.buffer.length);
      assert.ok(record.scan);
      const delivered = await fetch(record.scan.imageUrl);
      assert.equal(delivered.status, 200);
      assert.equal(delivered.headers.get('content-type'), 'image/png');
      const unsigned = record.scan.imageUrl.replace(/\/s--[^/]+--\//, '/');
      assert.ok((await fetch(unsigned)).status >= 400);
      // Phones commonly encode portrait JPEGs through EXIF rather than rotated pixels.
      const portrait = await imageFile('jpeg', 6);
      const portraitKey = randomUUID();
      const portraitHash = createHash('sha256').update(`anonymous:${portraitKey}`).digest('hex');
      keyHashes.push(portraitHash);
      assert.equal((await send(portrait, portraitKey)).status, 201);
      const portraitScan = await database.scanUpload.findUniqueOrThrow({
        where: { requestKeyHash: portraitHash },
        include: { scan: true },
      });
      assert.ok(portraitScan.scan);
      assert.equal(portraitScan.scan.imageBytes, portrait.buffer.length);
      const jpeg = await fetch(portraitScan.scan.imageUrl);
      assert.equal(jpeg.status, 200);
      assert.equal(jpeg.headers.get('content-type'), 'image/jpeg');
    });
  } finally {
    try {
      const records = await database.scanUpload.findMany({
        where: { requestKeyHash: { in: keyHashes } },
      });
      for (const record of records) {
        await storage.destroy(record.publicId);
        await database.scanUpload.delete({ where: { id: record.id } });
        if (record.scanId) await database.scan.delete({ where: { id: record.scanId } });
      }
    } finally {
      await database.$disconnect();
    }
  }
});
