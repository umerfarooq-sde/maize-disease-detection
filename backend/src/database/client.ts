import { PrismaPg } from '@prisma/adapter-pg';
import { config } from 'dotenv';
import { PrismaClient } from '../generated/prisma/client.js';

config({ quiet: true });

// Client construction only. Repositories will own application queries in later phases.
export function databaseConnectionUrl(connectionString = process.env['DATABASE_URL']): URL {
  if (!connectionString) throw new Error('DATABASE_URL is required.');
  const url = new URL(connectionString);
  if (!['postgres:', 'postgresql:'].includes(url.protocol)) {
    throw new Error('DATABASE_URL must be a PostgreSQL connection URL.');
  }
  // Keep the current strict TLS semantics explicit for pg's evolving SSL aliases.
  if (['prefer', 'require', 'verify-ca'].includes(url.searchParams.get('sslmode') ?? '')
      && url.searchParams.get('uselibpqcompat') !== 'true') {
    url.searchParams.set('sslmode', 'verify-full');
  }
  return url;
}

export function createDatabaseClient(connectionString = process.env['DATABASE_URL']): PrismaClient {
  const url = databaseConnectionUrl(connectionString);
  const schema = url.searchParams.get('schema') ?? 'public';
  const adapter = new PrismaPg({
    connectionString: url.toString(),
    max: 2,
    connectionTimeoutMillis: 10000,
    idleTimeoutMillis: 10000,
  }, { schema });
  return new PrismaClient({ adapter });
}
