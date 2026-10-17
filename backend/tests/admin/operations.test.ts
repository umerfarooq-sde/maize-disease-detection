import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import { createOperationsService } from '../../src/modules/admin/operations.service.js';
import type {
  OperationEvent,
  OperationsRepository,
} from '../../src/modules/admin/operations.repository.js';
import { operationsRoutes } from '../../src/modules/admin/operations.routes.js';
import { AppError } from '../../src/errors/app-error.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { memoryRepository } from '../auth/helpers.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { Prisma } from '../../src/generated/prisma/client.js';
function fixture() {
  const rows: OperationEvent[] = [];
  const repository: OperationsRepository = {
    async record(event) {
      rows.push(event);
    },
    async aggregate() {
      return { totals: [], daily: [] };
    },
  };
  return { rows, repository, service: createOperationsService(repository, silentLogger) };
}

test('close drains the owned writer before database teardown and rejects later recording', async () => {
  const f = fixture();
  let release: (() => void) | undefined;
  let disconnected = false;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  f.repository.record = async (event) => {
    await gate;
    assert.equal(disconnected, false, 'A telemetry write must not outlive its database owner.');
    f.rows.push(event);
  };
  await f.service.measure('RETRIEVAL', async () => true);
  await f.service.measure('GENERATION', async () => true);
  let closed = false;
  const closing = f.service.close().then(() => {
    closed = true;
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(closed, false);
  release?.();
  await closing;
  disconnected = true;
  assert.equal(f.rows.length, 2);
  assert.equal(await f.service.measure('RETRIEVAL', async () => 7), 7);
  assert.equal(f.rows.length, 2);
  assert.equal((await f.service.summary('2026-10-01', '2026-10-02')).collection.localDropped, 1);
});
test('operational producer records one metadata-only event per attempt and preserves abstention', async () => {
  const f = fixture();
  assert.equal(await f.service.measure('INFERENCE', async () => 42), 42);
  await f.service.measure('GENERATION', async () => ({ status: 'INSUFFICIENT_INFORMATION' }));
  await f.service.flush();
  assert.equal(f.rows.length, 2);
  assert.equal(f.rows[1]?.outcome, 'ABSTAINED');
  assert.deepEqual(
    Object.keys(f.rows[0]!).sort(),
    ['id', 'scope', 'operation', 'outcome', 'durationMs', 'category', 'occurredAt'].sort(),
  );
  assert.equal(new Set(f.rows.map((row) => row.id)).size, 2);
});
test('provider failure and retry are distinct attempts with safe categories', async () => {
  const f = fixture(),
    error = new AppError('GEN_TIMEOUT');
  await assert.rejects(
    f.service.measure('GENERATION', async () => {
      throw error;
    }),
    (e) => e === error,
  );
  await f.service.measure('GENERATION', async () => ({ status: 'GROUNDED' }));
  await f.service.flush();
  assert.equal(f.rows[0]?.category, 'TIMEOUT');
  assert.equal(f.rows[0]?.outcome, 'FAILED');
  assert.equal(f.rows[1]?.outcome, 'SUCCESS');
});
test('telemetry storage failure never replaces successful data or original downstream errors', async () => {
  const f = fixture();
  f.repository.record = async () => {
    throw new Error('private storage failure');
  };
  assert.equal(await f.service.measure('RETRIEVAL', async () => 7), 7);
  await assert.rejects(
    f.service.measure('INFERENCE', async () => {
      throw new AppError('INFERENCE_UNAVAILABLE');
    }),
    (e) => e instanceof AppError && e.code === 'INFERENCE_UNAVAILABLE',
  );
  await f.service.flush();
  const summary = await f.service.summary('2026-10-01', '2026-10-02');
  assert.equal(summary.collection.localDropped, 2);
});
test('concurrent telemetry writes are bounded and loss is explicitly reported', async () => {
  const f = fixture(),
    release: (() => void)[] = [];
  let writes = 0;
  f.repository.record = async () => {
    if (++writes === 1) await new Promise<void>((resolve) => release.push(resolve));
  };
  const work = Array.from({ length: 132 }, () => f.service.measure('RETRIEVAL', async () => true));
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(release.length, 1);
  release.forEach((resolve) => {
    resolve();
  });
  await Promise.all(work);
  await f.service.flush();
  assert.equal(writes, 129);
  assert.equal((await f.service.summary('2026-10-01', '2026-10-02')).collection.localDropped, 3);
});
test('aggregation failure is unavailable, never a fabricated zero', async () => {
  const f = fixture();
  f.repository.aggregate = async () => {
    throw new Error('private');
  };
  const result = await f.service.summary('2026-10-01', '2026-10-02');
  assert.equal(result.status, 'UNAVAILABLE');
  assert.equal(result.totals, null);
});

test('aggregate degradation logs safe acquisition category without leaking dependency text', async () => {
  const f = fixture();
  const warnings: unknown[] = [];
  const logger = silentLogger.child({});
  logger.warn = ((entry: unknown) => warnings.push(entry)) as typeof logger.warn;
  f.repository.aggregate = async () => {
    throw new Prisma.PrismaClientKnownRequestError(
      'Unable to start a transaction in the given time. postgresql://private-marker',
      { code: 'P2028', clientVersion: 'fixture' },
    );
  };
  const service = createOperationsService(f.repository, logger);
  const result = await service.summary('2026-10-01', '2026-10-02');
  assert.equal(result.status, 'UNAVAILABLE');
  assert.equal(result.totals, null);
  assert.deepEqual(warnings, [
    {
      event: 'ai_telemetry_aggregate_unavailable',
      stage: 'AGGREGATE',
      dependencyCode: 'P2028',
      databaseFailureKind: 'TRANSACTION_ACQUISITION_TIMEOUT',
    },
  ]);
  assert.ok(!JSON.stringify({ result, warnings }).includes('private-marker'));
});
test('AI operational endpoint requires ADMIN and validates date filters before aggregate work', async () => {
  const f = fixture(),
    auth = createAuthService(testEnvironment, memoryRepository().repository);
  const password = 'synthetic test password';
  await auth.createAdmin({ email: 'operations-admin@example.invalid', password });
  await auth.register({ email: 'operations-farmer@example.invalid', password });
  const admin = (await auth.login({ email: 'operations-admin@example.invalid', password }))
    .accessToken;
  const farmer = (await auth.login({ email: 'operations-farmer@example.invalid', password }))
    .accessToken;
  const app = express();
  app.use(requestContext(silentLogger));
  app.use('/api/v1', operationsRoutes(auth, f.service));
  app.use(errorHandler(silentLogger));
  await withServer(app, async (base) => {
    const url = base + '/api/v1/admin/ai-operations';
    assert.equal((await fetch(url)).status, 401);
    assert.equal(
      (await fetch(url, { headers: { Authorization: `Bearer ${farmer}` } })).status,
      403,
    );
    assert.equal(
      (await fetch(url + '?from=2026-10-01', { headers: { Authorization: `Bearer ${admin}` } }))
        .status,
      400,
    );
    const response = await fetch(url + '?from=2026-10-01&to=2026-10-02', {
      headers: { Authorization: `Bearer ${admin}` },
    });
    assert.equal(response.status, 200);
    const value = await response.json();
    assert.equal(value.data.status, 'COLLECTED');
    assert.deepEqual(value.data.totals, []);
  });
});
