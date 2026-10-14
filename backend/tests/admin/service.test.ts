import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  createDashboardRepository,
  dashboardSummarySql,
} from '../../src/modules/admin/dashboard.repository.js';
import { createDashboardService } from '../../src/modules/admin/dashboard.service.js';
import { dashboardStoredSchema } from '../../src/modules/admin/dashboard.types.js';
import { resolveAnalyticsRange } from '../../src/modules/analytics/analytics.types.js';
import { now, rangeQuery } from '../analytics/helpers.js';
import { dashboardStored } from './helpers.js';

test('dashboard preserves system counts, UTC zero days and explicitly unavailable telemetry', async () => {
  const calls: unknown[] = [];
  const service = createDashboardService(
    {
      async summary(range) {
        calls.push(range);
        return dashboardStored();
      },
    },
    { AI_SERVICE_URL: '', AI_MODEL_VERSION: '' },
    () => now,
  );
  const result = await service.summary(rangeQuery);
  assert.equal(calls.length, 1);
  assert.equal(result.scans.totals.totalScans, 8);
  assert.equal(result.ownership.anonymous, 3);
  assert.equal(result.farmers.total, 3);
  assert.equal(result.scans.distribution.length, 5);
  assert.deepEqual(
    result.scans.daily.map((item) => item.count),
    [5, 3],
  );
  assert.deepEqual(result.model, {
    registry: 'NOT_PROMOTED',
    productionVersion: null,
    configuredVersion: null,
    inferenceConfigured: false,
    readiness: 'NOT_CHECKED',
  });
  assert.equal(result.aiRequestStatistics, 'NOT_RECORDED');
  assert.ok(!JSON.stringify(result).includes('accuracy'));
});
test('single versus ambiguous production registry never guesses current model or live readiness', async () => {
  for (const count of [1, 2, 3]) {
    const stored = dashboardStored();
    stored.productionCount = count;
    stored.productionVersions =
      count === 1 ? ['registered-v1'] : ['registered-v1', 'registered-v2'];
    const result = await createDashboardService(
      {
        async summary() {
          return stored;
        },
      },
      {
        AI_SERVICE_URL: 'https://internal.example.test',
        AI_MODEL_VERSION: 'configured-research-v2',
      },
      () => now,
    ).summary(rangeQuery);
    assert.equal(result.model.registry, count === 1 ? 'SINGLE_PRODUCTION' : 'MULTIPLE_PRODUCTION');
    assert.equal(result.model.productionVersion, count === 1 ? 'registered-v1' : null);
    assert.equal(result.model.configuredVersion, 'configured-research-v2');
    assert.equal(result.model.readiness, 'NOT_CHECKED');
  }
});
test('empty system is zero-filled; invalid date ranges fail before repository work', async () => {
  const stored = dashboardStored();
  for (const key of Object.keys(stored.scans.totals) as (keyof typeof stored.scans.totals)[])
    stored.scans.totals[key] = 0;
  stored.scans.daily = [];
  stored.scans.distribution = [];
  stored.scans.uncertainty = { lowConfidence: 0, confident: 0, unavailable: 0 };
  stored.ownership = { authenticated: 0, anonymous: 0 };
  stored.farmers = { total: 0, active: 0, suspended: 0, deactivated: 0 };
  let calls = 0;
  const service = createDashboardService(
    {
      async summary() {
        calls++;
        return stored;
      },
    },
    { AI_SERVICE_URL: '', AI_MODEL_VERSION: '' },
    () => now,
  );
  const result = await service.summary({});
  assert.equal(result.scans.daily.length, 30);
  assert.equal(result.farmers.total, 0);
  await assert.rejects(service.summary({ from: '2026-10-16', to: '2026-10-16' }));
  assert.equal(calls, 1);
});
test('dashboard SQL aggregates on the server, binds dates, bounds recent/version projections and rejects malformed counts', async () => {
  const range = resolveAnalyticsRange(rangeQuery, now);
  const query = dashboardSummarySql(range);
  assert.ok(query.sql.includes('LIMIT 10'));
  assert.ok(query.sql.includes('LIMIT 2'));
  assert.ok(query.sql.includes("role='FARMER'"));
  assert.ok(query.sql.includes("status='PRODUCTION'"));
  assert.ok(!query.sql.includes('2026-10-01'));
  assert.ok(query.values.some((value) => value instanceof Date));
  let statements = 0;
  const database = {
    async $queryRaw() {
      statements++;
      return [{ dashboard: dashboardStored() }];
    },
  };
  // The Prisma generic tag is mocked only at the database boundary.
  const repository = createDashboardRepository(
    database as unknown as Parameters<typeof createDashboardRepository>[0],
  );
  assert.equal((await repository.summary(range)).scans.totals.totalScans, 8);
  assert.equal(statements, 1);
  const malformed = dashboardStored();
  malformed.ownership.anonymous = 99;
  assert.equal(dashboardStoredSchema.safeParse(malformed).success, false);
  assert.equal(
    dashboardStoredSchema.safeParse({ ...dashboardStored(), productionCount: 1 }).success,
    false,
  );
});
