import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { createApp } from '../backend/dist/app.js';
import { loadEnvironment } from '../backend/dist/config/environment.js';
import { createLogger } from '../backend/dist/config/logger.js';
import { createDatabaseClient } from '../backend/dist/database/client.js';
import { createAuthRepository } from '../backend/dist/modules/auth/auth.repository.js';
import { createHealthRepository } from '../backend/dist/modules/health/health.repository.js';
import { createScanRepository } from '../backend/dist/modules/scans/scan.repository.js';
import { createScanService } from '../backend/dist/modules/scans/scan.service.js';
import { createImageStorage } from '../backend/dist/modules/scans/scan.storage.js';
import { createAiInferenceClient } from '../backend/dist/modules/inference/inference.client.js';

const inference = process.argv.includes('--inference');

const environment = loadEnvironment();
const database = createDatabaseClient(environment.DATABASE_URL, 30000);
const real = createImageStorage(environment);
const ids = new Set();
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
  const args = [
    'test', '--no-pub', '--reporter', 'expanded', 'test/integration/scan_upload_test.dart',
    '--dart-define=RUN_LIVE_SCAN_CHECK=true',
    `--dart-define=RUN_LIVE_SCAN_INFERENCE=${inference}`,
    `--dart-define=API_BASE_URL=http://127.0.0.1:${port}/api/v1`,
  ];
  const windows = process.platform === 'win32';
  // Every shell argument is a constant or our validated numeric port; no credentials.
  const child = spawn(windows ? 'cmd.exe' : 'flutter', windows ? ['/d', '/s', '/c', `flutter.bat ${args.join(' ')}`] : args, {
    cwd: fileURLToPath(new URL('../mobile', import.meta.url)), windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stdout.on('data', (data) => process.stdout.write(data));
  child.stderr.on('data', (data) => process.stderr.write(data));
  const [code] = await once(child, 'exit');
  assert.equal(code, 0);
  assert.equal(ids.size, 1);
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
  } finally {
    await database.$disconnect();
  }
  console.log('Removed only this run\'s synthetic asset and database records.');
}
