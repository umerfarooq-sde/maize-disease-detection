/** Isolated HTTP process for the opt-in shared-state contract, never production. */
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import express from 'express';
import { createDistributedQuota, redisQuotaStore } from '../../src/infrastructure/quotas.js';
import { requestRateLimit } from '../../src/middleware/rate-limit.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { silentLogger, testEnvironment } from '../foundation/helpers.js';

const url = process.env['TEST_REDIS_URL'];
const namespace = process.env['TEST_QUOTA_NAMESPACE'];
const key = process.env['TEST_QUOTA_KEY'];
if (!url || !namespace || !key) throw new Error('Missing isolated Redis test configuration');
const quota = createDistributedQuota(
  { ...testEnvironment, JWT_SECRET: key, REDIS_NAMESPACE: namespace },
  redisQuotaStore(url, silentLogger),
  silentLogger,
);
const app = express();
app.locals.distributedQuota = quota;
app.use(requestContext(silentLogger));
app.get('/quota', requestRateLimit(3, 3000), (_req, res) => res.end());
app.use(errorHandler(silentLogger));
const server = createServer(app);
await quota.start();
await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
process.send?.({ port: (server.address() as AddressInfo).port, pid: process.pid });
let stopping: Promise<void> | undefined;
function stop() {
  stopping ??= (async () => {
    server.closeAllConnections();
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await quota.close();
    process.exit(0);
  })();
  stopping.catch(() => process.exit(1));
}
process.on('message', stop);
process.on('disconnect', stop);
process.once('SIGTERM', stop);
