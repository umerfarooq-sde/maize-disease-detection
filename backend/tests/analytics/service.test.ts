import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import { createAnalyticsService } from '../../src/modules/analytics/analytics.service.js';
import {
  activityQuery,
  analyticsAggregateSchema,
  analyticsQuery,
  resolveAnalyticsRange,
} from '../../src/modules/analytics/analytics.types.js';
import { aggregate, memoryAnalytics, now, rangeQuery } from './helpers.js';

const fails = (code: string) => (error: unknown) =>
  error instanceof AppError && error.code === code;
test('UTC windows default to thirty inclusive dates and accept actual leap-day boundaries', () => {
  assert.deepEqual(resolveAnalyticsRange({}, now), {
    from: '2026-09-16',
    to: '2026-10-15',
    timeZone: 'UTC',
    days: 30,
  });
  assert.equal(resolveAnalyticsRange({ from: '2024-01-01', to: '2024-12-31' }, now).days, 366);
  assert.equal(resolveAnalyticsRange({ from: '2024-02-29', to: '2024-02-29' }, now).days, 1);
});
test('invalid dates, future/reversed/oversized/partial windows and forged owner filters are rejected', () => {
  for (const value of [
    { from: '2026-02-30', to: '2026-03-01' },
    { from: '0000-01-01', to: '0000-01-01' },
    { from: ['2026-01-01'] },
    { userId: randomUUID() },
    { bucket: 'all' },
    { limit: '10' },
  ])
    assert.equal(analyticsQuery.safeParse(value).success, false);
  for (const value of [
    { from: '2026-10-01' },
    { to: '2026-10-02' },
    { from: '2026-10-16', to: '2026-10-16' },
    { from: '2026-10-02', to: '2026-10-01' },
    { from: '2024-01-01', to: '2025-01-01' },
  ])
    assert.throws(() => resolveAnalyticsRange(value, now), fails('VALIDATION_ERROR'));
  for (const value of [
    { limit: '0' },
    { limit: '-1' },
    { limit: '51' },
    { limit: '01' },
    { limit: '1e1' },
    { limit: ['2', '3'] },
    { cursor: 'bad' },
    { user_id: randomUUID() },
  ])
    assert.equal(activityQuery.safeParse(value).success, false);
});
test('empty farmer statistics contain all canonical zero labels and every UTC date', async () => {
  const memory = memoryAnalytics();
  const service = createAnalyticsService(memory.repository, () => now);
  const summary = await service.summary(randomUUID(), rangeQuery);
  assert.equal(summary.totals.totalScans, 0);
  assert.equal(summary.distribution.length, 5);
  assert.deepEqual(summary.daily, [
    { date: '2026-10-01', count: 0 },
    { date: '2026-10-02', count: 0 },
  ]);
  assert.equal(summary.asOf, now.toISOString());
});
test('statistics retain usage/prediction semantics and never produce model accuracy or account data', async () => {
  const memory = memoryAnalytics();
  const owner = randomUUID();
  memory.data.set(owner, aggregate());
  const summary = await createAnalyticsService(memory.repository, () => now).summary(
    owner,
    rangeQuery,
  );
  assert.equal(summary.totals.totalScans, 8);
  assert.equal(summary.totals.diseasePredictions, 2);
  assert.equal(summary.totals.completedWithoutPrediction, 1);
  assert.equal(summary.uncertainty.lowConfidence, 2);
  assert.equal(
    summary.distribution.find((item) => item.label === 'Northern_Corn_Leaf_Blight')?.count,
    0,
  );
  for (const field of [
    'accuracy',
    'precision',
    'recall',
    'userId',
    'imageUrl',
    'cloudinaryPublicId',
  ])
    assert.ok(!Object.hasOwn(summary, field));
});
test('recent activity maps unknown legacy labels separately and respects owner/cursor pagination', async () => {
  const memory = memoryAnalytics();
  const owner = randomUUID();
  memory.data.set(owner, aggregate());
  const service = createAnalyticsService(memory.repository, () => now);
  const first = await service.activity(owner, { ...rangeQuery, limit: 2 });
  assert.equal(first.items.length, 2);
  assert.equal(first.nextCursor, memory.ids[1]);
  const next = await service.activity(owner, {
    ...rangeQuery,
    limit: 2,
    cursor: first.nextCursor ?? undefined,
  });
  assert.equal(next.items.length, 1);
  assert.equal(next.nextCursor, null);
  await assert.rejects(
    service.activity(randomUUID(), { ...rangeQuery, limit: 2, cursor: memory.ids[0] }),
    fails('NOT_FOUND'),
  );
});
test('aggregate conservation rejects incompatible counts and duplicate days/labels', () => {
  const valid = aggregate();
  assert.equal(analyticsAggregateSchema.safeParse(valid).success, true);
  assert.equal(
    analyticsAggregateSchema.safeParse({ ...valid, totals: { ...valid.totals, totalScans: 9 } })
      .success,
    false,
  );
  assert.equal(
    analyticsAggregateSchema.safeParse({ ...valid, daily: [valid.daily[0], valid.daily[0]] })
      .success,
    false,
  );
});
