import { loadEnvironment } from '../config/environment.js';
import { getDatabaseClient } from '../database/client.js';
import { createProfileMediaRepository } from '../modules/profile/profile-media.repository.js';
import { createProfileMediaService } from '../modules/profile/profile-media.service.js';
import { createImageStorage } from '../modules/scans/scan.storage.js';

let database: ReturnType<typeof getDatabaseClient> | undefined;
try {
  const environment = loadEnvironment();
  database = getDatabaseClient(environment.DATABASE_URL);
  const result = await createProfileMediaService(
    createProfileMediaRepository(database),
    createImageStorage(environment, 'profiles'),
  ).cleanup();
  console.log(
    `Profile image cleanup: ${result.removed} removed, ${result.failed} awaiting retry (maximum 20 per run).`,
  );
  if (result.failed) process.exitCode = 1;
} catch {
  console.error('Profile image cleanup failed; check database/Cloudinary connectivity and retry.');
  process.exitCode = 1;
} finally {
  await database?.$disconnect();
}
