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
  const result = await createScanService(
    createScanRepository(database),
    createImageStorage(environment),
    createLogger(environment),
  ).cleanup();
  console.log(
    `Scan upload cleanup: ${result.removed} recovered, ${result.failed} pending retry, ${result.pruned} expired failed attempts removed (maximum 100 each per run).`,
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
