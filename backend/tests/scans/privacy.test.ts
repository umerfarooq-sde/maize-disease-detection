import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import express from 'express';
import sharp from 'sharp';
import { AppError } from '../../src/errors/app-error.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { privateStorageImage } from '../../src/modules/scans/image-privacy.js';
import { createPrivateImageReader } from '../../src/modules/scans/private-image.js';
import { scanRoutes } from '../../src/modules/scans/scan.routes.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import { createImageStorage } from '../../src/modules/scans/scan.storage.js';
import { validateImage } from '../../src/modules/scans/scan.validation.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { fakeInference, fakeStorage, imageFile, memoryScans } from './helpers.js';

for (const format of ['jpeg', 'png', 'webp'] as const) {
  test(`${format} private storage removes identifying EXIF/XMP and preserves input identity`, async () => {
    const file = await imageFile(format);
    file.buffer = await sharp(file.buffer)
      .withExif({ IFD0: { Artist: 'PRIVATE_CAMERA_OWNER', ImageDescription: 'PRIVATE_LOCATION' } })
      .withXmp('<x:xmpmeta xmlns:x="adobe:ns:meta/">PRIVATE_GPS_LOCATION</x:xmpmeta>')
      .toBuffer();
    const original = Buffer.from(file.buffer);
    const image = await validateImage(file);
    assert.ok((await sharp(image.bytes).metadata()).exif);
    const stored = await privateStorageImage(image);
    const metadata = await sharp(stored.bytes).metadata();
    assert.equal(metadata.exif, undefined);
    assert.equal(metadata.xmp, undefined);
    assert.equal(metadata.iptc, undefined);
    assert.equal(metadata.orientation, undefined);
    assert.equal(metadata.format, format);
    assert.equal(stored.mimeType, image.mimeType);
    assert.deepEqual(image.bytes, original);
    assert.equal(stored.bytes.includes(Buffer.from('PRIVATE_')), false);
  });
}

test('privacy encoding bakes portrait orientation into display pixels, never the inference input', async () => {
  const file = await imageFile('jpeg', 6);
  const image = await validateImage(file);
  const stored = await privateStorageImage(image);
  assert.equal(stored.width, image.height);
  assert.equal(stored.height, image.width);
  assert.equal(stored.orientation, 1);
  assert.equal(image.orientation, 6);
  assert.equal(image.bytes, file.buffer);
  const { repository } = memoryScans();
  const inference = fakeInference();
  const provider = fakeStorage();
  let storedBytes: Buffer | undefined;
  const service = createScanService(
    repository,
    {
      ...provider.storage,
      async upload(input, id) {
        storedBytes = (await privateStorageImage(input)).bytes;
        return provider.storage.upload(input, id);
      },
    },
    silentLogger,
    inference.client,
  );
  await service.create(file, randomUUID(), null);
  assert.ok(storedBytes);
  assert.equal(inference.calls[0]?.bytes, file.buffer);
  assert.notDeepEqual(storedBytes, file.buffer);
});

test('storage namespaces reject cross-purpose uploads and deletes before provider I/O', async () => {
  const environment = {
    ...testEnvironment,
    CLOUDINARY_CLOUD_NAME: 'fixture',
    CLOUDINARY_API_KEY: '123',
    CLOUDINARY_API_SECRET: 'fixture-secret',
  };
  const image = await validateImage(await imageFile());
  for (const purpose of ['scans', 'profiles'] as const) {
    const other = purpose === 'scans' ? 'profiles' : 'scans';
    const storage = createImageStorage(environment, purpose);
    const id = `maizedoctor/${other}/${randomUUID()}`;
    await assert.rejects(storage.upload(image, id), (error: unknown) => error instanceof AppError);
    await assert.rejects(storage.destroy(id), (error: unknown) => error instanceof AppError);
  }
});

test('protected image reader fixes provider origin/namespace, strips metadata and rejects SSRF and redirects', async () => {
  const image = await imageFile();
  const legacy = await sharp(image.buffer)
    .withExif({ IFD0: { Artist: 'PRIVATE_CAMERA_FIXTURE' } })
    .png()
    .toBuffer();
  assert.ok((await sharp(legacy).metadata()).exif);
  const id = `maizedoctor/scans/${randomUUID()}`;
  const url = `https://res.cloudinary.com/fixture/image/authenticated/s--abcdefgh--/v123/${id}.png`;
  let calls = 0;
  let providerStatus = 200;
  const read = createPrivateImageReader(
    { CLOUDINARY_CLOUD_NAME: 'fixture' },
    async (_url, options) => {
      calls++;
      assert.equal(new URL(String(_url)).search, '');
      assert.equal(options?.redirect, 'manual');
      return new Response(new Uint8Array(legacy), {
        status: providerStatus,
        headers: { 'Content-Type': 'image/png' },
      });
    },
  );
  const location = { url, publicId: id, purpose: 'scans' as const };
  const result = await read(location);
  assert.equal(result.mimeType, 'image/png');
  assert.equal((await sharp(result.bytes).metadata()).exif, undefined);
  await read({ ...location, url: `${url}?_a=fixture_sdk_analytics` });
  for (const bad of [
    url.replace('https:', 'http:'),
    url.replace('res.cloudinary.com', '127.0.0.1'),
    url.replace('res.cloudinary.com', 'res.cloudinary.com.evil.invalid'),
    `${url}?fetch=http://127.0.0.1`,
    url.replace('/fixture/', '/another-cloud/'),
    url.replace('/scans/', '/profiles/'),
  ]) {
    await assert.rejects(read({ ...location, url: bad }));
  }
  assert.equal(calls, 2);
  providerStatus = 302;
  await assert.rejects(
    read(location),
    (error: unknown) => error instanceof AppError && error.code === 'UPLOAD_UNAVAILABLE',
  );
});

test('protected image provider concurrency rejects excess work and releases slots after failures', async () => {
  const image = await imageFile();
  const waiting: ((response: Response) => void)[] = [];
  const id = `maizedoctor/scans/${randomUUID()}`;
  const location = {
    url: `https://res.cloudinary.com/fixture/image/authenticated/s--abcdefgh--/v1/${id}.png`,
    publicId: id,
    purpose: 'scans' as const,
  };
  const read = createPrivateImageReader(
    { CLOUDINARY_CLOUD_NAME: 'fixture' },
    async () => new Promise<Response>((resolve) => waiting.push(resolve)),
  );
  const first = read(location),
    second = read(location);
  await assert.rejects(
    read(location),
    (error: unknown) => error instanceof AppError && error.code === 'RATE_LIMITED',
  );
  assert.equal(waiting.length, 2);
  for (const resolve of waiting)
    resolve(
      new Response(new Uint8Array(image.buffer), { headers: { 'Content-Type': 'image/png' } }),
    );
  await Promise.all([first, second]);
  const next = read(location);
  waiting[2]?.(new Response('provider failure', { status: 503 }));
  await assert.rejects(next);
});

test('protected scan HTTP images require owner or anonymous capability; Admin has no bypass', async () => {
  const memory = memoryRepository();
  const auth = createAuthService(testEnvironment, memory.repository);
  const credentials = (kind: string) => ({
    email: `${kind}@fixture.invalid`,
    password: 'long synthetic security fixture password',
  });
  await auth.register(credentials('owner'));
  await auth.register(credentials('other'));
  await auth.createAdmin(credentials('admin'));
  const owner = await auth.login(credentials('owner'));
  const other = await auth.login(credentials('other'));
  const admin = await auth.login(credentials('admin'));
  const ownerId = (await auth.authenticate(owner.accessToken)).userId;
  const { repository } = memoryScans();
  const storage = fakeStorage();
  const service = createScanService(repository, storage.storage, silentLogger);
  const key = randomUUID();
  const file = await imageFile();
  const guest = await service.create(file, key, null);
  const owned = await service.create(file, randomUUID(), ownerId);
  const app = express();
  app.use(requestContext(silentLogger));
  app.use(
    '/api/v1/scans',
    scanRoutes(testEnvironment, auth, service, async () => ({
      bytes: file.buffer,
      mimeType: 'image/png',
    })),
  );
  app.use(errorHandler(silentLogger));
  await withServer(app, async (base) => {
    const path = (id: string) => `${base}/api/v1/scans/${id}/image`;
    assert.equal((await fetch(path(guest.scan.id))).status, 401);
    assert.equal(
      (await fetch(path(guest.scan.id), { headers: { 'Idempotency-Key': randomUUID() } })).status,
      404,
    );
    const authorized = await fetch(path(guest.scan.id), { headers: { 'Idempotency-Key': key } });
    assert.equal(authorized.status, 200);
    assert.equal(authorized.headers.get('cache-control'), 'private, no-store');
    assert.deepEqual(Buffer.from(await authorized.arrayBuffer()), file.buffer);
    for (const [token, expected] of [
      [owner.accessToken, 200],
      [other.accessToken, 404],
      [admin.accessToken, 403],
    ] as const) {
      assert.equal(
        (await fetch(path(owned.scan.id), { headers: { Authorization: `Bearer ${token}` } }))
          .status,
        expected,
      );
    }
    await auth.logout(owner.refreshToken);
    assert.equal(
      (
        await fetch(path(owned.scan.id), {
          headers: { Authorization: `Bearer ${owner.accessToken}` },
        })
      ).status,
      401,
    );
    assert.equal(JSON.stringify(owned.scan).includes('res.cloudinary.com'), false);
    assert.equal(owned.scan.image.url, `scans/${owned.scan.id}/image`);
  });
});
