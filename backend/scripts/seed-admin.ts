import { adminSeedInvocationAllowed, runAdminSeed } from '../src/cli/admin-seed.js';
import { createAdminTerminal } from '../src/cli/admin-terminal.js';
import { loadEnvironment } from '../src/config/environment.js';
import { createDatabaseClient } from '../src/database/client.js';
import { createAuthRepository } from '../src/modules/auth/auth.repository.js';
import { createHealthRepository } from '../src/modules/health/health.repository.js';

// An explicit, interactive operator entrypoint; never imported by the server/seed.
if (
  !adminSeedInvocationAllowed(
    process.env,
    process.argv.slice(2),
    process.stdin.isTTY === true && process.stdout.isTTY === true,
  )
) {
  console.error(
    'Admin setup requires a manual interactive terminal outside CI. Usage: npm run admin:seed [-- --check]. Do not pass credentials as arguments or stdin.',
  );
  process.exitCode = 1;
} else {
  process.exitCode = await runAdminSeed(
    {
      terminal: createAdminTerminal(),
      loadEnvironment,
      connect(environment) {
        const database = createDatabaseClient(environment.DATABASE_URL);
        return {
          repository: createAuthRepository(database),
          checkDatabase: createHealthRepository(database, environment.NODE_ENV === 'production')
            .checkDatabase,
          disconnect: () => database.$disconnect(),
        };
      },
    },
    process.argv[2] === '--check',
  );
}
