// Independent infrastructure probe; uses a temporary table and rolls back all writes.
import assert from 'node:assert/strict';
import pg from 'pg';
import { databaseConnectionUrl } from './database/client.js';

const connectionString = process.env['DATABASE_URL'];
if (!connectionString) {
  console.error('DATABASE_URL is required. Set it in backend/.env before checking PostgreSQL.');
  process.exitCode = 1;
} else {
  const client = new pg.Client({
    connectionString: databaseConnectionUrl(connectionString).toString(),
    connectionTimeoutMillis: 10000,
    query_timeout: 10000,
  });
  try {
    await client.connect();
    await client.query('BEGIN');
    await client.query(
      'CREATE TEMP TABLE environment_probe (value integer NOT NULL) ON COMMIT DROP',
    );
    await client.query('INSERT INTO environment_probe (value) VALUES ($1)', [42]);
    const result = await client.query<{ value: number }>('SELECT value FROM environment_probe');
    assert.equal(result.rows[0]?.value, 42);
    const version = await client.query<{ server_version: string }>('SHOW server_version');
    assert.ok(
      Number.parseInt(version.rows[0]?.server_version ?? '0', 10) >= 16,
      'Expected PostgreSQL 16 or newer.',
    );
    await client.query('ROLLBACK');
    console.log(
      `PASS: PostgreSQL ${version.rows[0]?.server_version} authenticated connection and temporary-table SQL round trip.`,
    );
  } catch {
    // Avoid printing connection strings, credentials, or raw driver errors.
    console.error('PostgreSQL check failed. Verify the server and backend/.env configuration.');
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}
