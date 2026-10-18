import { randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import type { Logger } from 'pino';
import { AppError } from '../../errors/app-error.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import { databaseDiagnostics } from '../../utils/database-diagnostics.js';
import { resolveAnalyticsRange } from '../analytics/analytics.types.js';
import {
  createOperationsRepository,
  type OperationEvent,
  type OperationsRepository,
} from './operations.repository.js';

export function createOperationsService(
  repository: OperationsRepository,
  logger: Pick<Logger, 'warn'>,
) {
  let lost = 0,
    closed = false;
  const pending: OperationEvent[] = [];
  let worker: Promise<void> | undefined;
  async function drain() {
    while (pending.length) {
      const event = pending.shift();
      if (!event) break;
      let recorded = false;
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          await repository.record(event);
          recorded = true;
          break;
        } catch {
          /* Retry the same identity once; an ambiguous commit cannot duplicate it. */
        }
      }
      if (!recorded) {
        lost++;
        logger.warn({ event: 'ai_telemetry_dropped', reason: 'storage' });
      }
    }
  }
  function startWriter() {
    if (worker) return;
    worker = drain()
      .catch(() => {
        lost += pending.length;
        pending.length = 0;
        logger.warn({ event: 'ai_telemetry_dropped', reason: 'writer' });
      })
      .finally(() => {
        worker = undefined;
        if (pending.length) startWriter();
      });
  }
  async function flush() {
    while (worker) await worker;
  }
  return {
    operationalState() {
      return { dropped: lost, pending: pending.length + (worker ? 1 : 0), closed };
    },
    flush,
    async close() {
      closed = true;
      await flush();
    },
    async summaryQuery(query: { from?: string | undefined; to?: string | undefined }) {
      const range = resolveAnalyticsRange(query, new Date());
      return this.summary(range.from, range.to);
    },
    async measure<T>(operation: OperationEvent['operation'], action: () => Promise<T>): Promise<T> {
      const start = performance.now();
      let outcome: OperationEvent['outcome'] = 'SUCCESS',
        category: OperationEvent['category'] = null;
      try {
        const result = await action();
        if (
          result &&
          typeof result === 'object' &&
          'status' in result &&
          ['OUT_OF_SCOPE', 'INSUFFICIENT_INFORMATION', 'CONFLICTING_EVIDENCE'].includes(
            String(result.status),
          )
        )
          outcome = 'ABSTAINED';
        return result;
      } catch (error) {
        outcome = 'FAILED';
        const code = error instanceof AppError ? error.code : '';
        category = code.includes('TIMEOUT')
          ? 'TIMEOUT'
          : code === 'INVALID_IMAGE'
            ? 'REJECTED'
            : code.includes('INVALID')
              ? 'INVALID_RESPONSE'
              : code.includes('UNAVAILABLE')
                ? 'UNAVAILABLE'
                : 'INTERNAL';
        throw error;
      } finally {
        const durationMs = Math.min(86400000, Math.round(performance.now() - start));
        if (closed || pending.length >= 128) {
          lost++;
          logger.warn({ event: 'ai_telemetry_dropped', reason: 'capacity' });
        } else {
          pending.push({
            id: randomUUID(),
            scope: 'NODE',
            operation,
            outcome,
            durationMs,
            category,
            occurredAt: new Date(),
          });
          startWriter();
        }
      }
    },
    async summary(from: string, to: string) {
      try {
        return {
          status: 'COLLECTED' as const,
          from,
          to,
          ...(await repository.aggregate(from, to)),
          collection: {
            scope: 'observed operations only',
            delivery: 'bounded best effort',
            localDropped: lost,
            localPending: pending.length + (worker ? 1 : 0),
            historicalCoverage: 'not collected before Phase 24.6',
            retention: 'deployment-controlled; erasure requires an approved policy',
          },
        };
      } catch (error) {
        logger.warn({
          event: 'ai_telemetry_aggregate_unavailable',
          stage: 'AGGREGATE',
          ...databaseDiagnostics(error),
        });
        return {
          status: 'UNAVAILABLE' as const,
          from,
          to,
          totals: null,
          daily: null,
          collection: {
            scope: 'observed operations only',
            delivery: 'bounded best effort',
            localDropped: lost,
            localPending: pending.length + (worker ? 1 : 0),
            historicalCoverage: 'not collected before Phase 24.6',
            retention: 'deployment-controlled; erasure requires an approved policy',
          },
        };
      }
    },
  };
}
export type OperationsService = ReturnType<typeof createOperationsService>;
const instances = new WeakMap<PrismaClient, OperationsService>();
export function operationsFor(
  database: PrismaClient,
  logger: Pick<Logger, 'warn'>,
): OperationsService {
  let service = instances.get(database);
  if (!service) {
    service = createOperationsService(createOperationsRepository(database), logger);
    instances.set(database, service);
  }
  return service;
}
