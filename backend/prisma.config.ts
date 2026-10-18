import { config } from 'dotenv';
import { defineConfig, env } from 'prisma/config';
import { withSecretFile } from './src/config/secrets.js';

if (!process.env['MAIZEDOCTOR_SECRETS_FILE']) config({ quiet: true });
const secretEnvironment = withSecretFile(process.env);

const databaseUrl = new URL(secretEnvironment['DIRECT_DATABASE_URL'] || secretEnvironment['DATABASE_URL'] || env('DATABASE_URL'));
// Remote startup/connect latency exceeded the CLI's default 5-second timeout.
// Respect an explicit URL timeout; this does not change the runtime pg adapter.
if (!databaseUrl.searchParams.has('connect_timeout')) {
  databaseUrl.searchParams.set('connect_timeout', '30');
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  // Migrations/introspection need a session connection rather than transaction pooling.
  datasource: { url: databaseUrl.toString() },
});
