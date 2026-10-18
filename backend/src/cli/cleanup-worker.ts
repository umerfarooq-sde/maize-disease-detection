import { execFile } from 'node:child_process';
import { timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';
import { createClient } from 'redis';
import { Counter, Gauge, Registry } from 'prom-client';
import { loadEnvironment } from '../config/environment.js';
import { createLogger } from '../config/logger.js';
import { runScheduledCycle, type WorkerLease } from '../infrastructure/scheduler.js';

const environment = loadEnvironment();
const logger = createLogger(environment);
if (!environment.REDIS_URL) throw new Error('Scheduled cleanup requires shared Redis coordination');
const intervalSeconds = Number(process.env['CLEANUP_INTERVAL_SECONDS'] ?? 300);
if (!Number.isInteger(intervalSeconds) || intervalSeconds < 30 || intervalSeconds > 86400)
  throw new Error('Invalid cleanup schedule');
const client = createClient({
  url: environment.REDIS_URL,
  disableOfflineQueue: true,
  commandsQueueMaxLength: 8,
  socket: { connectTimeout: 1000, reconnectStrategy: false },
});
client.on('error', () => logger.warn({ event: 'cleanup_redis_unavailable' }));
const key = `{${environment.REDIS_NAMESPACE}}:cleanup-worker`;
async function command<T>(action: () => Promise<T>): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      action(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          if (client.isOpen) client.destroy();
          reject(new Error('Worker Redis deadline'));
        }, 1000);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
const lease: WorkerLease = {
  acquire: async (id) =>
    (await command(() => client.set(key, id, { NX: true, PX: 120000 }))) === 'OK',
  renew: async (id) =>
    Number(
      await command(() =>
        client.eval(
          "if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('PEXPIRE',KEYS[1],120000) else return 0 end",
          { keys: [key], arguments: [id] },
        ),
      ),
    ) === 1,
  async release(id) {
    await command(() =>
      client.eval(
        "if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('DEL',KEYS[1]) else return 0 end",
        { keys: [key], arguments: [id] },
      ),
    );
  },
};
const registry = new Registry();
const outcomes = new Counter({
  name: 'maizedoctor_cleanup_runs_total',
  help: 'Owned scheduled cleanup invocations.',
  labelNames: ['purpose', 'outcome'],
  registers: [registry],
});
const lastSuccess = new Gauge({
  name: 'maizedoctor_cleanup_last_success_seconds',
  help: 'Last successful purpose run; absent before collection.',
  labelNames: ['purpose'],
  registers: [registry],
});
const stopping = new AbortController();
let current: Promise<void> | undefined;
const purposes = ['scan-uploads', 'profile-images', 'reference-images'] as const;
const tasks = purposes.map((purpose) => async (signal: AbortSignal) => {
  try {
    await new Promise<void>((resolve, reject) => {
      const child = execFile(
        process.execPath,
        [`dist/cli/cleanup-${purpose}.js`],
        { signal, timeout: 180000, maxBuffer: 65536, windowsHide: true },
        (error) => (error ? reject(error) : resolve()),
      );
      // Aborted subprocesses receive SIGTERM; force a bound if a handler stalls.
      let killTimer: NodeJS.Timeout | undefined;
      const force = () => {
        killTimer = setTimeout(() => child.kill('SIGKILL'), 5000);
      };
      signal.addEventListener('abort', force, { once: true });
      child.once('exit', () => {
        clearTimeout(killTimer);
        signal.removeEventListener('abort', force);
      });
    });
    outcomes.inc({ purpose, outcome: 'success' });
    lastSuccess.set({ purpose }, Date.now() / 1000);
  } catch {
    outcomes.inc({ purpose, outcome: 'failure' });
    throw new Error('Cleanup pending; durable journal retained');
  }
});
const server = createServer(async (request, response) => {
  const token = request.headers['x-operations-token'];
  const expected = environment.OPERATIONS_TOKEN;
  if (
    typeof token !== 'string' ||
    Buffer.byteLength(token) !== Buffer.byteLength(expected) ||
    !expected ||
    !timingSafeEqual(Buffer.from(token), Buffer.from(expected))
  ) {
    response.writeHead(404).end();
    return;
  }
  if (request.url === '/internal/metrics') {
    response.setHeader('Content-Type', registry.contentType);
    response.end(await registry.metrics());
  } else if (request.url === '/internal/ready')
    response.writeHead(!stopping.signal.aborted && client.isReady ? 200 : 503).end();
  else response.writeHead(404).end();
});
await new Promise<void>((resolve) => server.listen(9010, '0.0.0.0', resolve));
function tick() {
  if (current || stopping.signal.aborted) return;
  current = (async () => {
    if (!client.isReady) await client.connect();
    await runScheduledCycle(lease, tasks, stopping.signal);
  })()
    .catch(() => logger.warn({ event: 'scheduled_cleanup_failed' }))
    .finally(() => {
      current = undefined;
    });
}
const schedule = setInterval(tick, intervalSeconds * 1000);
tick();
let closing: Promise<void> | undefined;
function stop() {
  closing ??= (async () => {
    clearInterval(schedule);
    stopping.abort();
    await current;
    if (client.isOpen) client.destroy();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  })().catch(() => {
    process.exitCode = 1;
  });
}
process.once('SIGTERM', stop);
process.once('SIGINT', stop);
process.once('SIGBREAK', stop);
