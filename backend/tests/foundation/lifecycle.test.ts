import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { test } from 'node:test';
import { type ApplicationDatabase, startApplication } from '../../src/application.js';
import { getDatabaseClient } from '../../src/database/client.js';
import { silentLogger, testEnvironment } from './helpers.js';

function fakeDatabase() {
  const calls: string[] = [];
  const database: ApplicationDatabase = {
    async $connect() {
      calls.push('connect');
    },
    async $queryRaw(query) {
      calls.push(query.join(''));
      return [{ value: 1 }];
    },
    async $disconnect() {
      calls.push('disconnect');
    },
  };
  return { calls, database };
}

test('application reuses one Prisma client instance', () => {
  assert.equal(
    getDatabaseClient(testEnvironment.DATABASE_URL),
    getDatabaseClient(testEnvironment.DATABASE_URL),
  );
});

test('startup verifies database before listening; stop is idempotent and disconnects', async () => {
  const { database, calls } = fakeDatabase();
  const application = await startApplication(
    { ...testEnvironment, PORT: 0 },
    silentLogger,
    database,
  );
  assert.deepEqual(calls, ['connect', 'SELECT 1']);
  const address = application.server.address() as AddressInfo;
  const response = await fetch(`http://127.0.0.1:${address.port}/api/v1/health`);
  assert.equal(response.status, 200);
  await response.text();
  const stopping = application.stop();
  assert.equal(application.stop(), stopping);
  await stopping;
  assert.equal(application.server.listening, false);
  assert.equal(calls.filter((call) => call === 'disconnect').length, 1);
});

test('failed connection or readiness query cleans up without listening', async () => {
  for (const failingMethod of ['$connect', '$queryRaw'] as const) {
    const { database, calls } = fakeDatabase();
    database[failingMethod] = async () => {
      throw new Error('offline');
    };
    await assert.rejects(
      startApplication({ ...testEnvironment, PORT: 0 }, silentLogger, database),
      /offline/,
    );
    assert.equal(calls.at(-1), 'disconnect');
  }
});

test('failed listen cleans up the connected database', async () => {
  const occupied = createServer();
  await new Promise<void>((resolve) => occupied.listen(0, '127.0.0.1', resolve));
  const { database, calls } = fakeDatabase();
  try {
    await assert.rejects(
      startApplication(
        { ...testEnvironment, PORT: (occupied.address() as AddressInfo).port },
        silentLogger,
        database,
      ),
      { code: 'EADDRINUSE' },
    );
    assert.equal(calls.at(-1), 'disconnect');
  } finally {
    await new Promise<void>((resolve) => occupied.close(() => resolve()));
  }
});

test('shutdown waits for in-flight health requests before disconnecting', async () => {
  const { database, calls } = fakeDatabase();
  let finishQuery: (() => void) | undefined;
  let requestStarted: (() => void) | undefined;
  const started = new Promise<void>((resolve) => {
    requestStarted = resolve;
  });
  const application = await startApplication(
    { ...testEnvironment, PORT: 0 },
    silentLogger,
    database,
  );
  database.$queryRaw = async () =>
    new Promise<void>((resolve) => {
      finishQuery = resolve;
      requestStarted?.();
    });
  const address = application.server.address() as AddressInfo;
  const request = fetch(`http://127.0.0.1:${address.port}/api/v1/health`);
  await started;
  const stopping = application.stop();
  assert.ok(!calls.includes('disconnect'));
  finishQuery?.();
  await (await request).text();
  await stopping;
  assert.equal(calls.at(-1), 'disconnect');
});

test('shutdown has a deadline when database cleanup stalls', async () => {
  const { database } = fakeDatabase();
  const application = await startApplication(
    { ...testEnvironment, PORT: 0, SHUTDOWN_TIMEOUT_MS: 30 },
    silentLogger,
    database,
  );
  database.$disconnect = async () => new Promise<void>(() => {});
  await assert.rejects(application.stop(), /timed out/);
  assert.equal(application.server.listening, false);
});
