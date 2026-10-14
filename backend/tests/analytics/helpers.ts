import { randomUUID } from 'node:crypto';
import type { AnalyticsRepository } from '../../src/modules/analytics/analytics.repository.js';
import type { AnalyticsAggregate } from '../../src/modules/analytics/analytics.types.js';

export const now = new Date('2026-10-15T12:00:00.000Z');
export const rangeQuery = { from: '2026-10-01', to: '2026-10-02' };
export function aggregate(empty = false): AnalyticsAggregate {
  return empty
    ? {
        totals: {
          totalScans: 0,
          completedScans: 0,
          pendingScans: 0,
          processingScans: 0,
          failedScans: 0,
          withPrediction: 0,
          completedWithoutPrediction: 0,
          healthyPredictions: 0,
          diseasePredictions: 0,
          otherPredictions: 0,
        },
        uncertainty: { lowConfidence: 0, confident: 0, unavailable: 0 },
        distribution: [],
        daily: [],
      }
    : {
        totals: {
          totalScans: 8,
          completedScans: 5,
          pendingScans: 1,
          processingScans: 1,
          failedScans: 1,
          withPrediction: 4,
          completedWithoutPrediction: 1,
          healthyPredictions: 1,
          diseasePredictions: 2,
          otherPredictions: 1,
        },
        uncertainty: { lowConfidence: 2, confident: 1, unavailable: 1 },
        distribution: [
          { label: 'Healthy', count: 1 },
          { label: 'Common_Rust', count: 1 },
          { label: 'Gray_Leaf_Spot', count: 1 },
          { label: 'OTHER', count: 1 },
        ],
        daily: [
          { date: '2026-10-01', count: 5 },
          { date: '2026-10-02', count: 3 },
        ],
      };
}
export function memoryAnalytics() {
  const data = new Map<string, AnalyticsAggregate>();
  const reads: { userId: string; operation: string }[] = [];
  const ids = [randomUUID(), randomUUID(), randomUUID()];
  const ownerRows = ids.map((id, index) => ({
    id,
    status: 'COMPLETED' as const,
    createdAt: new Date(`2026-10-02T00:00:0${3 - index}.000Z`),
    predictions: [{ predictedClass: 'Healthy' }],
  }));
  const repository: AnalyticsRepository = {
    async summary(userId) {
      reads.push({ userId, operation: 'summary' });
      return data.get(userId) ?? aggregate(true);
    },
    async activity(userId, _range, limit, cursor) {
      reads.push({ userId, operation: 'activity' });
      const rows = data.has(userId) ? ownerRows : [];
      const offset = cursor ? rows.findIndex((row) => row.id === cursor) + 1 : 0;
      if (cursor && offset === 0) return null;
      const items = rows.slice(offset, offset + limit);
      return {
        items,
        nextCursor: offset + limit < rows.length ? (items.at(-1)?.id ?? null) : null,
      };
    },
  };
  return { data, repository, reads, ids };
}
