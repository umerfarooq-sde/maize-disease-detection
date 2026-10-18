import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import { Prisma } from '../../src/generated/prisma/client.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { silentLogger, withServer } from './helpers.js';
import { databaseDiagnostics } from '../../src/utils/database-diagnostics.js';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { safeLogFile } from '../../src/infrastructure/safe-log.js';

test('transaction diagnostics distinguish acquisition from expiry without dependency text', () => {
  for (const [message, expected] of [
    [
      'Unable to start a transaction in the given time private-marker',
      'TRANSACTION_ACQUISITION_TIMEOUT',
    ],
    ['Transaction already closed: expired transaction private-marker', 'TRANSACTION_DEADLINE'],
  ] as const) {
    const result = databaseDiagnostics(
      new Prisma.PrismaClientKnownRequestError(message, {
        code: 'P2028',
        clientVersion: 'fixture',
      }),
    );
    assert.equal(result.databaseFailureKind, expected);
    assert.ok(!JSON.stringify(result).includes('private-marker'));
  }
});

test('untrusted dependency codes and ordinary exceptions are not serialized', () => {
  assert.deepEqual(databaseDiagnostics({ code: 'P2028', message: 'private-marker' }), {});
  assert.deepEqual(databaseDiagnostics(new Error('private-marker')), {});
  assert.deepEqual(
    databaseDiagnostics(
      new Prisma.PrismaClientKnownRequestError('private-marker', {
        code: 'private-marker',
        clientVersion: 'fixture',
      }),
    ),
    {},
  );
});

test('database failure logs only a bounded code; public responses omit driver details', async () => {
  const entries: unknown[] = [];
  const logger = silentLogger.child({});
  logger.error = ((entry: unknown) => entries.push(entry)) as typeof logger.error;
  const app = express();
  app.use(requestContext(logger));
  app.get('/fixture', () => {
    throw new Prisma.PrismaClientKnownRequestError(
      'postgresql://private-marker password=private-marker SELECT private-marker',
      { code: 'P2028', clientVersion: 'fixture', meta: { secret: 'private-marker' } },
    );
  });
  app.use(errorHandler(logger));
  await withServer(app, async (base) => {
    const result = await fetch(`${base}/fixture`);
    assert.equal(result.status, 500);
    const body = await result.text();
    assert.ok(!body.includes('private-marker'));
    assert.ok(!body.includes('P2028'));
  });
  assert.equal(entries.length, 1);
  assert.equal((entries[0] as { dependencyCode: string }).dependencyCode, 'P2028');
  assert.ok(!JSON.stringify(entries).includes('private-marker'));
});

test('raw and wrapped adapter timeouts retain bounded stages without private messages', () => {
  assert.deepEqual(databaseDiagnostics(new Error('Query read timeout')), {
    dependencyCode: 'PG_DRIVER',
    databaseFailureKind: 'QUERY_READ_TIMEOUT',
  });
  const wrapped = new Prisma.PrismaClientUnknownRequestError(
    'private-marker SQL=private-marker Query read timeout',
    { clientVersion: 'fixture' },
  );
  assert.deepEqual(databaseDiagnostics(wrapped), {
    dependencyCode: 'PRISMA_DRIVER',
    databaseFailureKind: 'QUERY_READ_TIMEOUT',
  });
  assert.deepEqual(databaseDiagnostics(new Error('private-marker Query read timeout')), {});
});

test('central log projection retains safe database stages and excludes private payloads', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'maizedoctor-safe-log-'));
  try {
    const sink = safeLogFile(directory);
    sink.write(
      JSON.stringify({
        level: 50,
        event: 'database_fixture',
        ...databaseDiagnostics(new Error('Query read timeout')),
        password: 'private-marker',
        message: 'private-marker',
        query: 'private-marker',
      }),
    );
    const value = await readFile(join(directory, 'node.jsonl'), 'utf8');
    assert.ok(value.includes('QUERY_READ_TIMEOUT'));
    assert.ok(!value.includes('private-marker'));
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
