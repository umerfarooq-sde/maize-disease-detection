// Invoked only by the existing disposable-schema E2E harness. No production writes.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createApp } from '../backend/src/app.ts';
import { loadEnvironment } from '../backend/src/config/environment.ts';
import { getDatabaseClient } from '../backend/src/database/client.ts';
import { silentLogger } from '../backend/tests/foundation/helpers.ts';

const schema = process.env.PHASE23_SCHEMA;
assert.match(schema ?? '', /^phase23_[a-f0-9]{32}$/);
assert.equal(process.env.PHASE23_DB_CONTEXT_LOADED, '1');
const environment = {
  ...loadEnvironment(),
  NODE_ENV: 'test',
  AUTH_RATE_LIMIT_MAX: 100,
  KNOWLEDGE_RATE_LIMIT_MAX: 100,
};
assert.equal(new URL(environment.DATABASE_URL).searchParams.get('schema'), schema);
const database = getDatabaseClient(environment.DATABASE_URL);
assert.equal((await database.$queryRaw`SELECT current_schema() AS schema`)[0].schema, schema);
const credentials = {
  email: `phase236-${randomUUID()}@example.invalid`,
  password: `synthetic-${randomUUID()}`,
};
// Other checks can already have fixtures in the same owned E2E schema.
const usersBefore = await database.user.count();
const server = createServer(
  createApp(environment, silentLogger, {
    async checkDatabase() {
      await database.$queryRaw`SELECT 1`;
    },
  }),
);
const proof = { passed: false, physicalDevice: false, rawDatasetAccess: false };
try {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  // Only tool paths/settings and generated fixture credentials enter Flutter.
  const tooling = new Set([
    'PATH',
    'PATHEXT',
    'SYSTEMROOT',
    'WINDIR',
    'COMSPEC',
    'TEMP',
    'TMP',
    'USERPROFILE',
    'APPDATA',
    'LOCALAPPDATA',
    'PROGRAMDATA',
    'PROGRAMFILES',
    'PROGRAMFILES(X86)',
    'HOMEDRIVE',
    'HOMEPATH',
    'PUB_CACHE',
    'PUB_HOSTED_URL',
    'FLUTTER_ROOT',
    'ANDROID_HOME',
    'ANDROID_SDK_ROOT',
    'JAVA_HOME',
    'CI',
    'TERM',
    'NO_COLOR',
    'FLUTTER_SUPPRESS_ANALYTICS',
    'DART_SUPPRESS_ANALYTICS',
  ]);
  const childEnvironment = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => tooling.has(key.toUpperCase())),
  );
  await new Promise((resolve, reject) => {
    const child = spawn(
      process.env.PHASE23_DART,
      [
        process.env.PHASE23_FLUTTER_TOOLS,
        'test',
        '--no-pub',
        '--reporter=expanded',
        'test/integration/farmer_remediation_test.dart',
        '--dart-define=RUN_LIVE_FARMER_REMEDIATION=true',
        `--dart-define=API_BASE_URL=${base}`,
      ],
      {
        cwd: new URL('../mobile/', import.meta.url),
        windowsHide: true,
        env: {
          ...childEnvironment,
          REMEDIATION_FARMER: JSON.stringify(credentials),
        },
        stdio: 'inherit',
      },
    );
    child.once('error', reject);
    child.once('exit', (code) =>
      code === 0 ? resolve() : reject(new Error('Flutter remediation check failed')),
    );
  });
  const user = await database.user.findUniqueOrThrow({
    where: { email: credentials.email },
  });
  assert.equal(user.role, 'FARMER');
  assert.notEqual(user.passwordHash, credentials.password);
  assert.match(user.passwordHash, /^\$argon2id\$/);
  assert.equal(await database.user.count(), usersBefore + 1);
  const sessions = await database.authSession.findMany({
    where: { userId: user.id },
  });
  assert.ok(sessions.length >= 1 && sessions.every((session) => session.revokedAt !== null));
  assert.equal(await database.disease.count({ where: { status: 'ACTIVE' } }), 4);
  assert.equal(await database.knowledgeDocument.count({ where: { status: 'ACTIVE' } }), 25);
  proof.passed = true;
  proof.accountPersistedWithArgon2id = true;
  proof.farmerOnly = true;
  proof.sessionsRevoked = true;
  proof.catalogueEntries = 4;
  proof.activeSourcedDocuments = 25;
  proof.steps = [
    'registration-form',
    'registration-viewmodel-repository-api',
    'duplicate-registration',
    'login-form',
    'farmer-knowledge-tab',
    'four-real-detail-views',
    'source-display',
    'semantic-search-real-google-pgvector',
    'guest-knowledge-tab',
    'refresh-logout',
    'admin-role-injection-rejected',
  ];
} catch {
  console.error('FAIL: farmer remediation live check; private details omitted.');
  process.exitCode = 1;
} finally {
  await new Promise((resolve) => server.close(resolve));
  await writeFile(
    join(process.env.PHASE23_OUTPUT, 'farmer-remediation-proof.json'),
    JSON.stringify(proof, null, 2),
  );
  await database.$disconnect();
}
if (proof.passed)
  console.log(
    'PASS: actual Flutter registration/knowledge widgets → MVVM → Node → isolated PostgreSQL and retrieval; no physical device used.',
  );
