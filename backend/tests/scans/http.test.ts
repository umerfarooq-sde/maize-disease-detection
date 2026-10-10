import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import express from 'express';
import { createApp } from '../../src/app.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { createScanService } from '../../src/modules/scans/scan.service.js';
import { scanLimits } from '../../src/modules/scans/scan.types.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { fakeStorage, imageFile, memoryScans } from './helpers.js';

test('multipart API enforces authentication, farmer ownership, limits, shape and safe responses', async () => {
  const auth = memoryRepository();
  const scans = memoryScans();
  const cloud = fakeStorage();
  const environment = { ...testEnvironment, SCAN_RATE_LIMIT_MAX: 100 };
  const authService = createAuthService(environment, auth.repository);
  const farmer = {
    email: 'farmer@example.invalid',
    password: 'synthetic farmer password for tests',
  };
  const admin = { email: 'admin@example.invalid', password: 'synthetic administrator password' };
  await authService.register(farmer);
  await authService.createAdmin(admin);
  const farmerToken = (await authService.login(farmer)).accessToken;
  const adminToken = (await authService.login(admin)).accessToken;
  const file = await imageFile();
  const key = randomUUID();
  const app = createApp(
    environment,
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    createScanService(scans.repository, cloud.storage, silentLogger),
  );
  await withServer(app, async (url) => {
    async function send(
      options: {
        token?: string;
        key?: string;
        buffer?: Buffer;
        filename?: string;
        mime?: string;
        extra?: boolean;
        header?: boolean;
      } = {},
    ) {
      const form = new FormData();
      form.append(
        'image',
        new Blob([new Uint8Array(options.buffer ?? file.buffer)], {
          type: options.mime ?? 'image/png',
        }),
        options.filename ?? 'leaf.png',
      );
      if (options.extra) form.append('userId', randomUUID());
      return fetch(`${url}/api/v1/scans`, {
        method: 'POST',
        headers: {
          'Idempotency-Key': options.key ?? randomUUID(),
          ...(options.header === false ? {} : { 'X-Auth-Request': '1' }),
          ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
        },
        body: form,
      });
    }
    const created = await send({ key });
    assert.equal(created.status, 201);
    const json = (await created.json()) as {
      success: boolean;
      data: { id: string; status: string };
      requestId: string;
    };
    assert.equal(json.success, true);
    assert.equal(json.data.status, 'FAILED');
    assert.equal(created.headers.get('cache-control'), 'no-store');
    assert.equal((await send({ key })).status, 200);
    assert.equal(scans.records.size, 1);
    assert.equal((await send({ token: farmerToken })).status, 201);
    assert.ok(
      [...scans.records.values()].some(
        (r) => r.scan?.userId === auth.accounts.get(farmer.email)?.id,
      ),
    );
    assert.equal((await send({ token: 'invalid' })).status, 401);
    assert.equal((await send({ token: adminToken })).status, 403);
    assert.equal((await send({ extra: true })).status, 400);
    assert.equal((await send({ key: 'bad' })).status, 400);
    assert.equal((await send({ header: false })).status, 403);
    assert.equal((await send({ mime: 'image/jpeg' })).status, 415);
    assert.equal((await send({ filename: 'leaf.svg' })).status, 415);
    assert.equal((await send({ buffer: Buffer.alloc(scanLimits.bytes + 1) })).status, 413);
    const broken = await fetch(`${url}/api/v1/scans`, {
      method: 'POST',
      headers: {
        'X-Auth-Request': '1',
        'Idempotency-Key': randomUUID(),
        'Content-Type': 'multipart/form-data; boundary=missing',
      },
      body: 'broken',
    });
    assert.equal(broken.status, 400);
    assert.ok(!JSON.stringify(await broken.json()).includes('stack'));
  });
});
test('upload rate limit runs before image parsing', async () => {
  const auth = memoryRepository();
  const scans = memoryScans();
  const cloud = fakeStorage();
  const app = createApp(
    { ...testEnvironment, SCAN_RATE_LIMIT_MAX: 1 },
    silentLogger,
    { async checkDatabase() {} },
    auth.repository,
    createScanService(scans.repository, cloud.storage, silentLogger),
  );
  await withServer(app, async (url) => {
    assert.equal((await fetch(`${url}/api/v1/scans`, { method: 'POST' })).status, 403);
    assert.equal((await fetch(`${url}/api/v1/scans`, { method: 'POST' })).status, 429);
  });
});

test('disconnected clients keep upload slots reserved until storage work finishes', {
  timeout: 10000,
}, async () => {
  const auth = memoryRepository();
  const scans = memoryScans();
  const cloud = fakeStorage();
  const upload = cloud.storage.upload;
  let entered = 0;
  let release: () => void = () => {};
  let ready: () => void = () => {};
  let disconnected: () => void = () => {};
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const started = new Promise<void>((resolve) => {
    ready = resolve;
  });
  const closed = new Promise<void>((resolve) => {
    disconnected = resolve;
  });
  cloud.storage.upload = async (...args) => {
    entered++;
    if (entered === 2) ready();
    await gate;
    return upload(...args);
  };
  const firstKey = randomUUID();
  const file = await imageFile();
  const observed = express();
  observed.disable('x-powered-by');
  observed.use((request, response, next) => {
    if (request.get('idempotency-key') === firstKey) response.once('close', disconnected);
    next();
  });
  observed.use(
    createApp(
      { ...testEnvironment, SCAN_RATE_LIMIT_MAX: 100 },
      silentLogger,
      { async checkDatabase() {} },
      auth.repository,
      createScanService(scans.repository, cloud.storage, silentLogger),
    ),
  );
  await withServer(observed, async (url) => {
    function send(key = randomUUID(), signal?: AbortSignal) {
      const form = new FormData();
      form.append(
        'image',
        new Blob([new Uint8Array(file.buffer)], { type: 'image/png' }),
        'leaf.png',
      );
      return fetch(`${url}/api/v1/scans`, {
        method: 'POST',
        headers: { 'X-Auth-Request': '1', 'Idempotency-Key': key },
        body: form,
        ...(signal ? { signal } : {}),
      });
    }
    const abort = new AbortController();
    const first = send(firstKey, abort.signal).catch(() => null);
    const second = send();
    try {
      await started;
      abort.abort();
      await first;
      await closed;
      assert.equal((await send()).status, 503);
    } finally {
      release();
    }
    assert.equal((await second).status, 201);
    assert.equal((await send()).status, 201);
  });
});
