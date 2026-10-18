/** Real scheduler/Redis/SQL subprocess gate, only for an EMPTY local CI database. */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomBytes, randomUUID } from 'node:crypto';
import { once } from 'node:events';
import test from 'node:test';
import { createClient } from 'redis';
import { parseEnvironment } from '../src/config/environment.js';
import { createDatabaseClient, databaseConnectionUrl } from '../src/database/client.js';

test('real cleanup worker invokes all three existing CLIs and releases its shared lease on shutdown', {
  skip: process.env['RUN_CLEANUP_WORKER_TESTS'] !== '1',
}, async () => {
  const url = process.env['TEST_CLEANUP_DATABASE_URL'];
  const redisUrl = process.env['TEST_REDIS_URL'];
  assert.ok(url && redisUrl);
  const parsed = databaseConnectionUrl(url);
  assert.ok(['localhost', '127.0.0.1'].includes(parsed.hostname));
  assert.match(parsed.pathname, /^\/(maizedoctor_ci|phase25_ci)$/);
  assert.ok(['localhost', '127.0.0.1'].includes(new URL(redisUrl).hostname));
  const db = createDatabaseClient(url);
  try {
    // Never run provider-facing cleanup against a configured user/asset database.
    const counts = await Promise.all([
      db.scan.count(),
      db.scanUpload.count(),
      db.farmerProfile.count(),
      db.diseaseImage.count(),
    ]);
    assert.ok(
      counts.every((count) => count === 0),
      'Requires empty asset tables; no reset performed',
    );
  } finally {
    await db.$disconnect();
  }
  const token = randomBytes(32).toString('base64url');
  const namespace = `cleanup-${randomUUID().replaceAll('-', '').slice(0, 24)}`;
  const environment = {
    PATH: process.env['PATH'],
    SystemRoot: process.env['SystemRoot'],
    NODE_ENV: 'test',
    DATABASE_URL: url,
    REDIS_URL: redisUrl,
    REDIS_NAMESPACE: namespace,
    LOG_LEVEL: 'silent',
    JWT_SECRET: randomBytes(32).toString('base64url'),
    JWT_REFRESH_SECRET: randomBytes(32).toString('base64url'),
    OPERATIONS_TOKEN: token,
    CLEANUP_INTERVAL_SECONDS: '86400',
    CLOUDINARY_CLOUD_NAME: 'synthetic-ci-never-contact',
    CLOUDINARY_API_KEY: '000000000000000',
    CLOUDINARY_API_SECRET: 'synthetic-ci-never-contact',
  };
  // Use the runtime validator, never weaken its contract for a test fixture.
  parseEnvironment(environment);
  const worker = spawn(process.execPath, ['dist/cli/cleanup-worker.js'], {
    cwd: process.cwd(),
    stdio: 'ignore',
    windowsHide: true,
    // Synthetic configuration plus an empty DB; no real provider claim.
    env: environment,
  });
  try {
    let complete = false;
    let lastMetrics = '';
    const deadline = Date.now() + 45000;
    while (Date.now() < deadline && worker.exitCode === null) {
      try {
        const result = await fetch('http://127.0.0.1:9010/internal/metrics', {
          headers: { 'X-Operations-Token': token },
          signal: AbortSignal.timeout(1000),
        });
        const metrics = await result.text();
        lastMetrics = metrics;
        complete =
          result.ok &&
          ['scan-uploads', 'profile-images', 'reference-images'].every((purpose) =>
            metrics.includes(
              `maizedoctor_cleanup_runs_total{purpose="${purpose}",outcome="success"} 1`,
            ),
          );
        if (complete) break;
      } catch {
        /* Bounded cold process startup only; no provider/application retries. */
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.ok(
      complete,
      `Real cleanup CLIs did not complete; exit=${worker.exitCode}; ${lastMetrics}`,
    );
    assert.equal((await fetch('http://127.0.0.1:9010/internal/metrics')).status, 404);
  } finally {
    const exited = once(worker, 'exit');
    const force = setTimeout(() => worker.kill('SIGKILL'), 10000);
    if (worker.exitCode === null) worker.kill('SIGTERM');
    else clearTimeout(force);
    if (worker.exitCode === null) await exited;
    clearTimeout(force);
  }
  assert.equal(worker.exitCode, 0);
  const redis = createClient({
    url: redisUrl,
    socket: { reconnectStrategy: false, connectTimeout: 1000 },
  });
  redis.on('error', () => undefined);
  try {
    await redis.connect();
    assert.equal(await redis.get(`{${namespace}}:cleanup-worker`), null);
  } finally {
    if (redis.isOpen) redis.destroy();
  }
});
