import { loadEnvironment } from '../config/environment.js';
import { getDatabaseClient } from '../database/client.js';
import { createReferenceRepository } from '../modules/knowledge/media.repository.js';
import { createReferenceService } from '../modules/knowledge/media.service.js';
import { createImageStorage } from '../modules/scans/scan.storage.js';
const environment = loadEnvironment(),
  database = getDatabaseClient(environment.DATABASE_URL);
try {
  const result = await createReferenceService(
    createReferenceRepository(database),
    createImageStorage(environment, 'references'),
  ).cleanup();
  console.log(JSON.stringify(result));
  if (result.failed) process.exitCode = 1;
} catch {
  console.error('Reference image recovery failed; durable intents retained.');
  process.exitCode = 1;
} finally {
  await database.$disconnect();
}
