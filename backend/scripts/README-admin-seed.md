# Secure Admin account setup

This manually invoked tool creates one account through the existing auth service
and repository. It never starts the HTTP server, migrates/seeds content, or runs
as part of startup/CI. No account is created when you install/build the project.

## Preconditions

- Use the project's Node 24.22+ 24.x runtime and installed backend dependencies.
- Existing Prisma client and database schema must already be available.
- Review the existing backend environment configuration (`backend/.env`, process
  overrides, or `MAIZEDOCTOR_SECRETS_FILE`). The same complete runtime validator,
  signing-key rules and production settings apply; do not print secret values.
- Use an authorized database identity with users SELECT/INSERT permission.
  Production additionally runs the existing least-privilege runtime-role check;
  a superuser, schema owner, migrator or DDL-capable role is refused. Do not weaken
  privileges/TLS to make the command pass.
- Run from a normal interactive PowerShell/terminal, not CI, a pipe, redirected
  input or a transcript/terminal-recording session. Remote targets require verified
  TLS. The tool rejects missing usernames, ambiguous schema names/system databases
  and requires an exact displayed database/schema confirmation before creation.

## PowerShell invocation

From the repository root:

```powershell
. .\scripts\use-project-node.ps1
Set-Location .\backend
npm run admin:seed
```

Enter your email, password and password confirmation at the prompts. Passwords
are hidden (no stars). Use 15-128 Unicode code points under the privileged
bootstrap policy; Farmer signup separately allows 6-128. Email is trimmed/lowercased.
Verify environment, host, port,
database and schema, then type the exact confirmation shown. Production uses
`CREATE PRODUCTION ADMIN <database> <schema>`; other environments use
`CREATE ADMIN <database> <schema>`. Never pass credentials as command arguments,
environment variables, piped JSON or files for this interactive entrypoint.

There is **no Admin name field in the existing User model**. No name is requested
or stored in a Farmer profile. Role ADMIN is fixed by the existing auth service;
ACTIVE is the existing trusted database default. IDs/timestamps use current rules.
The existing Argon2id helper retains its memory/time/concurrency settings.

## Existing accounts and verification

```powershell
npm run admin:seed -- --check
```

This prompts only for email and performs a read-only account lookup. Output is
limited to existence, supplied normalized email, role and status; no hashes,
tokens, internal IDs or connection strings. It creates no session or account.

- Existing ADMIN: report its status and leave password/sessions unchanged. Exit 0
  does not imply a suspended/deactivated account can sign in.
- Existing FARMER: refuse, exit 1; never promote or overwrite.
- Missing account in check mode: report absence, exit 0; no mutation.
- Competing setup: the unique email constraint prevents duplicates; the losing
  invocation reports the existing account without changing it.
- Invalid input/cancellation: exit 1 before opening a database connection.
- Database failure: exit 1 with sanitized guidance. A lost commit acknowledgement
  may mean creation succeeded: check first instead of attempting a password reset.
- Disconnect failure after success: explicitly report the committed result and
  exit 1. Check state; existing credentials are never overwritten on retry.

The single users INSERT is atomic. No sessions are created/revoked and no
additional account-creation audit event is introduced: the existing operator
bootstrap does not produce one. This tool does not invent an audit actor or a
second account-creation implementation. Existing Admin content mutations retain
their normal audit behavior. Keep secure external operator change records as needed.
JavaScript cannot guarantee zeroization of immutable password strings; the tool
keeps them transient, disables readline history and writes no credential files.

## Flutter login

`Profile -> Administrator workspace -> Administrator sign-in`

Enter the chosen Admin email/password and select **Sign in as Admin**. The existing
`POST /api/v1/auth/login` contract, refresh cookie and ADMIN role checks are
unchanged. A successful login shows **Admin overview / System overview**, outside
the Farmer navigation shell. Backend and Flutter must target the same environment.
No public Admin registration or bootstrap HTTP endpoint exists.

## Common failures

- Configuration/target rejected: check complete backend environment, secret-file
  conflicts, explicit database username/name/schema and verified remote TLS. Do
  not paste the connection string into issue reports.
- Database unavailable: check provider availability/network, existing schema,
  credentials and SELECT/INSERT permission. No automatic reconnect loop is used.
- Production role rejected: use the already authorized least-privilege identity;
  do not use a migrator/admin database credential or modify roles through this tool.
- No interactive terminal/CI rejection: run directly in a normal terminal. Only
  `--check` is accepted as an argument; do not supply an email/password flag.
- Account already exists: use its existing credentials or the separately authorized
  account-management process. This command is not a promotion/reset/reactivation tool.

## Verification without real accounts

`npm test` includes isolated in-memory auth/runner and terminal-input tests.
`npm run test:admin-seed:database` is opt-in via
`TEST_ADMIN_SEED_DATABASE_URL`: only localhost databases named `admin_seed_fixture`,
`maizedoctor_ci`, `phase25_ci`, or `phase25_native_final` are accepted. It creates a
random owned schema, installs only existing committed authentication DDL there,
tests real Prisma/Argon2/HTTP login, then removes that schema. It never falls back
to DATABASE_URL or inserts into the configured application's users table. Supply
only a disposable fixture database; this is not an instruction to change a real
database role/password or run the interactive seeder in CI.
