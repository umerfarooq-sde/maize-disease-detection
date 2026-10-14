import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { analyticsSummarySql } from '../analytics/analytics.repository.js';
import { analyticsBounds, type AnalyticsRange } from '../analytics/analytics.types.js';
import { diseaseLabels } from '../inference/inference.types.js';
import { dashboardStoredSchema, type DashboardStored } from './dashboard.types.js';

export interface DashboardRepository {
  summary(range: AnalyticsRange): Promise<DashboardStored>;
}
export function dashboardSummarySql(range: AnalyticsRange): Prisma.Sql {
  const { from, until } = analyticsBounds(range);
  return Prisma.sql`
    WITH scan_summary AS (${analyticsSummarySql(null, range)}),
    ownership AS (
      SELECT count(*) FILTER (WHERE user_id IS NOT NULL) AS authenticated,
             count(*) FILTER (WHERE user_id IS NULL) AS anonymous
      FROM scans WHERE created_at>=${from} AND created_at<${until}
    ), farmers AS (
      SELECT count(*) AS total, count(*) FILTER (WHERE status='ACTIVE') AS active,
             count(*) FILTER (WHERE status='SUSPENDED') AS suspended,
             count(*) FILTER (WHERE status='DEACTIVATED') AS deactivated FROM users WHERE role='FARMER'
    ), production AS (SELECT version FROM model_versions WHERE status='PRODUCTION'),
    recent AS (
      SELECT s.id, s.created_at, s.status, CASE WHEN s.user_id IS NULL THEN 'ANONYMOUS' ELSE 'AUTHENTICATED' END AS origin,
        CASE WHEN p.predicted_class IS NULL THEN NULL WHEN p.predicted_class IN (${Prisma.join(diseaseLabels)})
             THEN p.predicted_class ELSE 'OTHER' END AS label
      FROM (SELECT id, created_at, status, user_id FROM scans WHERE created_at>=${from} AND created_at<${until}
            ORDER BY created_at DESC,id DESC LIMIT 10) s
      LEFT JOIN LATERAL (SELECT predicted_class FROM scan_predictions WHERE scan_id=s.id AND s.status='COMPLETED'
                         ORDER BY created_at DESC,id DESC LIMIT 1) p ON true
      ORDER BY s.created_at DESC,s.id DESC
    )
    SELECT jsonb_build_object('scans',scan_summary.summary, 'farmers',to_jsonb(farmers),
      'ownership',to_jsonb(ownership), 'productionCount',(SELECT count(*) FROM production),
      'productionVersions',coalesce((SELECT jsonb_agg(version) FROM (SELECT version FROM production ORDER BY version LIMIT 2) v),'[]'::jsonb),
      'recent',coalesce((SELECT jsonb_agg(jsonb_build_object('createdAt',created_at,'status',status,'origin',origin,'predictedClass',label) ORDER BY created_at DESC,id DESC) FROM recent),'[]'::jsonb))
      AS dashboard FROM scan_summary CROSS JOIN ownership CROSS JOIN farmers
  `;
}
export function createDashboardRepository(
  database: Pick<PrismaClient, '$queryRaw'>,
): DashboardRepository {
  return {
    async summary(range) {
      const rows = await database.$queryRaw<{ dashboard: unknown }[]>(dashboardSummarySql(range));
      return dashboardStoredSchema.parse(rows[0]?.dashboard);
    },
  };
}
