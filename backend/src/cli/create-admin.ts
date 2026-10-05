import { createInterface } from 'node:readline';
import { loadEnvironment } from '../config/environment.js';
import { getDatabaseClient } from '../database/client.js';
import { createAuthRepository } from '../modules/auth/auth.repository.js';
import { createAuthService } from '../modules/auth/auth.service.js';
import { registrationCredentials } from '../modules/auth/auth.validators.js';

// Operator-only stdin input keeps passwords out of command arguments/history/env.
// PowerShell's secure-prompt helper is scripts/create-admin.ps1.
const input = createInterface({ input: process.stdin, terminal: false });
let database: ReturnType<typeof getDatabaseClient> | undefined;
try {
  let line: string | undefined;
  for await (const received of input) {
    line = received;
    break;
  }
  const credentials = registrationCredentials.parse(JSON.parse(line ?? '{}'));
  const environment = loadEnvironment();
  database = getDatabaseClient(environment.DATABASE_URL);
  await createAuthService(environment, createAuthRepository(database)).createAdmin(credentials);
  console.log('Admin account created. No existing account was promoted or overwritten.');
} catch {
  console.error(
    'Admin creation failed. Check input, database configuration and account uniqueness.',
  );
  process.exitCode = 1;
} finally {
  input.close();
  try {
    await database?.$disconnect();
  } catch {
    console.error('Admin database cleanup failed.');
    process.exitCode = 1;
  }
}
