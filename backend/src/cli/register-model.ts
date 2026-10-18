import { parseArgs } from 'node:util';
import { loadEnvironment } from '../config/environment.js';
import { withSecretFile } from '../config/secrets.js';
import { getDatabaseClient } from '../database/client.js';
import { databaseConnectionUrl, hasVerifiedDatabaseTransport } from '../database/connection-url.js';
import { readApprovedModel } from '../modules/inference/model-registration.js';
import { registerModelVersion } from '../modules/inference/model.repository.js';

let database: ReturnType<typeof getDatabaseClient> | undefined;
try {
  const { values } = parseArgs({
    options: { metadata: { type: 'string' }, sha256: { type: 'string' } },
  });
  if (!values.metadata || !values.sha256)
    throw new Error('Metadata path and approved SHA required.');
  const secrets = process.env['MAIZEDOCTOR_SECRETS_FILE'] ? withSecretFile(process.env) : undefined;
  const environment = secrets
    ? {
        AI_MODEL_VERSION: process.env['AI_MODEL_VERSION'] ?? '',
        AI_PREPROCESSING_VERSION: process.env['AI_PREPROCESSING_VERSION'] ?? '',
        DATABASE_URL: secrets['DIRECT_DATABASE_URL'] ?? secrets['DATABASE_URL'] ?? '',
      }
    : loadEnvironment();
  if (
    process.env['NODE_ENV'] === 'production' &&
    !hasVerifiedDatabaseTransport(databaseConnectionUrl(environment.DATABASE_URL))
  )
    throw new Error('Registration requires verified database transport.');
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
