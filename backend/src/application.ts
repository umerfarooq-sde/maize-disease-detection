import { createServer, type Server } from 'node:http';
import type { Logger } from 'pino';
import { createApp } from './app.js';
import type { Environment } from './config/environment.js';
import { getDatabaseClient } from './database/client.js';
import { createHealthRepository, type HealthDatabase } from './modules/health/health.repository.js';

export interface ApplicationDatabase extends HealthDatabase {
  $connect(): Promise<void>;
  $disconnect(): Promise<void>;
}

export interface RunningApplication {
  server: Server;
  stop(): Promise<void>;
}

function closeServer(server: Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

export async function startApplication(
  environment: Environment,
  logger: Logger,
  database: ApplicationDatabase = getDatabaseClient(environment.DATABASE_URL),
): Promise<RunningApplication> {
  const repository = createHealthRepository(database);
  const app = createApp(environment, logger, repository);
  const server = createServer(
    { requestTimeout: 60000, headersTimeout: 10000, keepAliveTimeout: 5000 },
    app,
  );
  try {
    await database.$connect();
    // Prisma adapter connections can be lazy; require a real round trip before listening.
    await repository.checkDatabase();
    await new Promise<void>((resolve, reject) => {
      server.once('error', reject);
      server.listen(environment.PORT, environment.HOST, () => {
        server.off('error', reject);
        resolve();
      });
    });
  } catch (error) {
    try {
      await database.$disconnect();
    } catch {
      logger.error({ code: 'DATABASE_DISCONNECT_FAILED' }, 'Startup cleanup failed');
    }
    throw error;
  }
  logger.info({ host: environment.HOST, port: environment.PORT }, 'Backend ready');

  // Bounded conditional recovery handles process crashes without a separate queue.
  // One recovery per process at a time; attempt UUIDs fence delayed workers.
  let recovery: Promise<void> | undefined;
  const recoveryTimer = setInterval(() => {
    if (recovery) return;
    const recover = app.locals.recoverScans as () => Promise<number>;
    recovery = recover()
      .then((count) => {
        if (count)
          logger.warn({ code: 'INFERENCE_INTERRUPTED', count }, 'Interrupted scans marked failed');
      })
      .catch(() => {
        logger.error(
          { code: 'SCAN_RECOVERY_PENDING' },
          'Scan recovery requires database availability',
        );
      })
      .finally(() => {
        recovery = undefined;
      });
  }, 60_000);
  recoveryTimer.unref();

  let stopping: Promise<void> | undefined;
  return {
    server,
    stop() {
      stopping ??= (async () => {
        clearInterval(recoveryTimer);
        let deadline: NodeJS.Timeout | undefined;
        const timedOut = new Promise<never>((_resolve, reject) => {
          deadline = setTimeout(() => {
            server.closeAllConnections();
            reject(new Error('Graceful shutdown timed out.'));
          }, environment.SHUTDOWN_TIMEOUT_MS);
        });
        const cleanup = (async () => {
          try {
            await closeServer(server);
            await recovery;
          } finally {
            await database.$disconnect();
          }
        })();
        try {
          await Promise.race([cleanup, timedOut]);
          logger.info('Backend stopped');
        } finally {
          clearTimeout(deadline);
        }
      })();
      return stopping;
    },
  };
}
