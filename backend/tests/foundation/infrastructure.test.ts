import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { EventEmitter } from 'node:events';
import { fork } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import express from 'express';
import type { Request, Response } from 'express';
import { withSecretFile } from '../../src/config/secrets.js';
import { createDistributedQuota, type QuotaStore } from '../../src/infrastructure/quotas.js';
import { installOperations } from '../../src/infrastructure/metrics.js';
import { requestRateLimit } from '../../src/middleware/rate-limit.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { silentLogger, testEnvironment, withServer } from './helpers.js';

function storeFixture() {
  const keys: string[][] = [];
  const releases: string[] = [];
  const store: QuotaStore = {
    async start() {},
    ready: () => true,
    async evaluate(values) {
      keys.push(values);
      return [1, 0];
    },
    async release(_key, id) {
      releases.push(id);
    },
    async close() {},
  };
  return { store, keys, releases };
}

test('actual generation/index/scan routes use configured shared capacity', async () => {
  const fixture = storeFixture();
  const calls: { keys: string[]; args: string[] }[] = [];
  fixture.store.evaluate = async (keys, args) => {
    calls.push({ keys, args });
    return [1, 0];
  };
  const quota = createDistributedQuota(
    { ...testEnvironment, INFERENCE_MAX_CONCURRENCY: 2 },
    fixture.store,
    silentLogger,
  );
  const app = express();
  app.set('trust proxy', 'loopback'); // Only this owned HTTP test uses loopback forwarding.
  app.locals.distributedQuota = quota;
  app.use((_request, response, next) => {
    response.locals.principal = {
      userId: 'synthetic-account',
      sessionId: 'synthetic-session',
      role: 'FARMER',
      user: {
        email: 'synthetic@example.invalid',
        role: 'FARMER',
        createdAt: new Date().toISOString(),
      },
    };
    next();
  });
  for (const path of [
    '/knowledge/ask',
    '/scans/:scanId/explanation',
    '/admin/knowledge/documents/:id/index',
    '/scans/:id',
  ]) {
    app.post(path, requestRateLimit(10), (_request, response) => response.json({ success: true }));
  }
  app.use(errorHandler(silentLogger));
  await withServer(app, async (base) => {
    for (const ip of ['2001:db8:abcd:1200::1', '2001:db8:abcd:12ff::2']) {
      assert.equal(
        (
          await fetch(base + '/knowledge/ask', {
            method: 'POST',
            headers: { 'X-Forwarded-For': ip },
          })
        ).status,
        200,
      );
    }
    await fetch(base + '/scans/synthetic/explanation', { method: 'POST' });
    await fetch(base + '/admin/knowledge/documents/synthetic/index', { method: 'POST' });
    await fetch(base + '/scans/synthetic', { method: 'POST' });
  });
  await quota.close();
  assert.equal(calls[0]?.keys[0], calls[1]?.keys[0]);
  assert.equal(calls[0]?.keys[1], calls[1]?.keys[1]);
  assert.deepEqual(
    calls.map((row) => row.args[2]),
    ['2', '2', '2', '1', '2'],
  );
  assert.ok(!JSON.stringify(calls).includes('synthetic-account'));
});

test('mounted secrets reject unknown keys/conflicts and never echo private values', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'maizedoctor-secrets-'));
  try {
    const path = join(directory, 'config.json');
    await writeFile(path, JSON.stringify({ JWT_SECRET: 'private-fixture-marker' }));
    assert.equal(
      withSecretFile({ MAIZEDOCTOR_SECRETS_FILE: path })['JWT_SECRET'],
      'private-fixture-marker',
    );
    assert.throws(
      () => withSecretFile({ MAIZEDOCTOR_SECRETS_FILE: path, JWT_SECRET: 'different-marker' }),
      (error) => error instanceof Error && !error.message.includes('marker'),
    );
    await writeFile(path, JSON.stringify({ NODE_OPTIONS: '--private-marker' }));
    assert.throws(
      () => withSecretFile({ MAIZEDOCTOR_SECRETS_FILE: path }),
      /Invalid runtime secret file/,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('distributed denial/storage failure is fail closed; leases are released once and tracked', async () => {
  const fixture = storeFixture();
  const quota = createDistributedQuota(testEnvironment, fixture.store, silentLogger);
  const app = express();
  app.locals.distributedQuota = quota;
  app.use(requestContext(silentLogger));
  app.post('/assistant/questions', requestRateLimit(2), (_req, res) => {
    res.json({ success: true });
  });
  app.use(errorHandler(silentLogger));
  await quota.start();
  try {
    await withServer(app, async (base) => {
      assert.equal((await fetch(base + '/assistant/questions', { method: 'POST' })).status, 200);
      fixture.store.evaluate = async () => [0, 1000];
      const denied = await fetch(base + '/assistant/questions', { method: 'POST' });
      assert.equal(denied.status, 429);
      assert.equal(denied.headers.get('Retry-After'), '1');
      fixture.store.evaluate = async () => {
        throw new Error('redis://private-fixture-marker');
      };
      const unavailable = await fetch(base + '/assistant/questions', { method: 'POST' });
      assert.equal(unavailable.status, 503);
      assert.ok(!(await unavailable.text()).includes('marker'));
    });
  } finally {
    await quota.close();
  }
  assert.equal(fixture.releases.length, 1);
  assert.ok(!JSON.stringify(fixture.keys).includes('127.0.0.1'));
});

test('one inference slot rejects excess 2 and 4 request bursts and permits retry after release', { timeout: 10000 }, async () => {
  for (const count of [1, 2, 4]) {
    const active = new Set<string>();
    const fixture = storeFixture();
    let released: () => void = () => {};
    const releaseObserved = new Promise<void>((resolve) => { released = resolve; });
    fixture.store.evaluate = async (_keys, args) => {
      assert.equal(args[2], '1');
      if (active.size >= Number(args[2])) return [0, 1000];
      const lease = args[4];
      assert.ok(lease);
      active.add(lease);
      return [1, 0];
    };
    fixture.store.release = async (_key, identity) => {
      active.delete(identity);
      released();
    };
    const quota = createDistributedQuota(testEnvironment, fixture.store, silentLogger);
    const app = express();
    app.locals.distributedQuota = quota;
    let entered: () => void = () => {};
    let release: () => void = () => {};
    const started = new Promise<void>((resolve) => { entered = resolve; });
    const gate = new Promise<void>((resolve) => { release = resolve; });
    let hold = true;
    const scans = express.Router();
    scans.post('/', requestRateLimit(100), async (_request, response) => {
      response.flushHeaders();
      entered();
      if (hold) await gate;
      response.end();
    });
    app.use('/api/v1/scans', scans);
    app.use(errorHandler(silentLogger));
    try {
      await withServer(app, async (base) => {
        let first: Awaited<ReturnType<typeof fetch>> | undefined;
        try {
          first = await fetch(`${base}/api/v1/scans`, { method: 'POST' });
          await started;
          assert.equal(first.status, 200);
          const excess = await Promise.all(
            Array.from({ length: count - 1 }, () =>
              fetch(`${base}/api/v1/scans`, { method: 'POST' }),
            ),
          );
          assert.ok(excess.every((response) => response.status === 429));
          assert.ok(excess.every((response) => response.headers.get('Retry-After') === '1'));
          assert.equal(active.size, 1);
          hold = false;
          release();
          await releaseObserved;
          assert.equal(active.size, 0);
          const retry = await fetch(`${base}/api/v1/scans`, { method: 'POST' });
          assert.equal(retry.status, 200);
          await retry.arrayBuffer();
        } finally {
          hold = false;
          release();
          await first?.arrayBuffer().catch(() => undefined);
        }
      });
    } finally {
      release();
      await quota.close();
    }
    assert.equal(active.size, 0);
  }
});

test('private operations authentication, unavailable readiness and route-template-only metrics', async () => {
  const app = express();
  const environment = { ...testEnvironment, OPERATIONS_TOKEN: 'synthetic-operations-token' };
  let available = false;
  installOperations(app, environment, {
    async checkDatabase() {
      if (!available) throw new Error('private marker');
    },
  });
  app.get('/private/:id', (_req, res) => res.end());
  const headers = { 'X-Operations-Token': environment.OPERATIONS_TOKEN };
  await withServer(app, async (base) => {
    assert.equal((await fetch(base + '/internal/metrics')).status, 404);
    assert.equal((await fetch(base + '/internal/ready', { headers })).status, 503);
    available = true;
    assert.equal((await fetch(base + '/internal/ready', { headers })).status, 200);
    await fetch(base + '/private/private-marker');
    const metrics = await (await fetch(base + '/internal/metrics', { headers })).text();
    assert.ok(metrics.includes('/private/:id'));
    assert.ok(!metrics.includes('private-marker'));
    assert.ok(!metrics.includes(environment.OPERATIONS_TOKEN));
  });
});

test('completed uploads retain shared concurrency after disconnect; interrupted bodies release once', async () => {
  const fixture = storeFixture();
  const quota = createDistributedQuota(testEnvironment, fixture.store, silentLogger);
  await quota.start();
  try {
    for (const complete of [true, false]) {
      const response = Object.assign(new EventEmitter(), { locals: {}, setHeader() {} });
      const request = {
        complete,
        route: { path: '/scans' },
        baseUrl: '/api/v1',
        method: 'POST',
        ip: '127.0.0.1',
        socket: {},
      };
      const before = fixture.releases.length;
      await quota.admit(request as unknown as Request, response as unknown as Response, 2, 1000);
      response.emit('close');
      assert.equal(fixture.releases.length, before + Number(!complete));
      if (complete)
        (response.locals as { releaseInferenceQuota?: () => void }).releaseInferenceQuota?.();
      response.emit('finish');
      response.emit('close');
      assert.equal(fixture.releases.length, before + 1);
    }
  } finally {
    await quota.close();
  }
});

test('real Redis shares atomic limits across two independent Node OS processes', {
  skip:
    process.env['RUN_REDIS_TESTS'] !== '1'
      ? 'Opt-in requires an isolated Redis endpoint; no fake Redis claim.'
      : false,
}, async () => {
  const url = process.env['TEST_REDIS_URL'];
  assert.ok(url, 'TEST_REDIS_URL is required');
  const namespace = `test-${process.pid}-${Date.now()}`;
  const children = [0, 1].map(() =>
    fork(fileURLToPath(new URL('../fixtures/redis-instance.ts', import.meta.url)), [], {
      cwd: fileURLToPath(new URL('../../', import.meta.url)),
      execArgv: ['--import', 'tsx'],
      stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
      env: {
        PATH: process.env['PATH'],
        SystemRoot: process.env['SystemRoot'],
        NODE_ENV: 'test',
        TEST_REDIS_URL: url,
        TEST_QUOTA_NAMESPACE: namespace,
        TEST_QUOTA_KEY: testEnvironment.JWT_SECRET,
      },
    }),
  );
  try {
    const origins = await Promise.all(
      children.map(
        (child) =>
          new Promise<string>((resolve, reject) => {
            const deadline = setTimeout(
              () => reject(new Error('Redis fixture startup deadline')),
              10000,
            );
            child.once('exit', () => {
              clearTimeout(deadline);
              reject(new Error('Redis fixture exited'));
            });
            child.once('message', (message: unknown) => {
              clearTimeout(deadline);
              assert.ok(message && typeof message === 'object' && 'port' in message);
              const port = Number(message.port);
              assert.ok(Number.isInteger(port) && port > 0);
              resolve(`http://127.0.0.1:${port}`);
            });
          }),
      ),
    );
    const [first, second] = origins;
    assert.ok(first && second && children[0]?.pid !== children[1]?.pid);
    const statuses = await Promise.all(
      [first, second, first, second, first, second].map(
        async (origin) => (await fetch(origin + '/quota')).status,
      ),
    );
    assert.equal(statuses.filter((status) => status === 200).length, 3);
    assert.equal(statuses.filter((status) => status === 429).length, 3);
    await new Promise((resolve) => setTimeout(resolve, 3100));
    assert.equal((await fetch(second + '/quota')).status, 200);
  } finally {
    await Promise.all(
      children.map(
        (child) =>
          new Promise<void>((resolve) => {
            if (child.exitCode !== null) {
              resolve();
              return;
            }
            const deadline = setTimeout(() => child.kill('SIGKILL'), 5000);
            child.once('exit', () => {
              clearTimeout(deadline);
              resolve();
            });
            if (child.connected) child.send('stop');
            else child.kill();
          }),
      ),
    );
  }
});
