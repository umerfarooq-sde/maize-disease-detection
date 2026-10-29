import type { Environment } from '../config/environment.js';
import { databaseConnectionUrl, hasVerifiedDatabaseTransport } from '../database/connection-url.js';
import { AppError } from '../errors/app-error.js';
import type { AuthRepository } from '../modules/auth/auth.repository.js';
import { createAuthService } from '../modules/auth/auth.service.js';
import { registrationCredentials } from '../modules/auth/auth.validators.js';

export interface AdminTerminal {
  ask(label: string, hidden?: boolean): Promise<string>;
  write(message: string): void;
  close(): void;
}
export interface AdminSeedConnection {
  repository: AuthRepository;
  checkDatabase(): Promise<void>;
  disconnect(): Promise<void>;
}
export interface AdminSeedDependencies {
  terminal: AdminTerminal;
  loadEnvironment(): Environment;
  connect(environment: Environment): AdminSeedConnection;
}

/** Show only the target identity, never a URL, role credential or driver error. */
export function adminSeedTarget(environment: Environment) {
  const url = databaseConnectionUrl(environment.DATABASE_URL);
  const database = decodeURIComponent(url.pathname.slice(1));
  const schema = url.searchParams.get('schema') ?? 'public';
  const options = new Set([
    'schema',
    'sslmode',
    'sslrootcert',
    'sslcert',
    'sslkey',
    'connect_timeout',
    'application_name',
    'pgbouncer',
    'connection_limit',
    'pool_timeout',
    'statement_timeout',
    'uselibpqcompat',
    'channel_binding',
  ]);
  if (
    !url.username ||
    url.hash ||
    !/^[A-Za-z0-9_-]{1,63}$/.test(database) ||
    ['postgres', 'template0', 'template1'].includes(database.toLowerCase()) ||
    !/^[A-Za-z_][A-Za-z0-9_]{0,62}$/.test(schema) ||
    [...url.searchParams.keys()].some((key) => !options.has(key)) ||
    !hasVerifiedDatabaseTransport(url)
  ) {
    throw new Error('Unsafe database target.');
  }
  const production = environment.NODE_ENV === 'production';
  return {
    summary: `Environment: ${environment.NODE_ENV}; host: ${url.hostname}; port: ${url.port || '5432'}; database: ${database}; schema: ${schema}`,
    confirmation: `${production ? 'CREATE PRODUCTION ADMIN' : 'CREATE ADMIN'} ${database} ${schema}`,
  };
}

export function adminSeedInvocationAllowed(
  input: NodeJS.ProcessEnv,
  arguments_: readonly string[],
  interactive: boolean,
): boolean {
  return (
    interactive &&
    (arguments_.length === 0 || (arguments_.length === 1 && arguments_[0] === '--check')) &&
    !['CI', 'GITHUB_ACTIONS', 'TF_BUILD', 'BUILD_BUILDID'].some((key) => {
      const value = input[key]?.trim().toLowerCase();
      return value && value !== 'false' && value !== '0';
    })
  );
}

/** Interactive orchestration only; account creation remains in the auth service. */
export async function runAdminSeed(
  dependencies: AdminSeedDependencies,
  checkOnly = false,
): Promise<number> {
  const { terminal } = dependencies;
  let connection: AdminSeedConnection | undefined;
  let committed = false;
  let exitCode = 0;
  let stage: 'configuration' | 'input' | 'database' = 'configuration';
  try {
    const perform = async (): Promise<number> => {
      const environment = dependencies.loadEnvironment();
      const target = adminSeedTarget(environment);
      terminal.write(
        `MAIZEDOCTOR - Admin Account ${checkOnly ? 'Check' : 'Setup'}\n${target.summary}`,
      );
      stage = 'input';
      const email = (await terminal.ask('Admin email: ')).trim().toLowerCase();
      // Reuse the operator-bootstrap contract, including its email validation.
      if (!registrationCredentials.shape.email.safeParse(email).success) {
        terminal.write('Invalid email. Enter a valid email of at most 254 characters.');
        return 1;
      }
      let password = '';
      if (!checkOnly) {
        password = await terminal.ask('Admin password (15-128 characters): ', true);
        const confirmation = await terminal.ask('Confirm password: ', true);
        if (password !== confirmation) {
          terminal.write('Password confirmation does not match. No account was created.');
          return 1;
        }
        if (!registrationCredentials.safeParse({ email, password }).success) {
          terminal.write('Invalid password. Use 15-128 characters. No account was created.');
          return 1;
        }
        terminal.write(`Verify this target. Type exactly: ${target.confirmation}`);
        if ((await terminal.ask('Confirmation: ')) !== target.confirmation) {
          terminal.write('Cancelled. No account was created.');
          return 1;
        }
      }
      stage = 'database';
      connection = dependencies.connect(environment);
      await connection.checkDatabase();
      const existing = await connection.repository.findAccount(email);
      if (existing) {
        password = '';
        terminal.write(
          `Account exists. Email: ${email}; role: ${existing.role}; status: ${existing.status}. No changes made.`,
        );
        return existing.role === 'ADMIN' ? 0 : 1;
      }
      if (checkOnly) {
        terminal.write('No account exists for this email. No changes made.');
        return 0;
      }
      terminal.write('Creating administrator...');
      try {
        await createAuthService(environment, connection.repository).createAdmin({
          email,
          password,
        });
        committed = true;
      } catch (error) {
        if (!(error instanceof AppError) || error.code !== 'ACCOUNT_EXISTS') throw error;
        // A concurrent invocation may have won the unique-email constraint.
        const winner = await connection.repository.findAccount(email);
        if (!winner) throw error;
        terminal.write(
          `Account already exists. Role: ${winner.role}; status: ${winner.status}. No changes made by this invocation.`,
        );
        return winner.role === 'ADMIN' ? 0 : 1;
      } finally {
        password = '';
      }
      terminal.write(
        `Admin account created successfully.\nEmail: ${email}\nRole: ADMIN\nStatus: ACTIVE\nYou can now sign in through the MAIZEDOCTOR Admin interface.`,
      );
      return 0;
    };
    exitCode = await perform();
  } catch {
    exitCode = 1;
    terminal.write(
      stage === 'configuration'
        ? 'Configuration/target rejected. Check backend environment settings, database/schema identity and verified TLS. No account was created.'
        : stage === 'input'
          ? 'Input cancelled or terminal unavailable. No account was created.'
          : 'Database operation failed. Check connectivity, permissions and production runtime-role policy. Commit outcome may be unknown: use admin:seed -- --check before trying again. No existing account will be overwritten.',
    );
  } finally {
    if (connection) {
      try {
        await connection.disconnect();
      } catch {
        exitCode = 1;
        terminal.write(
          committed
            ? 'Account creation committed, but database disconnect failed. Verify with --check; do not assume creation failed.'
            : 'Database disconnect failed. Verify connectivity and account state with --check.',
        );
      }
    }
    terminal.close();
  }
  return exitCode;
}
