import type { PrismaClient } from '../../generated/prisma/client.js';

export interface OperationEvent {
  id: string;
  scope: 'NODE' | 'AI_SERVICE' | 'PROVIDER';
  operation: 'INFERENCE' | 'RETRIEVAL' | 'GENERATION' | 'EXPLANATION' | 'GEMINI' | 'EMBEDDING';
  outcome: 'SUCCESS' | 'FAILED' | 'ABSTAINED';
  durationMs: number;
  category: 'TIMEOUT' | 'REJECTED' | 'UNAVAILABLE' | 'INVALID_RESPONSE' | 'INTERNAL' | null;
  occurredAt: Date;
}
export interface OperationAggregate {
  scope: string;
  operation: string;
  requests: number;
  successes: number;
  failures: number;
  abstained: number;
  averageMs: number;
  p50Ms: number;
  p95Ms: number;
}
export function createOperationsRepository(database: PrismaClient) {
  return {
    async record(event: OperationEvent) {
      await database.$transaction(
        async (tx) => {
          await tx.$executeRaw`SET LOCAL statement_timeout = '1500ms'`;
          // Same event may be retried safely; no second row is counted.
          await tx.aiOperation.createMany({ data: [event], skipDuplicates: true });
        },
        // A provider call can outlast the shared pool's idle timeout. Allow a
        // verified TLS reconnect. This runs in the owned bounded writer, never
        // on the farmer response deadline. A retry retains the same event ID.
        { maxWait: 10000, timeout: 5000 },
      );
    },
    async aggregate(from: string, to: string) {
      // One statement gives both projections the same snapshot and avoids an
      // unnecessary interactive transaction's shorter acquisition deadline.
      // Shared pool acquisition/query limits still apply; no retries or warming.
      const rows = await database.$queryRaw<
        {
          totals: OperationAggregate[];
          daily: { date: string; scope: string; requests: number; failures: number }[];
        }[]
      >`
          WITH filtered AS (
            SELECT scope,operation,outcome,duration_ms,occurred_at FROM ai_operations
            WHERE occurred_at >= (${from}::date::timestamp AT TIME ZONE 'UTC')
              AND occurred_at < ((${to}::date+1)::timestamp AT TIME ZONE 'UTC')
          ), totals AS (
          SELECT scope, operation, count(*)::int AS requests,
          count(*) FILTER (WHERE outcome='SUCCESS')::int AS successes,
          count(*) FILTER (WHERE outcome='FAILED')::int AS failures,
          count(*) FILTER (WHERE outcome='ABSTAINED')::int AS abstained,
          avg(duration_ms)::float8 AS "averageMs",
          percentile_cont(0.5) WITHIN GROUP (ORDER BY duration_ms)::float8 AS "p50Ms",
          percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms)::float8 AS "p95Ms"
          FROM filtered GROUP BY scope, operation
          ), daily AS (
          SELECT to_char(occurred_at AT TIME ZONE 'UTC','YYYY-MM-DD') AS date, scope,
          count(*)::int AS requests, count(*) FILTER (WHERE outcome='FAILED')::int AS failures
          FROM filtered GROUP BY 1,scope
          )
          SELECT COALESCE((SELECT jsonb_agg(t ORDER BY t.scope,t.operation) FROM totals t),'[]'::jsonb) AS totals,
                 COALESCE((SELECT jsonb_agg(d ORDER BY d.date,d.scope) FROM daily d),'[]'::jsonb) AS daily`;
      const result = rows[0];
      if (!result) throw new Error('Operational aggregate row missing.');
      return result;
    },
  };
}
export type OperationsRepository = ReturnType<typeof createOperationsRepository>;
