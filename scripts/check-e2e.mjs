import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createApp } from '../backend/src/app.ts';
import { loadEnvironment } from '../backend/src/config/environment.ts';
import { getDatabaseClient } from '../backend/src/database/client.ts';
import { createAuthRepository } from '../backend/src/modules/auth/auth.repository.ts';
import { createAuthService } from '../backend/src/modules/auth/auth.service.ts';
import { createScanRepository } from '../backend/src/modules/scans/scan.repository.ts';
import { createScanService } from '../backend/src/modules/scans/scan.service.ts';
import { createImageStorage } from '../backend/src/modules/scans/scan.storage.ts';
import { createAiInferenceClient } from '../backend/src/modules/inference/inference.client.ts';
import { silentLogger } from '../backend/tests/foundation/helpers.ts';
import { draftInput } from '../backend/tests/fertilizer/helpers.ts';
import { draft as yieldDraft } from '../backend/tests/yield/helpers.ts';

const schema = process.env.PHASE23_SCHEMA;
assert.match(schema ?? '', /^phase23_[a-f0-9]{32}$/);
assert.equal(
  process.env.PHASE23_DB_CONTEXT_LOADED,
  '1',
  'The schema-isolation preloader is required.',
);
const environment = {
  ...loadEnvironment(),
  NODE_ENV: 'test',
  GENERATION_RATE_LIMIT_MAX: 100,
  KNOWLEDGE_RATE_LIMIT_MAX: 100,
};
assert.equal(new URL(environment.DATABASE_URL).searchParams.get('schema'), schema);
const database = getDatabaseClient(environment.DATABASE_URL);
assert.equal(
  (await database.$queryRaw`SELECT current_schema() AS schema`)[0].schema,
  schema,
  'Raw SQL and Prisma must resolve the same disposable schema before any fixture writes.',
);
if (process.argv.includes('--preflight')) {
  await database.$disconnect();
  console.log('PASS: Prisma and raw SQL both target the verified disposable schema.');
  process.exit(0);
}
const authRepository = createAuthRepository(database);
const auth = createAuthService(environment, authRepository);
const realStorage = createImageStorage(environment),
  assets = new Set();
assert.ok(realStorage.enabled);
const storage = {
  ...realStorage,
  async upload(image, id) {
    assets.add(id);
    return realStorage.upload(image, id);
  },
};
const scans = createScanService(
  createScanRepository(database),
  storage,
  silentLogger,
  createAiInferenceClient(environment),
);
const app = createApp(
  environment,
  silentLogger,
  {
    async checkDatabase() {
      await database.$queryRaw`SELECT 1`;
    },
  },
  authRepository,
  scans,
);
const server = createServer(app);
const proof = { passed: false, cloudCleanupComplete: false, ownedCloudAssets: [], steps: [] };
let stage = 'controlled Admin fixture';
try {
  const adminCredentials = {
    email: `phase23-admin-${randomUUID()}@example.invalid`,
    password: `synthetic-${randomUUID()}`,
  };
  const farmerCredentials = {
    email: `phase23-farmer-${randomUUID()}@example.invalid`,
    password: `synthetic-${randomUUID()}`,
  };
  await auth.createAdmin(adminCredentials);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  async function request(path, method, body, token, status = 200) {
    const response = await fetch(base + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(body),
    });
    assert.equal(response.status, status);
    return (await response.json()).data;
  }
  const admin = await auth.login(adminCredentials);
  // Synthetic arithmetic data is intentionally published only inside this verified disposable schema.
  stage = 'isolated synthetic calculator versions';
  for (const [path, body] of [
    ['fertilizer/rules', draftInput()],
    ['yield/configurations', yieldDraft()],
  ]) {
    const row = await request(`/admin/calculators/${path}`, 'POST', body, admin.accessToken, 201);
    await request(
      `/admin/calculators/${path}/${row.id}/status`,
      'PATCH',
      { status: 'ACTIVE' },
      admin.accessToken,
    );
  }
  const corpus = JSON.parse(
    await readFile(
      new URL('../backend/knowledge/maize-extension-20261012-v1.json', import.meta.url),
      'utf8',
    ),
  );
  const source = corpus.documents.find(
    (item) => item.diseaseLabel === 'Common_Rust' && item.knowledgeType === 'OVERVIEW',
  );
  const document = {
    documentKey: `phase23-${randomUUID()}`,
    expectedVersion: 0,
    diseaseSlug: 'common-rust',
    knowledgeType: 'OVERVIEW',
    title: source.title,
    content: source.content,
    source: source.source,
    region: source.metadata.region,
    sourceSection: source.metadata.sourceSection,
    reviewNote:
      'Isolated test reuses existing reviewed corpus text; no new agricultural recommendation or approval.',
    approved: true,
  };
  const tooling = new Set([
    'PATH',
    'PATHEXT',
    'SYSTEMROOT',
    'WINDIR',
    'COMSPEC',
    'USERPROFILE',
    'APPDATA',
    'LOCALAPPDATA',
    'TEMP',
    'TMP',
    'HOME',
    'PUB_CACHE',
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
  stage = 'connected Flutter farmer/Admin journey';
  await new Promise((resolve, reject) => {
    const child = spawn(
      process.env.PHASE23_DART,
      [
        process.env.PHASE23_FLUTTER_TOOLS,
        'test',
        '--no-pub',
        '--reporter=expanded',
        'test/integration/e2e_test.dart',
        'test/integration/backend_connection_test.dart',
        '--dart-define=RUN_LIVE_E2E_CHECK=true',
        '--dart-define=RUN_LIVE_API_CHECK=true',
        `--dart-define=API_BASE_URL=${base}`,
      ],
      {
        cwd: new URL('../mobile/', import.meta.url),
        windowsHide: true,
        env: {
          ...childEnvironment,
          E2E_FARMER: JSON.stringify(farmerCredentials),
          E2E_ADMIN: JSON.stringify(adminCredentials),
          E2E_DOCUMENT: JSON.stringify(document),
        },
        stdio: 'inherit',
      },
    );
    child.once('error', reject);
    child.once('exit', (code) =>
      code === 0 ? resolve() : reject(new Error('Flutter journey failed')),
    );
  });
  stage = 'persistent outcome and audit evidence';
  const owner = await database.user.findUniqueOrThrow({
    where: { email: farmerCredentials.email },
  });
  const saved = await database.scan.findMany({
    where: { userId: owner.id },
    include: { predictions: true },
  });
  assert.equal(saved.length, 1);
  assert.equal(saved[0].status, 'COMPLETED');
  assert.equal(saved[0].predictions.length, 1);
  assert.equal(saved[0].predictions[0].predictionStatus, 'LOW_CONFIDENCE');
  const versions = await database.knowledgeDocument.findMany({
    where: { documentKey: document.documentKey },
    orderBy: { version: 'asc' },
    include: { chunks: true },
  });
  assert.equal(versions.length, 2);
  assert.equal(versions[0].status, 'ARCHIVED');
  assert.equal(versions[1].status, 'ACTIVE');
  assert.ok(
    versions.every(
      (row) =>
        row.chunks.length > 0 && row.chunks.every((chunk) => chunk.embeddingStatus === 'READY'),
    ),
  );
  const auditCount = await database.auditLog.count({
    where: { entityId: { in: versions.map((row) => row.id) } },
  });
  assert.ok(auditCount >= 6);
  proof.passed = true;
  proof.steps = [
    'registration',
    'login',
    'real-cloud-upload',
    'real-model-prediction',
    'history',
    'result-detail',
    'grounded-scan-explanation-or-honest-abstention',
    'sourced-knowledge-api',
    'synthetic-calculators',
    'farmer-statistics',
    'admin-login',
    'admin-dashboard',
    'immutable-knowledge-revision',
    'real-embedding-rebuild',
    'model-health',
    'refresh-logout',
  ];
  proof.knowledgeFarmerUi = 'VERIFIED_BY_SEPARATE_FARMER_REMEDIATION_GATE';
  proof.deviceCamera = 'NOT_DEVICE_TESTED';
  proof.realAgronomicCalculatorContent = 'PENDING';
} catch {
  console.error(`FAIL: ${stage}; private details omitted.`);
  process.exitCode = 1;
} finally {
  await new Promise((resolve) => server.close(resolve));
  await app.locals.flushOperationalEvents();
  const cleanup = await Promise.allSettled([...assets].map((id) => realStorage.destroy(id)));
  proof.ownedCloudAssets = [...assets];
  proof.cloudCleanupComplete = cleanup.every((result) => result.status === 'fulfilled');
  if (!proof.cloudCleanupComplete) {
    console.error(
      'FAIL: owned cloud cleanup; retain disposable schema and inspect the private proof.',
    );
    process.exitCode = 1;
  }
  await writeFile(
    join(process.env.PHASE23_OUTPUT, 'journey-proof.json'),
    JSON.stringify(proof, null, 2),
  );
  await database.$disconnect();
  if (proof.passed && proof.cloudCleanupComplete)
    console.log(
      'PASS: connected Flutter/API/MVVM farmer/Admin journey; owned Cloudinary asset removed.',
    );
}
