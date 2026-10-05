import assert from 'node:assert/strict';
import type { Prisma } from '../src/generated/prisma/client.js';

export const applicationTables = [
  'users', 'farmer_profiles', 'diseases', 'disease_images', 'disease_sources',
  'scans', 'scan_predictions', 'knowledge_documents', 'knowledge_chunks',
  'fertilizers', 'fertilizer_rules', 'calculator_configs', 'model_versions',
  'model_metrics', 'ai_queries', 'ai_responses', 'audit_logs', 'notifications', 'history',
  'auth_sessions',
] as const;

export async function assertSqlRejects(
  tx: Prisma.TransactionClient, sql: string, values: unknown[], codes: string | string[],
): Promise<void> {
  await tx.$executeRawUnsafe('SAVEPOINT invalid_fixture');
  try {
    await assert.rejects(tx.$executeRawUnsafe(sql, ...values), (error: unknown) => {
      const details = error as { code?: string; meta?: {
        code?: string; driverAdapterError?: { cause?: { originalCode?: string } };
      } };
      const sqlstate = details.meta?.code ?? details.meta?.driverAdapterError?.cause?.originalCode;
      const expectedCodes = typeof codes === 'string' ? [codes] : codes;
      assert.ok(sqlstate && expectedCodes.includes(sqlstate), `Expected PostgreSQL SQLSTATE ${expectedCodes.join('/')} (${JSON.stringify(details.meta)})`);
      return true;
    });
  } finally {
    await tx.$executeRawUnsafe('ROLLBACK TO SAVEPOINT invalid_fixture');
    await tx.$executeRawUnsafe('RELEASE SAVEPOINT invalid_fixture');
  }
}

export const rollbackFixture = new Error('ROLLBACK synthetic integration fixtures');
