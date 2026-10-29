import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { AdminSeedDependencies } from '../../src/cli/admin-seed.js';
import {
  adminSeedInvocationAllowed,
  adminSeedTarget,
  runAdminSeed,
} from '../../src/cli/admin-seed.js';
import { verifyPassword } from '../../src/modules/auth/auth.password.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { testEnvironment as sourceEnvironment } from '../foundation/helpers.js';
import { memoryRepository } from './helpers.js';

const credentials = {
  email: 'operator@example.invalid',
  password: 'synthetic administrator passphrase',
};
const testEnvironment = {
  ...sourceEnvironment,
  DATABASE_URL: 'postgresql://fixture_operator@localhost/maizedoctor',
};
const target = adminSeedTarget(testEnvironment).confirmation;

function fixture(
  answers = [credentials.email, credentials.password, credentials.password, target],
) {
  const memory = memoryRepository();
  const messages: string[] = [];
  const prompts: { label: string; hidden: boolean }[] = [];
  let connections = 0,
    disconnects = 0,
    closed = 0;
  const dependencies: AdminSeedDependencies = {
    terminal: {
      async ask(label, hidden = false) {
        prompts.push({ label, hidden });
        const answer = answers.shift();
        assert.notEqual(answer, undefined, 'Unexpected prompt');
        return answer ?? '';
      },
      write(message) {
        messages.push(message);
      },
      close() {
        closed++;
      },
    },
    loadEnvironment: () => testEnvironment,
    connect() {
      connections++;
      return {
        repository: memory.repository,
        async checkDatabase() {},
        async disconnect() {
          disconnects++;
        },
      };
    },
  };
  return {
    ...memory,
    dependencies,
    messages,
    prompts,
    counts: () => ({ connections, disconnects, closed }),
  };
}

test('interactive seed normalizes email, uses existing Argon2id and authenticates as active ADMIN', async () => {
  const f = fixture([
    '  OPERATOR@EXAMPLE.INVALID ',
    credentials.password,
    credentials.password,
    target,
  ]);
  assert.equal(await runAdminSeed(f.dependencies), 0);
  const account = f.accounts.get(credentials.email);
  assert.ok(account);
  assert.equal(account.role, 'ADMIN');
  assert.equal(account.status, 'ACTIVE');
  assert.match(account.passwordHash, /^\$argon2id\$v=19\$/);
  assert.deepEqual(
    Object.fromEntries(
      (account.passwordHash.split('$')[3] ?? '').split(',').map((item) => item.split('=')),
    ),
    { m: '65536', t: '3', p: '1' },
  );
  assert.equal(await verifyPassword(account.passwordHash, credentials.password), true);
  const service = createAuthService(testEnvironment, f.repository);
  const grant = await service.login(credentials);
  assert.equal((await service.authenticate(grant.accessToken)).role, 'ADMIN');
  assert.deepEqual(
    f.prompts.map((p) => p.hidden),
    [false, true, true, false],
  );
  assert.deepEqual(f.counts(), { connections: 1, disconnects: 1, closed: 1 });
  assert.ok(!f.messages.join('\n').includes(credentials.password));
  assert.ok(!f.messages.join('\n').includes(account.passwordHash));
});

test('repeat invocation preserves existing ADMIN password, status and sessions', async () => {
  const f = fixture();
  const service = createAuthService(testEnvironment, f.repository);
  await service.createAdmin(credentials);
  await service.login(credentials);
  const before = structuredClone([...f.accounts.values()]);
  assert.equal(await runAdminSeed(f.dependencies), 0);
  assert.deepEqual([...f.accounts.values()], before);
  assert.equal(f.sessions.size, 1);
  assert.match(f.messages.join('\n'), /Account exists/);
});

for (const role of ['ADMIN', 'FARMER'] as const) {
  for (const status of ['ACTIVE', 'SUSPENDED', 'DEACTIVATED'] as const) {
    test(`existing ${status} ${role} is never promoted, reactivated or overwritten`, async () => {
      const f = fixture();
      await createAuthService(testEnvironment, f.repository)[
        role === 'ADMIN' ? 'createAdmin' : 'register'
      ](credentials);
      const account = f.accounts.get(credentials.email);
      assert.ok(account);
      account.status = status;
      const before = structuredClone(account);
      assert.equal(await runAdminSeed(f.dependencies), role === 'ADMIN' ? 0 : 1);
      assert.deepEqual(account, before);
      assert.match(f.messages.join('\n'), new RegExp(status));
      assert.equal(f.sessions.size, 0);
    });
  }
}

for (const [name, answers] of [
  ['invalid email', ['not-an-email']],
  ['empty email', ['']],
  ['weak password', [credentials.email, 'short', 'short']],
  ['empty password', [credentials.email, '', '']],
  ['long password', [credentials.email, 'p'.repeat(129), 'p'.repeat(129)]],
  ['confirmation mismatch', [credentials.email, credentials.password, 'different']],
  [
    'cancelled target confirmation',
    [credentials.email, credentials.password, credentials.password, 'no'],
  ],
] as const) {
  test(`${name} cannot open a database or create an account`, async () => {
    const f = fixture([...answers]);
    assert.equal(await runAdminSeed(f.dependencies), 1);
    assert.deepEqual(f.counts(), { connections: 0, disconnects: 0, closed: 1 });
    assert.equal(f.accounts.size, 0);
  });
}

test('database errors are sanitized, disconnect is awaited and ambiguous commit has a check-only recovery', async () => {
  const f = fixture();
  f.repository.createAccount = async () => {
    throw new Error('private SQL password token connection-string');
  };
  assert.equal(await runAdminSeed(f.dependencies), 1);
  assert.match(f.messages.join('\n'), /outcome may be unknown/);
  assert.ok(!f.messages.join('\n').includes('private SQL'));
  assert.deepEqual(f.counts(), { connections: 1, disconnects: 1, closed: 1 });
});

test('lost commit acknowledgement can be reconciled read-only without overwriting the committed account', async () => {
  const f = fixture();
  const create = f.repository.createAccount;
  f.repository.createAccount = async (input) => {
    await create(input);
    throw new Error('connection lost after commit');
  };
  assert.equal(await runAdminSeed(f.dependencies), 1);
  const checker = fixture([credentials.email]);
  checker.dependencies.connect = () => ({
    repository: f.repository,
    async checkDatabase() {},
    async disconnect() {},
  });
  assert.equal(await runAdminSeed(checker.dependencies, true), 0);
  assert.equal(f.accounts.size, 1);
  assert.match(checker.messages.join('\n'), /ADMIN; status: ACTIVE/);
});

test('disconnect failure is nonzero and preserves acknowledgement of committed creation', async () => {
  const f = fixture();
  f.dependencies.connect = () => ({
    repository: f.repository,
    async checkDatabase() {},
    async disconnect() {
      throw new Error('secret driver details');
    },
  });
  assert.equal(await runAdminSeed(f.dependencies), 1);
  assert.match(f.messages.join('\n'), /creation committed/);
  assert.ok(!f.messages.join('\n').includes('secret driver details'));
  assert.equal(f.accounts.size, 1);
});

test('check-only mode asks no password, creates no account/session and reports absence', async () => {
  const f = fixture([credentials.email]);
  assert.equal(await runAdminSeed(f.dependencies, true), 0);
  assert.equal(f.accounts.size, 0);
  assert.equal(f.sessions.size, 0);
  assert.equal(f.prompts.length, 1);
  assert.match(f.messages.join('\n'), /No account exists/);
});

test('failed readiness/production privilege checks prevent creation and still disconnect', async () => {
  const f = fixture();
  let disconnected = false;
  f.dependencies.connect = () => ({
    repository: f.repository,
    async checkDatabase() {
      throw new Error('unsafe role or unavailable database; private details');
    },
    async disconnect() {
      disconnected = true;
    },
  });
  assert.equal(await runAdminSeed(f.dependencies), 1);
  assert.equal(f.accounts.size, 0);
  assert.equal(disconnected, true);
  assert.ok(!f.messages.join('\n').includes('private details'));
});

test('connection factory failure closes the terminal and reports only sanitized guidance', async () => {
  const f = fixture();
  f.dependencies.connect = () => {
    throw new Error('private database URL');
  };
  assert.equal(await runAdminSeed(f.dependencies), 1);
  assert.equal(f.accounts.size, 0);
  assert.equal(f.counts().closed, 1);
  assert.ok(!f.messages.join('\n').includes('private database URL'));
});

test('concurrent invocations reconcile unique-email conflicts without changing the winning credentials', async () => {
  const f = fixture(),
    g = fixture();
  g.dependencies.connect = () => ({
    repository: f.repository,
    async checkDatabase() {},
    async disconnect() {},
  });
  assert.deepEqual(
    await Promise.all([runAdminSeed(f.dependencies), runAdminSeed(g.dependencies)]),
    [0, 0],
  );
  assert.equal(f.accounts.size, 1);
  assert.equal(f.sessions.size, 0);
  assert.match([...f.messages, ...g.messages].join('\n'), /already exists/);
});

test('configuration and unsafe targets fail before database access without revealing supplied values', async () => {
  const f = fixture();
  f.dependencies.loadEnvironment = () => {
    throw new Error('database-password private-key');
  };
  assert.equal(await runAdminSeed(f.dependencies), 1);
  assert.equal(f.counts().connections, 0);
  assert.ok(!f.messages.join('\n').includes('database-password'));
  for (const url of [
    'postgresql://localhost/maizedoctor',
    'postgresql://operator:secret@localhost/postgres',
    'postgresql://operator:secret@localhost/maizedoctor?schema=public%3Bdrop',
    'postgresql://operator:secret@remote.example.invalid/maizedoctor?sslmode=disable',
    'postgresql://operator:secret@localhost/maizedoctor?schema=public&schema=other',
    'postgresql://operator:secret@localhost/maizedoctor?database=other',
    'postgresql://operator:secret@localhost/maizedoctor?user=other',
    'postgresql://operator:secret@localhost/maizedoctor?options=-csearch_path%3Dother',
  ])
    assert.throws(() => adminSeedTarget({ ...testEnvironment, DATABASE_URL: url }));
});

test('production target needs an explicit production confirmation and never prints connection credentials', async () => {
  const environment = {
    ...testEnvironment,
    NODE_ENV: 'production' as const,
    DATABASE_URL:
      'postgresql://operator:private-secret@db.example.invalid/maizedoctor?sslmode=verify-full',
  };
  const info = adminSeedTarget(environment);
  assert.match(info.confirmation, /^CREATE PRODUCTION ADMIN /);
  assert.ok(!info.summary.includes('operator') && !info.summary.includes('private-secret'));
  const f = fixture([
    credentials.email,
    credentials.password,
    credentials.password,
    'CREATE ADMIN maizedoctor public',
  ]);
  f.dependencies.loadEnvironment = () => environment;
  assert.equal(await runAdminSeed(f.dependencies), 1);
  assert.equal(f.counts().connections, 0);
});

test('manual entry rejects redirected input, CI and all credential arguments', () => {
  assert.equal(adminSeedInvocationAllowed({}, [], true), true);
  assert.equal(adminSeedInvocationAllowed({}, ['--check'], true), true);
  assert.equal(adminSeedInvocationAllowed({}, [], false), false);
  for (const key of ['CI', 'GITHUB_ACTIONS', 'TF_BUILD', 'BUILD_BUILDID'])
    assert.equal(adminSeedInvocationAllowed({ [key]: 'true' }, [], true), false);
  for (const args of [
    ['--email', credentials.email],
    ['--password=secret'],
    ['unknown'],
    ['--check', '--check'],
  ])
    assert.equal(adminSeedInvocationAllowed({}, args, true), false);
});
