import type { Environment } from '../../config/environment.js';
import { completeAnalyticsAggregate, resolveAnalyticsRange } from '../analytics/analytics.types.js';
import type { DashboardRepository } from './dashboard.repository.js';
import type { DashboardSummary } from './dashboard.types.js';

export interface DashboardService {
  summary(query: { from?: string | undefined; to?: string | undefined }): Promise<DashboardSummary>;
}
export function createDashboardService(
  repository: DashboardRepository,
  environment: Pick<Environment, 'AI_SERVICE_URL' | 'AI_MODEL_VERSION'>,
  now: () => Date = () => new Date(),
): DashboardService {
  return {
    async summary(query) {
      const timestamp = now();
      const range = resolveAnalyticsRange(query, timestamp);
      const stored = await repository.summary(range);
      return {
        range,
        asOf: timestamp.toISOString(),
        farmers: stored.farmers,
        ownership: stored.ownership,
        scans: completeAnalyticsAggregate(stored.scans, range),
        recent: stored.recent.map((item) => ({
          ...item,
          createdAt: new Date(item.createdAt).toISOString(),
        })),
        model: {
          registry:
            stored.productionCount === 0
              ? 'NOT_PROMOTED'
              : stored.productionCount === 1
                ? 'SINGLE_PRODUCTION'
                : 'MULTIPLE_PRODUCTION',
          productionVersion:
            stored.productionCount === 1 ? (stored.productionVersions[0] ?? null) : null,
          configuredVersion: environment.AI_MODEL_VERSION || null,
          inferenceConfigured: environment.AI_SERVICE_URL !== '',
          readiness: 'NOT_CHECKED',
        },
        aiRequestStatistics: 'AVAILABLE_SEPARATELY',
      };
    },
  };
}
