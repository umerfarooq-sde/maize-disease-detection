import { loadEnvironment } from '../config/environment.js';
import { createLogger } from '../config/logger.js';
import { getDatabaseClient } from '../database/client.js';
import { createScanRepository } from '../modules/scans/scan.repository.js';
import { createScanService } from '../modules/scans/scan.service.js';
import { createImageStorage } from '../modules/scans/scan.storage.js';

let database: ReturnType<typeof getDatabaseClient> | undefined;
try {
  const environment = loadEnvironment();
  database = getDatabaseClient(environment.DATABASE_URL);
  const service = createScanService(
    createScanRepository(database),
    createImageStorage(environment),
    createLogger(environment),
  );
  const interrupted = await service.recoverStale();
  const result = await service.cleanup();
  console.log(
    `Scan cleanup: ${interrupted} interrupted inferences failed; ${result.removed} uploads recovered, ${result.failed} pending retry, ${result.pruned} expired failed attempts removed (maximum 100 each per run).`,
  );
  if (result.failed) process.exitCode = 1;
} catch {
  console.error('Scan upload cleanup failed. Check database/Cloudinary configuration and rerun.');
  process.exitCode = 1;
} finally {
  try {
    await database?.$disconnect();
  } catch {
    process.exitCode = 1;
  }
}
