import { z } from 'zod';
import {
  analyticsAggregateSchema,
  analyticsLabels,
  type AnalyticsRange,
} from '../analytics/analytics.types.js';

const count = z.number().int().nonnegative().safe();
const version = z.string().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/);
export const dashboardStoredSchema = z
  .strictObject({
    scans: analyticsAggregateSchema,
    farmers: z.strictObject({ total: count, active: count, suspended: count, deactivated: count }),
    ownership: z.strictObject({ authenticated: count, anonymous: count }),
    productionCount: count,
    productionVersions: z.array(version).max(2),
    recent: z
      .array(
        z.strictObject({
          createdAt: z.iso.datetime({ offset: true }),
          status: z.enum(['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED']),
          origin: z.enum(['AUTHENTICATED', 'ANONYMOUS']),
          predictedClass: z.enum(analyticsLabels).nullable(),
        }),
      )
      .max(10),
  })
  .refine(
    (value) =>
      value.farmers.total ===
        value.farmers.active + value.farmers.suspended + value.farmers.deactivated &&
      value.ownership.authenticated + value.ownership.anonymous === value.scans.totals.totalScans &&
      value.productionVersions.length === Math.min(value.productionCount, 2),
    'Dashboard counts must reconcile.',
  );
export type DashboardStored = z.infer<typeof dashboardStoredSchema>;
export interface DashboardSummary
  extends Omit<DashboardStored, 'scans' | 'productionCount' | 'productionVersions'> {
  range: AnalyticsRange;
  asOf: string;
  scans: DashboardStored['scans'];
  model: {
    registry: 'NOT_PROMOTED' | 'SINGLE_PRODUCTION' | 'MULTIPLE_PRODUCTION';
    productionVersion: string | null;
    configuredVersion: string | null;
    inferenceConfigured: boolean;
    readiness: 'NOT_CHECKED';
  };
  aiRequestStatistics: 'NOT_RECORDED';
}
