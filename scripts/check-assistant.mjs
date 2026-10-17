import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { createApp } from '../backend/dist/app.js';
import { loadEnvironment } from '../backend/dist/config/environment.js';
import { createLogger } from '../backend/dist/config/logger.js';
import { createDatabaseClient, getDatabaseClient } from '../backend/dist/database/client.js';
import { createAuthRepository } from '../backend/dist/modules/auth/auth.repository.js';
import { createAuthService } from '../backend/dist/modules/auth/auth.service.js';
import { createGenerationClient } from '../backend/dist/modules/generation/generation.client.js';
import { createGenerationService } from '../backend/dist/modules/generation/generation.service.js';
import { createHealthRepository } from '../backend/dist/modules/health/health.repository.js';
import { createKnowledgeClient } from '../backend/dist/modules/knowledge/knowledge.client.js';
import { createKnowledgeRepository } from '../backend/dist/modules/knowledge/knowledge.repository.js';
import { createKnowledgeService } from '../backend/dist/modules/knowledge/knowledge.service.js';
import { createScanRepository } from '../backend/dist/modules/scans/scan.repository.js';
import { createScanService } from '../backend/dist/modules/scans/scan.service.js';
import { validateImage } from '../backend/dist/modules/scans/scan.validation.js';

// Opt-in development check. The configured FastAPI service, reviewed knowledge,
// PostgreSQL and Google provider must be ready. No dataset or Cloudinary is used.
const environment = { ...loadEnvironment(), GENERATION_RATE_LIMIT_MAX: 40 };
assert.ok(environment.AI_SERVICE_URL, 'Configure the internal AI service first.');
assert.ok(environment.AI_SERVICE_TOKEN, 'Configure the internal service token first.');
const database = createDatabaseClient(environment.DATABASE_URL, 30000);
const repository = createScanRepository(database);
const auth = createAuthRepository(database);
const logger = createLogger({ LOG_LEVEL: 'silent' });
const storage = {
  enabled: false,
  async upload() { throw new Error('The assistant check never uploads images.'); },
  async destroy() { throw new Error('The assistant check never creates cloud assets.'); },
};
const scans = createScanService(repository, storage, logger);
const app = createApp(
  environment, logger, createHealthRepository(database), auth, scans,
  createKnowledgeService(createKnowledgeRepository(database), createKnowledgeClient(environment)),
  createGenerationService(scans, createGenerationClient(environment)),
);
const server = createServer(app);
const uploadIds = new Set();
const scanIds = new Set();
const emails = new Set();
const digest = (value) => createHash('sha256').update(value).digest('hex');

try {
  await database.$connect();
  const model = await database.modelVersion.findUniqueOrThrow({
    where: { version: environment.AI_MODEL_VERSION },
  });
  assert.ok(['VALIDATED', 'PRODUCTION'].includes(model.status));
  assert.equal(model.preprocessingVersion, environment.AI_PREPROCESSING_VERSION);
  const fixtureEnvironment = {};
  const users = [];
  const authService = createAuthService(environment, auth);
  for (const prefix of ['OWNER', 'OTHER']) {
    const credentials = {
      email: `phase16-${randomUUID()}@example.invalid`,
      password: `synthetic-fixture-${randomUUID()}`,
    };
    emails.add(credentials.email);
    await authService.register(credentials);
    users.push(await database.user.findUniqueOrThrow({ where: { email: credentials.email } }));
    fixtureEnvironment[`ASSISTANT_FIXTURE_${prefix}_EMAIL`] = credentials.email;
    fixtureEnvironment[`ASSISTANT_FIXTURE_${prefix}_PASSWORD`] = credentials.password;
  }

  const require = createRequire(new URL('../backend/package.json', import.meta.url));
  const sharp = require('sharp');
  const buffer = await sharp({
    create: { width: 64, height: 96, channels: 3, background: '#245443' },
  }).png().toBuffer();
  const image = await validateImage({
    fieldname: 'image', originalname: 'leaf.png', mimetype: 'image/png', buffer,
    size: buffer.length, encoding: '7bit', destination: '', filename: '', path: '',
    stream: sharp(buffer),
  });
  const uploadId = randomUUID();
  uploadIds.add(uploadId);
  const claim = await repository.claim(digest(`${users[0].id}:${randomUUID()}`), digest(buffer), uploadId);
  assert.equal(claim.claimed, true);
  const pending = await repository.complete(uploadId, {
    userId: users[0].id, image,
    stored: {
      publicId: claim.record.publicId,
      url: `https://example.invalid/phase16-synthetic/${uploadId}.png`,
      uploadedAt: new Date(),
    },
  });
  assert.ok(pending.scan);
  scanIds.add(pending.scan.id);
  const attemptId = await repository.startInference(pending.scan.id);
  assert.ok(attemptId);
  // A controlled persisted prediction exercises explanation/ownership. These
  // synthetic scores are not an inference, training or accuracy measurement.
  const completed = await repository.completeInference(pending.scan.id, attemptId, {
    predictedClass: 'Common_Rust', confidence: 0.99,
    topProbabilities: [
      { className: 'Common_Rust', probability: 0.99 },
      { className: 'Gray_Leaf_Spot', probability: 0.004 },
      { className: 'Healthy', probability: 0.003 },
      { className: 'Northern_Corn_Leaf_Blight', probability: 0.003 },
    ],
    modelVersion: model.version, preprocessingVersion: model.preprocessingVersion,
    inferenceDurationMs: 0, predictionStatus: 'LOW_CONFIDENCE',
    uncertaintyReason: 'THRESHOLD_UNCONFIGURED', confidenceThreshold: null,
  });
  assert.equal(completed.status, 'COMPLETED');
  const before = await repository.findScan(completed.id);
  fixtureEnvironment.ASSISTANT_FIXTURE_SCAN_ID = completed.id;
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  assert.ok(Number.isInteger(port));
  const args = [
    'test', '--no-pub', '--reporter', 'expanded', 'test/integration/assistant_test.dart',
    '--dart-define=RUN_LIVE_ASSISTANT_CHECK=true',
    `--dart-define=API_BASE_URL=http://127.0.0.1:${port}/api/v1`,
  ];
  const windows = process.platform === 'win32';
  const systemKeys = new Set([
    'PATH', 'PATHEXT', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'USERPROFILE',
    'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'HOME', 'PUB_CACHE', 'FLUTTER_ROOT',
    'ANDROID_HOME', 'ANDROID_SDK_ROOT', 'JAVA_HOME', 'CI', 'TERM', 'NO_COLOR',
    'FLUTTER_SUPPRESS_ANALYTICS', 'DART_SUPPRESS_ANALYTICS',
  ]);
  // The Flutter test receives system tooling settings and its own throwaway
  // credentials. Database/provider/service/JWT secrets stay in this Node process.
  const systemEnvironment = Object.fromEntries(Object.entries(process.env)
    .filter(([key]) => systemKeys.has(key.toUpperCase())));
  // Shell arguments are constants or the validated port. Credentials are passed
  // only as throwaway child environment values, never as command-line defines.
  const child = spawn(windows ? 'cmd.exe' : 'flutter',
    windows ? ['/d', '/s', '/c', `flutter.bat ${args.join(' ')}`] : args, {
      cwd: fileURLToPath(new URL('../mobile', import.meta.url)), windowsHide: true,
      env: { ...systemEnvironment, ...fixtureEnvironment }, stdio: ['ignore', 'pipe', 'pipe'],
    });
  child.stdout.on('data', (data) => process.stdout.write(data));
  child.stderr.on('data', (data) => process.stderr.write(data));
  const [code] = await once(child, 'exit');
  assert.equal(code, 0, 'The live Flutter assistant contract must pass.');
  assert.deepEqual(await repository.findScan(completed.id), before);
  console.log('PASS: Flutter -> Node -> authenticated FastAPI/RAG/Google; grounded sources, scoped abstention, persisted farmer ownership and unchanged uncertainty.');
} finally {
  await new Promise((resolve) => server.close(resolve));
  await app.locals.flushOperationalEvents();
  try {
    const journals = await database.scanUpload.findMany({ where: { id: { in: [...uploadIds] } } });
    for (const journal of journals) if (journal.scanId) scanIds.add(journal.scanId);
    await database.$transaction(async (transaction) => {
      await transaction.scanUpload.deleteMany({ where: { id: { in: [...uploadIds] } } });
      await transaction.scanPrediction.deleteMany({ where: { scanId: { in: [...scanIds] } } });
      await transaction.scan.deleteMany({ where: { id: { in: [...scanIds] } } });
      await transaction.user.deleteMany({ where: { email: { in: [...emails] } } });
    }, { maxWait: 10000, timeout: 30000 });
  } finally {
    await getDatabaseClient(environment.DATABASE_URL).$disconnect();
    await database.$disconnect();
  }
  console.log('Removed only this run\'s two fixture accounts and synthetic scan/prediction/journal; no cloud assets, model, knowledge or source dataset changes.');
}
