import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import express from 'express';
import pg from 'pg';
import { adminSeedTarget, runAdminSeed } from '../src/cli/admin-seed.js';
import { createDatabaseClient, databaseConnectionUrl } from '../src/database/client.js';
import { authenticate } from '../src/middleware/authentication.js';
import { authorize } from '../src/middleware/authorization.js';
import { errorHandler } from '../src/middleware/error-handler.js';
import { createAuthRepository } from '../src/modules/auth/auth.repository.js';
import { authRoutes } from '../src/modules/auth/auth.routes.js';
import { createAuthService } from '../src/modules/auth/auth.service.js';
import { createHealthRepository } from '../src/modules/health/health.repository.js';
import { silentLogger, testEnvironment, withServer } from './foundation/helpers.js';

const configured = process.env['TEST_ADMIN_SEED_DATABASE_URL'];
test('real PostgreSQL isolated seed, repeat/collision safety, Argon2 and unchanged HTTP login/RBAC', {
  skip: !configured,
  timeout: 60000,
}, async () => {
  assert.ok(configured);
  const url = databaseConnectionUrl(configured);
  assert.ok(['localhost', '127.0.0.1'].includes(url.hostname));
  assert.match(
    url.pathname,
    /^\/(admin_seed_fixture|maizedoctor_ci|phase25_ci|phase25_native_final)$/,
  );
  assert.ok(!url.searchParams.has('schema') || url.searchParams.get('schema') === 'public');
  const schema = `admin_seed_verify_${randomUUID().replaceAll('-', '')}`;
  assert.match(schema, /^admin_seed_verify_[a-f0-9]{32}$/);
  const owner = new pg.Client({ connectionString: url.toString(), connectionTimeoutMillis: 5000 });
  let created = false;
  let database: ReturnType<typeof createDatabaseClient> | undefined;
  try {
    await owner.connect();
    await owner.query(`CREATE SCHEMA "${schema}"`);
    created = true;
    await owner.query(`SET search_path TO "${schema}", public`);
    // Exact existing auth DDL only, in an owned schema. No migration/seed against
    // public, no configured application database fallback, no hand-invented model.
    const initial = await readFile(
      new URL('../prisma/migrations/20261005000000_initial_schema/migration.sql', import.meta.url),
      'utf8',
    );
    const sessions = await readFile(
      new URL('../prisma/migrations/20261006000000_auth_sessions/migration.sql', import.meta.url),
      'utf8',
    );
    for (const pattern of [
      /CREATE TYPE "UserRole" AS ENUM \([\s\S]*?\);/,
      /CREATE TYPE "UserStatus" AS ENUM \([\s\S]*?\);/,
      /CREATE TABLE "users" \([\s\S]*?\);/,
      /CREATE UNIQUE INDEX "users_email_key"[^;]+;/,
      /ALTER TABLE users ADD CONSTRAINT users_identity_check CHECK \([\s\S]*?\);/,
    ]) {
      const statement = initial.match(pattern)?.[0];
      assert.ok(statement, 'Expected committed users DDL');
      await owner.query(statement);
    }
    for (const pattern of [
      /CREATE TABLE "auth_sessions" \([\s\S]*?\);/,
      /CREATE UNIQUE INDEX "auth_sessions_refresh_token_hash_key"[^;]+;/,
    ]) {
      const statement = sessions.match(pattern)?.[0];
      assert.ok(statement, 'Expected committed sessions DDL');
      await owner.query(statement);
    }
    url.searchParams.set('schema', schema);
    const environment = { ...testEnvironment, DATABASE_URL: url.toString() };
    database = createDatabaseClient(environment.DATABASE_URL);
    const repository = createAuthRepository(database);
    const messages: string[] = [];
    const credentials = {
      email: 'synthetic-admin@example.invalid',
      password: 'synthetic isolated administrator password',
    };
    let disconnects = 0;
    async function seed(email = credentials.email, check = false) {
      const answers = check
        ? [email]
        : [
            email,
            credentials.password,
            credentials.password,
            adminSeedTarget(environment).confirmation,
          ];
      return runAdminSeed(
        {
          loadEnvironment: () => environment,
          terminal: {
            async ask() {
              const answer = answers.shift();
              assert.ok(answer);
              return answer;
            },
            write(message) {
              messages.push(message);
            },
            close() {},
          },
          connect() {
            const seedDatabase = createDatabaseClient(environment.DATABASE_URL);
            return {
              repository: createAuthRepository(seedDatabase),
              checkDatabase: createHealthRepository(seedDatabase).checkDatabase,
              async disconnect() {
                disconnects++;
                await seedDatabase.$disconnect();
              },
            };
          },
        },
        check,
      );
    }
    assert.equal(await seed(), 0);
    const original = await repository.findAccount(credentials.email);
    assert.ok(original);
    assert.equal(original.role, 'ADMIN');
    assert.equal(original.status, 'ACTIVE');
    assert.match(original.passwordHash, /^\$argon2id\$/);
    assert.equal(await database.authSession.count(), 0);
    const service = createAuthService(environment, repository);
    const app = express();
    app.use(express.json());
    app.use('/api/v1/auth', authRoutes(environment, service));
    app.get('/admin-only', authenticate(service), authorize('ADMIN'), (_req, res) =>
      res.json({ allowed: true }),
    );
    app.use(errorHandler(silentLogger));
    await withServer(app, async (base) => {
      const response = await fetch(`${base}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Auth-Request': '1' },
        body: JSON.stringify(credentials),
      });
      assert.equal(response.status, 200);
      const body = (await response.json()) as {
        data: { user: { role: string }; accessToken: string };
      };
      assert.equal(body.data.user.role, 'ADMIN');
      assert.ok(response.headers.has('set-cookie'));
      assert.equal(
        (
          await fetch(`${base}/admin-only`, {
            headers: { Authorization: `Bearer ${body.data.accessToken}` },
          })
        ).status,
        200,
      );
      assert.equal((await fetch(`${base}/admin-only`)).status, 401);
    });
    assert.equal(await seed(), 0);
    assert.equal(await seed(credentials.email, true), 0);
    assert.deepEqual(await repository.findAccount(credentials.email), original);
    assert.equal(
      await database.authSession.count(),
      1,
      'Repeat/check must not revoke existing sessions',
    );
    const farmer = { ...credentials, email: 'synthetic-farmer@example.invalid' };
    await service.register(farmer);
    const before = await repository.findAccount(farmer.email);
    assert.equal(await seed(farmer.email), 1);
    assert.deepEqual(await repository.findAccount(farmer.email), before);
    await database.user.update({
      where: { email: credentials.email },
      data: { status: 'SUSPENDED' },
    });
    assert.equal(await seed(), 0);
    assert.equal((await repository.findAccount(credentials.email))?.status, 'SUSPENDED');
    assert.equal(await database.user.count(), 2);
    assert.equal(disconnects, 5);
    assert.ok(!messages.join('\n').includes(credentials.password));
    assert.ok(!messages.join('\n').includes(original.passwordHash));
  } finally {
    await database?.$disconnect();
    if (created) {
      await owner.query('SET search_path TO public');
      await owner.query(`DROP SCHEMA "${schema}" CASCADE`);
      const remains = await owner.query('SELECT 1 FROM pg_namespace WHERE nspname=$1', [schema]);
      assert.equal(remains.rowCount, 0);
    }
    await owner.end();
  }
});
