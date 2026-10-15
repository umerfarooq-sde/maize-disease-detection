import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { test } from 'node:test';
import { createApp } from '../../src/app.js';
import { createDatabaseClient } from '../../src/database/client.js';
import { AppError } from '../../src/errors/app-error.js';
import { createHealthRepository } from '../../src/modules/health/health.repository.js';
import { createAiInferenceClient } from '../../src/modules/inference/inference.client.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from './helpers.js';

async function closedLoopbackPort(): Promise<number> {
  const listener = createServer();
  await new Promise<void>((resolve) => listener.listen(0, '127.0.0.1', resolve));
  const port = (listener.address() as AddressInfo).port;
  await new Promise<void>((resolve, reject) =>
    listener.close((error) => (error ? reject(error) : resolve())),
  );
  return port;
}

test('a genuinely unreachable PostgreSQL endpoint produces safe degraded health, not a false success', async () => {
  const port = await closedLoopbackPort();
  const database = createDatabaseClient(
    `postgresql://127.0.0.1:${port}/synthetic_unavailable`,
    500,
  );
  try {
    const app = createApp(
      testEnvironment,
      silentLogger,
      createHealthRepository(database),
      memoryRepository().repository,
    );
    await withServer(app, async (base) => {
      const response = await fetch(`${base}/api/v1/health`);
      assert.equal(response.status, 503);
      const text = await response.text();
      const body = JSON.parse(text) as { data: { status: string; checks: { database: string } } };
      assert.equal(body.data.status, 'degraded');
      assert.equal(body.data.checks.database, 'down');
      for (const privateText of ['postgresql://', 'ECONNREFUSED', 'Prisma', 'stack'])
        assert.ok(!text.includes(privateText));
    });
  } finally {
    await database.$disconnect();
  }
});

const image = {
  bytes: Buffer.from('synthetic transport fixture'),
  mimeType: 'image/png' as const,
  width: 24,
  height: 24,
  orientation: 1,
};
function client(port: number) {
  return createAiInferenceClient({
    ...testEnvironment,
    AI_SERVICE_URL: `http://127.0.0.1:${port}`,
    AI_SERVICE_TOKEN: randomBytes(32).toString('base64url'),
    AI_SERVICE_TIMEOUT_MS: 1000,
    AI_MODEL_VERSION: 'synthetic-test',
    AI_PREPROCESSING_VERSION: '1.0.0',
  });
}
test('real FastAPI connection refusal maps to a safe unavailable error without provider causes', async () => {
  await assert.rejects(client(await closedLoopbackPort()).predict(image), (error: unknown) => {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, 'INFERENCE_UNAVAILABLE');
    assert.equal(error.cause, undefined);
    assert.ok(!JSON.stringify(error).includes('127.0.0.1'));
    return true;
  });
});
test('real stalled HTTP response obeys the inference deadline and releases the connection', async () => {
  const server = createServer(() => {});
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    await assert.rejects(
      client((server.address() as AddressInfo).port).predict(image),
      (error: unknown) => error instanceof AppError && error.code === 'INFERENCE_TIMEOUT',
    );
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
});
