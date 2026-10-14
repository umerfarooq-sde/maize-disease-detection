import { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { diseaseLabels } from '../inference/inference.types.js';

export const analyticsLabels = [...diseaseLabels, 'OTHER'] as const;
export const analyticsDayMs = 86_400_000;
const count = z.number().int().nonnegative().safe();
export const analyticsDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((value) => {
    const date = new Date(`${value}T00:00:00.000Z`);
    return (
      value >= '0001-01-01' &&
      Number.isFinite(date.getTime()) &&
      date.toISOString().slice(0, 10) === value
    );
  });
export const analyticsQuery = z.strictObject({
  from: analyticsDate.optional(),
  to: analyticsDate.optional(),
});
export const activityQuery = analyticsQuery.extend({
  limit: z
    .string()
    .regex(/^[1-9]\d?$/)
    .transform(Number)
    .refine((value) => value <= 50)
    .default(10),
  cursor: z.uuid().optional(),
});
export interface AnalyticsRange {
  from: string;
  to: string;
  timeZone: 'UTC';
  days: number;
}
export function resolveAnalyticsRange(
  query: z.infer<typeof analyticsQuery>,
  now: Date,
): AnalyticsRange {
  if ((query.from === undefined) !== (query.to === undefined))
    throw new AppError('VALIDATION_ERROR');
  const today = now.toISOString().slice(0, 10);
  const to = query.to ?? today;
  const from =
    query.from ??
    new Date(new Date(`${to}T00:00:00.000Z`).getTime() - 29 * analyticsDayMs)
      .toISOString()
      .slice(0, 10);
  const days =
    (new Date(`${to}T00:00:00.000Z`).getTime() - new Date(`${from}T00:00:00.000Z`).getTime()) /
      analyticsDayMs +
    1;
  if (
    !analyticsDate.safeParse(from).success ||
    !analyticsDate.safeParse(to).success ||
    !Number.isInteger(days) ||
    days < 1 ||
    days > 366 ||
    to > today
  )
    throw new AppError('VALIDATION_ERROR');
  return { from, to, timeZone: 'UTC', days };
}
export function analyticsBounds(range: AnalyticsRange) {
  return {
    from: new Date(`${range.from}T00:00:00.000Z`),
    until: new Date(new Date(`${range.to}T00:00:00.000Z`).getTime() + analyticsDayMs),
  };
}
export const analyticsAggregateSchema = z
  .strictObject({
    totals: z.strictObject({
      totalScans: count,
      completedScans: count,
      pendingScans: count,
      processingScans: count,
      failedScans: count,
      withPrediction: count,
      completedWithoutPrediction: count,
      healthyPredictions: count,
      diseasePredictions: count,
      otherPredictions: count,
    }),
    uncertainty: z.strictObject({ lowConfidence: count, confident: count, unavailable: count }),
    distribution: z.array(z.strictObject({ label: z.enum(analyticsLabels), count })).max(5),
    daily: z.array(z.strictObject({ date: analyticsDate, count })).max(366),
  })
  .refine((data) => {
    const totals = data.totals;
    return (
      totals.totalScans ===
        totals.completedScans + totals.pendingScans + totals.processingScans + totals.failedScans &&
      totals.completedScans === totals.withPrediction + totals.completedWithoutPrediction &&
      totals.withPrediction ===
        totals.healthyPredictions + totals.diseasePredictions + totals.otherPredictions &&
      totals.withPrediction ===
        data.uncertainty.lowConfidence +
          data.uncertainty.confident +
          data.uncertainty.unavailable &&
      totals.withPrediction === data.distribution.reduce((sum, item) => sum + item.count, 0) &&
      totals.totalScans === data.daily.reduce((sum, item) => sum + item.count, 0) &&
      new Set(data.distribution.map((item) => item.label)).size === data.distribution.length &&
      new Set(data.daily.map((item) => item.date)).size === data.daily.length
    );
  }, 'Analytics counts must reconcile.');
export type AnalyticsAggregate = z.infer<typeof analyticsAggregateSchema>;
export interface AnalyticsSummary extends AnalyticsAggregate {
  range: AnalyticsRange;
  asOf: string;
}
export const activityItemSchema = z.strictObject({
  id: z.uuid(),
  status: z.enum(['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED']),
  createdAt: z.iso.datetime(),
  predictedClass: z.enum(analyticsLabels).nullable(),
});
export type AnalyticsActivity = z.infer<typeof activityItemSchema>;
export interface AnalyticsActivityPage {
  range: AnalyticsRange;
  items: AnalyticsActivity[];
  nextCursor: string | null;
}
