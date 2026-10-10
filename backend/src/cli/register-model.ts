import { parseArgs } from 'node:util';
import { loadEnvironment } from '../config/environment.js';
import { getDatabaseClient } from '../database/client.js';
import { readApprovedModel } from '../modules/inference/model-registration.js';
import { registerModelVersion } from '../modules/inference/model.repository.js';

let database: ReturnType<typeof getDatabaseClient> | undefined;
try {
  const { values } = parseArgs({
    options: { metadata: { type: 'string' }, sha256: { type: 'string' } },
  });
  if (!values.metadata || !values.sha256)
    throw new Error('Metadata path and approved SHA required.');
  const environment = loadEnvironment();
  const model = await readApprovedModel(
    values.metadata,
    values.sha256,
    environment.AI_MODEL_VERSION,
    environment.AI_PREPROCESSING_VERSION,
  );
  database = getDatabaseClient(environment.DATABASE_URL);
  await registerModelVersion(database, model);
  console.log(
    `Registered ${model.version} for non-commercial research inference; no production promotion.`,
  );
} catch {
  console.error(
    'Model registration failed. Check the approved metadata/hash, configured versions and database. Existing artifacts are never overwritten.',
  );
  process.exitCode = 1;
} finally {
  await database?.$disconnect();
}
