import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import sharp from 'sharp';
import { AppError } from '../../src/errors/app-error.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import { scanLimits } from '../../src/modules/scans/scan.types.js';
import { validateImage } from '../../src/modules/scans/scan.validation.js';
import { silentLogger } from '../foundation/helpers.js';
import { fakeStorage, imageFile, memoryScans } from './helpers.js';

const errorCode = (code: string) => (error: unknown) =>
  error instanceof AppError && error.code === code;
for (const format of ['jpeg', 'png', 'webp'] as const) {
  test(`security decoder accepts a complete ${format} and preserves original bytes`, async () => {
    const file = await imageFile(format);
    const image = await validateImage(file);
    assert.equal(image.bytes, file.buffer);
    assert.equal(image.width, 24);
    assert.equal(image.mimeType, `image/${format}`);
  });
}
test('portrait JPEG orientation is retained without rotating or re-encoding uploaded bytes', async () => {
  const file = await imageFile('jpeg', 6);
  const image = await validateImage(file);
  assert.equal(image.orientation, 6);
  assert.equal(image.width, 24);
  assert.equal(image.height, 48);
  assert.equal(image.bytes, file.buffer);
});
test('reject empty, oversize, spoofed MIME, mismatched extension, SVG and truncated uploads', async () => {
  const file = await imageFile();
  for (const [input, code] of [
    [undefined, 'VALIDATION_ERROR'],
    [{ ...file, buffer: Buffer.alloc(0) }, 'VALIDATION_ERROR'],
    [{ ...file, buffer: Buffer.alloc(scanLimits.bytes + 1) }, 'PAYLOAD_TOO_LARGE'],
    [{ ...file, mimetype: 'image/jpeg' }, 'UNSUPPORTED_MEDIA_TYPE'],
    [{ ...file, originalname: 'leaf.exe' }, 'UNSUPPORTED_MEDIA_TYPE'],
    [{ ...file, buffer: Buffer.from('<svg></svg>') }, 'UNSUPPORTED_MEDIA_TYPE'],
    [{ ...file, buffer: file.buffer.subarray(0, 50) }, 'INVALID_IMAGE'],
  ] as const)
    await assert.rejects(validateImage(input), errorCode(code));
});
test('reject excessive pixel dimensions and animated images', async () => {
  const file = await imageFile();
  const large = await sharp({
    create: { width: 4096, height: 4096, channels: 3, background: '#245443' },
  })
    .png()
    .toBuffer();
  await assert.rejects(validateImage({ ...file, buffer: large }), errorCode('INVALID_IMAGE'));
  const frames = Buffer.concat([Buffer.alloc(12, 0), Buffer.alloc(12, 255)]);
  const animated = await sharp(frames, { raw: { width: 2, height: 4, pageHeight: 2, channels: 3 } })
    .webp({ loop: 0, delay: [100, 100] })
    .toBuffer();
  await assert.rejects(
    validateImage({ ...file, originalname: 'leaf.webp', mimetype: 'image/webp', buffer: animated }),
    errorCode('INVALID_IMAGE'),
  );
});
test('anonymous creation, farmer ownership and payload-bound retry produce one scan', async () => {
  const { repository, records } = memoryScans();
  const { storage, assets } = fakeStorage();
  const service = createScanService(repository, storage, silentLogger);
  const file = await imageFile();
  const key = randomUUID();
  const first = await service.create(file, key, null);
  const again = await service.create(file, key, null);
  assert.equal(first.scan.status, 'FAILED');
  assert.equal(first.scan.analysisError?.code, 'INFERENCE_UNAVAILABLE');
  assert.equal(first.scan.id, again.scan.id);
  assert.equal(again.replayed, true);
  assert.equal(assets.size, 1);
  assert.equal([...records.values()][0]?.scan?.userId, null);
  assert.ok(!JSON.stringify(first.scan).includes('cloudinaryPublicId'));
  assert.ok(!JSON.stringify(first.scan).includes('userId'));
  const userId = randomUUID();
  await service.create(file, key, userId);
  assert.ok([...records.values()].some((r) => r.scan?.userId === userId));
  await assert.rejects(service.create(await imageFile('webp'), key, null), errorCode('CONFLICT'));
});
test('database failure compensates the asset and permits retry after confirmed deletion', async () => {
  const { repository, records } = memoryScans();
  const { storage, assets } = fakeStorage();
  const complete = repository.complete;
  repository.complete = async () => {
    throw new Error('Database unavailable');
  };
  const service = createScanService(repository, storage, silentLogger);
  const file = await imageFile();
  const key = randomUUID();
  await assert.rejects(service.create(file, key, null), errorCode('UPLOAD_FAILED'));
  assert.equal(assets.size, 0);
  assert.equal([...records.values()][0]?.state, 'FAILED');
  assert.equal([...records.values()][0]?.scan, null);
  repository.complete = complete;
  assert.equal((await service.create(file, key, null)).scan.status, 'FAILED');
});
test('lost commit acknowledgement preserves the committed scan and image', async () => {
  const { repository } = memoryScans();
  const { storage, assets } = fakeStorage();
  const complete = repository.complete;
  repository.complete = async (...args) => {
    await complete(...args);
    throw new Error('Commit response lost');
  };
  const result = await createScanService(repository, storage, silentLogger).create(
    await imageFile(),
    randomUUID(),
    null,
  );
  assert.equal(result.replayed, true);
  assert.equal(assets.size, 1);
});
test('provider timeout, failed deletion and crashed uploads are recovered after grace; completed assets survive', async () => {
  const { repository, records } = memoryScans();
  const { storage, assets } = fakeStorage();
  const upload = storage.upload;
  const destroy = storage.destroy;
  const service = createScanService(repository, storage, silentLogger);
  const file = await imageFile();
  storage.upload = async (...args) => {
    await upload(...args);
    throw new Error('Reply lost');
  };
  const key = randomUUID();
  await assert.rejects(service.create(file, key, null), errorCode('UPLOAD_FAILED'));
  assert.equal([...records.values()][0]?.state, 'CLEANUP_PENDING');
  assert.deepEqual(await service.cleanup(), { removed: 0, failed: 0, pruned: 0 });
  await assert.rejects(service.create(file, key, null), errorCode('UPLOAD_IN_PROGRESS'));
  storage.destroy = async () => {
    throw new Error('Provider unavailable');
  };
  const future = new Date(Date.now() + scanLimits.cleanupDelayMs + 60_000);
  assert.deepEqual(await service.cleanup(future), { removed: 0, failed: 1, pruned: 0 });
  storage.destroy = destroy;
  assert.deepEqual(await service.cleanup(future), { removed: 1, failed: 0, pruned: 0 });
  storage.upload = upload;
  await service.create(file, randomUUID(), null);
  const { record } = await repository.claim('a'.repeat(64), 'b'.repeat(64), randomUUID());
  assets.add(record.publicId);
  assert.deepEqual(await service.cleanup(future), { removed: 1, failed: 0, pruned: 0 });
  assert.equal(assets.size, 1);
  assert.equal((await service.cleanup(new Date(Date.now() + 48 * 60 * 60_000))).pruned, 2);
  assert.equal(records.size, 1);
});
