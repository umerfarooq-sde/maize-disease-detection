import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { createApp } from '../backend/dist/app.js';
import { loadEnvironment } from '../backend/dist/config/environment.js';
import { createLogger } from '../backend/dist/config/logger.js';
import { createDatabaseClient } from '../backend/dist/database/client.js';
import { createAuthRepository } from '../backend/dist/modules/auth/auth.repository.js';
import { createAuthService } from '../backend/dist/modules/auth/auth.service.js';
import { createHealthRepository } from '../backend/dist/modules/health/health.repository.js';
import { createScanRepository } from '../backend/dist/modules/scans/scan.repository.js';
import { createScanService } from '../backend/dist/modules/scans/scan.service.js';
import { createImageStorage } from '../backend/dist/modules/scans/scan.storage.js';
import { createAiInferenceClient } from '../backend/dist/modules/inference/inference.client.js';

const inference = process.argv.includes('--inference');
const farmer = process.argv.includes('--farmer');
assert.ok(!farmer || inference, 'Farmer history check requires real inference.');

const environment = loadEnvironment();
const database = createDatabaseClient(environment.DATABASE_URL, 30000);
const real = createImageStorage(environment);
const ids = new Set();
const users = [];
const storage = {
  ...real,
  async upload(image, publicId) {
    ids.add(publicId.slice('maizedoctor/scans/'.length));
    return real.upload(image, publicId);
  },
};
const logger = createLogger({ LOG_LEVEL: 'silent' });
const app = createApp(
  environment, logger, createHealthRepository(database), createAuthRepository(database),
  createScanService(createScanRepository(database), storage, logger,
    inference ? createAiInferenceClient(environment) : undefined),
);
const server = createServer(app);
try {
  await database.$connect();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  assert.ok(Number.isInteger(port));
  const fixtureEnvironment = {};
  if (farmer) {
    const authService = createAuthService(environment, createAuthRepository(database));
    for (const prefix of ['OWNER', 'OTHER']) {
      const credentials = {
        email: `phase13-${randomUUID()}@example.invalid`,
        password: `synthetic-fixture-${randomUUID()}`,
      };
      // Only this harness's generated, throwaway farmers are supplied to the test.
      await authService.register(credentials);
      users.push((await database.user.findUniqueOrThrow({ where: { email: credentials.email } })).id);
      fixtureEnvironment[`SCAN_FIXTURE_${prefix}_EMAIL`] = credentials.email;
      fixtureEnvironment[`SCAN_FIXTURE_${prefix}_PASSWORD`] = credentials.password;
    }
  }
  const args = [
    'test', '--no-pub', '--reporter', 'expanded', farmer ? 'test/integration/farmer_scan_test.dart' : 'test/integration/scan_upload_test.dart',
    '--dart-define=RUN_LIVE_SCAN_CHECK=true',
    `--dart-define=RUN_LIVE_SCAN_INFERENCE=${inference}`,
    `--dart-define=API_BASE_URL=http://127.0.0.1:${port}/api/v1`,
  ];
  const windows = process.platform === 'win32';
  // Every shell argument is a constant or our validated numeric port; no credentials.
  const child = spawn(windows ? 'cmd.exe' : 'flutter', windows ? ['/d', '/s', '/c', `flutter.bat ${args.join(' ')}`] : args, {
    cwd: fileURLToPath(new URL('../mobile', import.meta.url)), windowsHide: true,
    env: { ...process.env, ...fixtureEnvironment },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stdout.on('data', (data) => process.stdout.write(data));
  child.stderr.on('data', (data) => process.stderr.write(data));
  const [code] = await once(child, 'exit');
  assert.equal(code, 0);
  assert.equal(ids.size, 1);
  if (farmer) {
    const saved = await database.scan.findMany({ where: { userId: users[0] }, include: { predictions: true } });
    assert.equal(saved.length, 1);
    assert.equal(saved[0].status, 'COMPLETED');
    assert.equal(saved[0].predictions.length, 1);
    console.log('PASS: real Flutter farmer session, scan, owned paginated history/detail, cross-farmer denial and logout.');
  }
  console.log(inference
    ? 'PASS: Flutter -> Node -> FastAPI -> shared/model -> PostgreSQL -> Flutter; real Cloudinary.'
    : 'PASS: complete Flutter upload chain against real Cloudinary/PostgreSQL.');
} finally {
  await new Promise((resolve) => server.close(resolve));
  try {
    const records = await database.scanUpload.findMany({ where: { id: { in: [...ids] } } });
    for (const record of records) await real.destroy(record.publicId);
    const scanIds = records.flatMap((record) => record.scanId ? [record.scanId] : []);
    await database.scanUpload.deleteMany({ where: { id: { in: [...ids] } } });
    await database.scanPrediction.deleteMany({ where: { scanId: { in: scanIds } } });
    await database.scan.deleteMany({ where: { id: { in: scanIds } } });
    await database.user.deleteMany({ where: { id: { in: users } } });
  } finally {
    await database.$disconnect();
  }
  console.log('Removed only this run\'s synthetic asset and database records.');
}
