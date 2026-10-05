import { PrismaPg } from '@prisma/adapter-pg';
import { config } from 'dotenv';
import { PrismaClient } from '../generated/prisma/client.js';
import { databaseConnectionUrl } from './connection-url.js';

export { databaseConnectionUrl } from './connection-url.js';

config({ quiet: true });

// Isolated seed/test clients use the factory; the application uses the shared getter.
export function createDatabaseClient(
  connectionString = process.env['DATABASE_URL'],
  queryTimeoutMillis = 5000,
): PrismaClient {
  if (!Number.isInteger(queryTimeoutMillis) || queryTimeoutMillis <= 0)
    throw new Error('Database query timeout must be a positive integer.');
  const url = databaseConnectionUrl(connectionString);
  const schema = url.searchParams.get('schema') ?? 'public';
  const adapter = new PrismaPg(
    {
      connectionString: url.toString(),
      max: 2,
      connectionTimeoutMillis: 10000,
      idleTimeoutMillis: 10000,
      query_timeout: queryTimeoutMillis,
    },
    { schema },
  );
  return new PrismaClient({ adapter });
}

let applicationClient: PrismaClient | undefined;

export function getDatabaseClient(connectionString: string): PrismaClient {
  applicationClient ??= createDatabaseClient(connectionString);
  return applicationClient;
}
