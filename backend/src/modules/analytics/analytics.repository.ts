import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { diseaseLabels } from '../inference/inference.types.js';
import {
  type AnalyticsAggregate,
  type AnalyticsRange,
  analyticsAggregateSchema,
  analyticsBounds,
} from './analytics.types.js';

export type AnalyticsDatabase = Pick<PrismaClient, '$queryRaw' | 'scan'>;
export interface AnalyticsRepository {
  summary(userId: string, range: AnalyticsRange): Promise<AnalyticsAggregate>;
  activity(
    userId: string,
    range: AnalyticsRange,
    limit: number,
    cursor?: string,
  ): Promise<{
    items: {
      id: string;
      status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
      createdAt: Date;
      predictions: { predictedClass: string }[];
    }[];
    nextCursor: string | null;
  } | null>;
}
/** One owner/date-indexed query returns aggregates, never every scan to Node. */
export function analyticsSummarySql(userId: string, range: AnalyticsRange): Prisma.Sql {
  const { from, until } = analyticsBounds(range);
  return Prisma.sql`
    WITH owned AS MATERIALIZED (
      SELECT s.id, s.status, s.created_at, p.id AS prediction_id, p.prediction_status,
             CASE WHEN p.id IS NULL THEN NULL
                  WHEN p.predicted_class IN (${Prisma.join(diseaseLabels)}) THEN p.predicted_class ELSE 'OTHER' END AS label
      FROM scans s
      LEFT JOIN LATERAL (
        SELECT id, predicted_class, prediction_status FROM scan_predictions
        WHERE scan_id=s.id AND s.status='COMPLETED'
        ORDER BY created_at DESC, id DESC LIMIT 1
      ) p ON true
      WHERE s.user_id=${userId}::uuid AND s.created_at>=${from} AND s.created_at<${until}
    ), daily AS (
      SELECT to_char(created_at AT TIME ZONE 'UTC','YYYY-MM-DD') AS date, count(*) AS count
      FROM owned GROUP BY 1
    ), labels AS (
      SELECT label, count(*) AS count FROM owned WHERE prediction_id IS NOT NULL GROUP BY label
    )
    SELECT jsonb_build_object(
      'totals', jsonb_build_object(
        'totalScans', count(*), 'completedScans', count(*) FILTER (WHERE status='COMPLETED'),
        'pendingScans', count(*) FILTER (WHERE status='PENDING'),
        'processingScans', count(*) FILTER (WHERE status='PROCESSING'),
        'failedScans', count(*) FILTER (WHERE status='FAILED'),
        'withPrediction', count(prediction_id),
        'completedWithoutPrediction', count(*) FILTER (WHERE status='COMPLETED' AND prediction_id IS NULL),
        'healthyPredictions', count(*) FILTER (WHERE label='Healthy'),
        'diseasePredictions', count(*) FILTER (WHERE label IN ('Common_Rust','Gray_Leaf_Spot','Northern_Corn_Leaf_Blight')),
        'otherPredictions', count(*) FILTER (WHERE label='OTHER')),
      'uncertainty', jsonb_build_object(
        'lowConfidence', count(*) FILTER (WHERE prediction_status='LOW_CONFIDENCE'),
        'confident', count(*) FILTER (WHERE prediction_status='CONFIDENT'),
        'unavailable', count(*) FILTER (WHERE prediction_id IS NOT NULL AND prediction_status IS NULL)),
      'distribution', coalesce((SELECT jsonb_agg(jsonb_build_object('label',label,'count',count)) FROM labels),'[]'::jsonb),
      'daily', coalesce((SELECT jsonb_agg(jsonb_build_object('date',date,'count',count) ORDER BY date) FROM daily),'[]'::jsonb)
    ) AS summary FROM owned
  `;
}
export function createAnalyticsRepository(database: AnalyticsDatabase): AnalyticsRepository {
  return {
    async summary(userId, range) {
      const rows = await database.$queryRaw<{ summary: unknown }[]>(
        analyticsSummarySql(userId, range),
      );
      return analyticsAggregateSchema.parse(rows[0]?.summary);
    },
    async activity(userId, range, limit, cursor) {
      const { from, until } = analyticsBounds(range);
      const where = { userId, createdAt: { gte: from, lt: until } };
      if (
        cursor &&
        !(await database.scan.findFirst({ where: { ...where, id: cursor }, select: { id: true } }))
      )
        return null;
      const rows = await database.scan.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        take: limit + 1,
        select: {
          id: true,
          status: true,
          createdAt: true,
          predictions: {
            orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
            take: 1,
            select: { predictedClass: true },
          },
        },
      });
      const items = rows.slice(0, limit);
      return { items, nextCursor: rows.length > limit ? (items.at(-1)?.id ?? null) : null };
    },
  };
}
