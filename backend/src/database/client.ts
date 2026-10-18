import { PrismaPg } from '@prisma/adapter-pg';
import { config } from 'dotenv';
import { performance } from 'node:perf_hooks';
import pg from 'pg';
import { PrismaClient } from '../generated/prisma/client.js';
import {
  databaseAcquisition,
  databaseFailures,
  databasePool,
  databaseQuery,
} from '../infrastructure/metrics.js';
import { databaseConnectionUrl } from './connection-url.js';
import { withSecretFile } from '../config/secrets.js';

export { databaseConnectionUrl } from './connection-url.js';

if (!process.env['MAIZEDOCTOR_SECRETS_FILE']) config({ quiet: true });

// Isolated seed/test clients use the factory; the application uses the shared getter.
export function createDatabaseClient(
  connectionString = withSecretFile(process.env)['DATABASE_URL'],
  queryTimeoutMillis = 5000,
): PrismaClient {
  if (!Number.isInteger(queryTimeoutMillis) || queryTimeoutMillis <= 0)
    throw new Error('Database query timeout must be a positive integer.');
  const url = databaseConnectionUrl(connectionString);
  const schema = url.searchParams.get('schema') ?? 'public';
  const pool = new pg.Pool({
    connectionString: url.toString(),
    max: 2,
    connectionTimeoutMillis: 10000,
    idleTimeoutMillis: 10000,
    query_timeout: queryTimeoutMillis,
  });
  const originalConnect = pool.connect.bind(pool);
  const sample = () => {
    databasePool.set({ state: 'total' }, pool.totalCount);
    databasePool.set({ state: 'idle' }, pool.idleCount);
    databasePool.set({ state: 'waiting' }, pool.waitingCount);
  };
  const acquire = async () => {
    const started = performance.now();
    try {
      const client = await originalConnect();
      databaseAcquisition.observe({ outcome: 'success' }, (performance.now() - started) / 1000);
      return client;
    } catch (error) {
      databaseAcquisition.observe({ outcome: 'failure' }, (performance.now() - started) / 1000);
      databaseFailures.inc({ stage: 'acquisition' });
      throw error;
    } finally {
      sample();
    }
  };
  Object.defineProperty(pool, 'connect', {
    value: (
      callback?: (
        error: Error | undefined,
        client: pg.PoolClient | undefined,
        done: (error?: Error | boolean) => void,
      ) => void,
    ) => {
      if (!callback) return acquire();
      return void acquire().then(
        (client) => callback(undefined, client, client.release.bind(client)),
        (error) =>
          callback(
            error instanceof Error ? error : new Error('Database connection failed'),
            undefined,
            () => undefined,
          ),
      );
    },
  });
  for (const event of ['connect', 'acquire', 'release', 'remove'] as const)
    pool.on(event, () => queueMicrotask(sample));
  const adapter = new PrismaPg(pool, {
    schema,
    disposeExternalPool: true,
    onPoolError: () => databaseFailures.inc({ stage: 'pool_disconnect' }),
    onConnectionError: () => databaseFailures.inc({ stage: 'connection' }),
  });
  const client = new PrismaClient({
    adapter,
    log: [
      { level: 'query', emit: 'event' },
      { level: 'error', emit: 'event' },
    ],
  });
  client.$on('query', (event) => {
    databaseQuery.observe(event.duration / 1000);
  });
  client.$on('error', (event) => {
    // Driver text can contain SQL/private parameters. Inspect locally and export
    // bounded categories only; never log it or turn it into a metric label.
    const message = event.message.toLowerCase();
    const stage = /cancel|57014/.test(message)
      ? 'query_cancelled'
      : /timeout|timed out/.test(message)
        ? 'query_timeout'
        : /certificate|ssl|tls/.test(message)
          ? 'tls'
          : /authentication|28p01|28000/.test(message)
            ? 'authentication'
            : /enotfound|eai_again/.test(message)
              ? 'dns'
              : /connection|econnreset|econnrefused/.test(message)
                ? 'connection'
                : 'query';
    databaseFailures.inc({ stage });
  });
  return client;
}

let applicationClient: PrismaClient | undefined;

export function getDatabaseClient(connectionString: string): PrismaClient {
  applicationClient ??= createDatabaseClient(connectionString);
  return applicationClient;
}
