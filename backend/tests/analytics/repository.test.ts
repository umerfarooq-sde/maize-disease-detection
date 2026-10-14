import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import {
  type AnalyticsDatabase,
  createAnalyticsRepository,
} from '../../src/modules/analytics/analytics.repository.js';
import { resolveAnalyticsRange } from '../../src/modules/analytics/analytics.types.js';
import { aggregate, now, rangeQuery } from './helpers.js';

test('summary performs one parameterized aggregate and transfers no full scan rows', async () => {
  const owner = randomUUID();
  const queries: { sql: string; values: unknown[] }[] = [];
  const database = {
    async $queryRaw(query: { sql: string; values: unknown[] }) {
      queries.push(query);
      return [{ summary: aggregate() }];
    },
    scan: {
      findMany() {
        throw new Error('Aggregates must not fetch all scans.');
      },
    },
  };
  const result = await createAnalyticsRepository(database as unknown as AnalyticsDatabase).summary(
    owner,
    resolveAnalyticsRange(rangeQuery, now),
  );
  assert.equal(result.totals.totalScans, 8);
  assert.equal(queries.length, 1);
  const query = queries[0];
  assert.ok(query);
  assert.ok(query.sql.includes('s.user_id='));
  assert.ok(!query.sql.includes(owner));
  assert.ok(query.values.includes(owner));
  assert.ok(query.sql.includes('LEFT JOIN LATERAL'));
  assert.ok(query.sql.includes('ORDER BY created_at DESC, id DESC LIMIT 1'));
  assert.deepEqual(
    query.values.filter((item) => item instanceof Date).map((date) => date.toISOString()),
    ['2026-10-01T00:00:00.000Z', '2026-10-03T00:00:00.000Z'],
  );
});
test('activity bounds page size and validates cursor against both owner and exact date window', async () => {
  const owner = randomUUID();
  const cursor = randomUUID();
  const calls: { operation: string; args: unknown }[] = [];
  const database = {
    scan: {
      async findFirst(args: unknown): Promise<{ id: string } | null> {
        calls.push({ operation: 'cursor', args });
        return { id: cursor };
      },
      async findMany(args: unknown) {
        calls.push({ operation: 'page', args });
        return [];
      },
    },
  };
  const repository = createAnalyticsRepository(database as unknown as AnalyticsDatabase);
  const range = resolveAnalyticsRange(rangeQuery, now);
  await repository.activity(owner, range, 50, cursor);
  const where = {
    userId: owner,
    createdAt: { gte: new Date('2026-10-01T00:00:00Z'), lt: new Date('2026-10-03T00:00:00Z') },
  };
  assert.deepEqual(calls[0]?.args, { where: { ...where, id: cursor }, select: { id: true } });
  const page = calls[1]?.args as {
    where: unknown;
    take: number;
    orderBy: unknown;
    cursor: unknown;
    skip: number;
    select: Record<string, unknown>;
  };
  assert.deepEqual(page.where, where);
  assert.equal(page.take, 51);
  assert.deepEqual(page.cursor, { id: cursor });
  assert.deepEqual(page.orderBy, [{ createdAt: 'desc' }, { id: 'desc' }]);
  assert.ok(!Object.hasOwn(page.select, 'imageUrl'));
  assert.ok(!Object.hasOwn(page.select, 'userId'));
  database.scan.findFirst = async (args) => {
    calls.push({ operation: 'denied', args });
    return null;
  };
  const length = calls.length;
  assert.equal(await repository.activity(owner, range, 50, randomUUID()), null);
  assert.equal(calls.length, length + 1);
});
