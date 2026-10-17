import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { PrismaClient } from '../../src/generated/prisma/client.js';
import { createOperationsRepository } from '../../src/modules/admin/operations.repository.js';

test('operational projections use one parameterized snapshot without a short interactive acquisition deadline', async () => {
  const from = '2026-10-01',
    to = '2026-10-02';
  const expected = {
    totals: [
      {
        scope: 'NODE',
        operation: 'INFERENCE',
        requests: 3,
        successes: 2,
        failures: 1,
        abstained: 0,
        averageMs: 20,
        p50Ms: 20,
        p95Ms: 29,
      },
    ],
    daily: [{ date: from, scope: 'NODE', requests: 3, failures: 1 }],
  };
  let queries = 0;
  const database = {
    async $transaction() {
      throw new Error('A cold connection exceeds the former one-second acquisition deadline.');
    },
    async $queryRaw<T>(parts: TemplateStringsArray, ...parameters: unknown[]): Promise<T> {
      queries++;
      assert.deepEqual(parameters, [from, to]);
      assert.ok(!parts.join('').includes(from));
      assert.ok(!parts.join('').includes(to));
      return [expected] as T;
    },
  } as unknown as PrismaClient;
  assert.deepEqual(await createOperationsRepository(database).aggregate(from, to), expected);
  assert.equal(queries, 1);
});

test('missing operational aggregate output fails rather than inventing empty statistics', async () => {
  const database = {
    async $queryRaw() {
      return [];
    },
  } as unknown as PrismaClient;
  await assert.rejects(
    createOperationsRepository(database).aggregate('2026-10-01', '2026-10-02'),
    /Operational aggregate row missing/,
  );
});
