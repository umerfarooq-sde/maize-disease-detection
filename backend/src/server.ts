import { startApplication } from './application.js';
import { loadEnvironment } from './config/environment.js';
import { createLogger } from './config/logger.js';

async function main(): Promise<void> {
  let environment: ReturnType<typeof loadEnvironment>;
  try {
    environment = loadEnvironment();
  } catch (error) {
    // Environment errors contain field names and safe schema messages only.
    console.error(error instanceof Error ? error.message : 'Invalid environment configuration.');
    process.exitCode = 1;
    return;
  }
  const logger = createLogger(environment);
  let application: Awaited<ReturnType<typeof startApplication>>;
  try {
    application = await startApplication(environment, logger);
  } catch {
    logger.fatal(
      { code: 'STARTUP_FAILED' },
      'Backend startup failed; verify database connectivity and listen configuration',
    );
    process.exitCode = 1;
    return;
  }

  let shuttingDown = false;
  async function shutdown(reason: string, exitCode: number): Promise<void> {
    if (shuttingDown) {
      if (exitCode !== 0) process.exitCode = exitCode;
      return;
    }
    shuttingDown = true;
    process.exitCode = exitCode;
    logger.info({ reason }, 'Stopping backend');
    try {
      await application.stop();
    } catch {
      logger.fatal({ code: 'SHUTDOWN_FAILED' }, 'Backend shutdown failed or timed out');
      logger.flush();
      process.exit(1);
    }
  }
  process.once('SIGINT', () => {
    void shutdown('SIGINT', 0);
  });
  process.once('SIGTERM', () => {
    void shutdown('SIGTERM', 0);
  });
  process.once('SIGBREAK', () => {
    void shutdown('SIGBREAK', 0);
  });
  process.once('uncaughtException', () => {
    void shutdown('UNCAUGHT_EXCEPTION', 1);
  });
  process.once('unhandledRejection', () => {
    void shutdown('UNHANDLED_REJECTION', 1);
  });
  application.server.on('error', () => {
    void shutdown('SERVER_ERROR', 1);
  });
}

await main();
