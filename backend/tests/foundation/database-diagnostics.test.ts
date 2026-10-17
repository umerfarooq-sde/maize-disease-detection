import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import { Prisma } from '../../src/generated/prisma/client.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { silentLogger, withServer } from './helpers.js';
import { databaseDiagnostics } from '../../src/utils/database-diagnostics.js';

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
