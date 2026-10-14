import type { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { diseaseLabels } from '../inference/inference.types.js';
import type { AnalyticsRepository } from './analytics.repository.js';
import {
  type AnalyticsActivityPage,
  type AnalyticsSummary,
  activityItemSchema,
  type activityQuery,
  completeAnalyticsAggregate,
  type analyticsQuery,
  resolveAnalyticsRange,
} from './analytics.types.js';

export interface AnalyticsService {
  summary(userId: string, query: z.infer<typeof analyticsQuery>): Promise<AnalyticsSummary>;
  activity(userId: string, query: z.infer<typeof activityQuery>): Promise<AnalyticsActivityPage>;
}
export function createAnalyticsService(
  repository: AnalyticsRepository,
  now: () => Date = () => new Date(),
): AnalyticsService {
  return {
    async summary(userId, query) {
      const timestamp = now();
      const range = resolveAnalyticsRange(query, timestamp);
      const aggregate = await repository.summary(userId, range);
      return {
        ...completeAnalyticsAggregate(aggregate, range),
        range,
        asOf: timestamp.toISOString(),
      };
    },
    async activity(userId, query) {
      const range = resolveAnalyticsRange(query, now());
      const page = await repository.activity(userId, range, query.limit, query.cursor);
      if (!page) throw new AppError('NOT_FOUND');
      return {
        range,
        nextCursor: page.nextCursor,
        items: page.items.map((scan) => {
          const prediction = scan.status === 'COMPLETED' ? scan.predictions[0] : undefined;
          return activityItemSchema.parse({
            id: scan.id,
            status: scan.status,
            createdAt: scan.createdAt.toISOString(),
            predictedClass: prediction
              ? (diseaseLabels.find((label) => label === prediction.predictedClass) ?? 'OTHER')
              : null,
          });
        }),
      };
    },
  };
}
