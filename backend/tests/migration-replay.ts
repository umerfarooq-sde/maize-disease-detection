import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import pg from 'pg';
import { databaseConnectionUrl } from '../src/database/client.js';
import { applicationTables } from './database-support.js';

// Replay the committed SQL in an isolated schema, never reset an existing database.
const schema = `phase2_verify_${randomUUID().replaceAll('-', '')}`;
assert.match(schema, /^phase2_verify_[a-f0-9]{32}$/);
const client = new pg.Client({
  connectionString: databaseConnectionUrl(process.env['DIRECT_DATABASE_URL'] || process.env['DATABASE_URL']).toString(),
  connectionTimeoutMillis: 10000,
});
let created = false;
try {
  await client.connect();
  await client.query(`CREATE SCHEMA "${schema}"`);
  created = true;
  await client.query(`SET search_path TO "${schema}", public`);
  const migrationsRoot = new URL('../prisma/migrations/', import.meta.url);
  const migrations = (await readdir(migrationsRoot, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory()).map((entry) => entry.name).sort();
  for (const name of migrations) {
    const migration = await readFile(new URL(`${name}/migration.sql`, migrationsRoot), 'utf8');
    await client.query(migration);
  }
  const tables = await client.query<{ tablename: string }>('SELECT tablename FROM pg_tables WHERE schemaname = $1', [schema]);
  assert.deepEqual(tables.rows.map((row) => row.tablename).sort(), [...applicationTables].sort());
  const constraints = await client.query<{ count: string }>(
    "SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname=$1 AND c.contype='c'", [schema],
  );
  assert.equal(Number(constraints.rows[0]?.count), 23);
  const triggers = await client.query<{ count: string }>(
    'SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=$1 AND NOT t.tgisinternal', [schema],
  );
  assert.equal(Number(triggers.rows[0]?.count), 37);
  console.log(`PASS: ${migrations.length} atomic migrations replay in an isolated schema with ${applicationTables.length} tables, checks, and triggers.`);
} catch (error) {
  // PostgreSQL diagnostics contain schema/statement context, never the connection URL.
  const details = error as { code?: string; message?: string };
  console.error(`Migration replay failed (${details.code ?? 'assertion'}): ${details.message ?? 'unknown error'}`);
  process.exitCode = 1;
} finally {
  if (created) {
    await client.query('ROLLBACK');
    await client.query('SET search_path TO public');
    // Name is locally generated and validated above; only our temporary schema is removed.
    await client.query(`DROP SCHEMA "${schema}" CASCADE`);
    console.log('Temporary migration schema removed.');
  }
  await client.end();
}
