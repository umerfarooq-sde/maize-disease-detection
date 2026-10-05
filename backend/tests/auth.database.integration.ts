import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import { createDatabaseClient } from '../src/database/client.js';
import { AppError } from '../src/errors/app-error.js';
import { createAuthRepository } from '../src/modules/auth/auth.repository.js';
import { createAuthService } from '../src/modules/auth/auth.service.js';
import { tokenHash } from '../src/modules/auth/auth.tokens.js';
import { createHealthRepository } from '../src/modules/health/health.repository.js';
import type { SuccessResponse } from '../src/types/api.js';
import { assertSqlRejects, rollbackFixture } from './database-support.js';
import { silentLogger, testEnvironment, withServer } from './foundation/helpers.js';

test('Prisma-backed authentication, rotation races, revocation and session constraints', {
  timeout: 180000,
}, async (t) => {
  const database = createDatabaseClient();
  const repository = createAuthRepository(database);
  const service = createAuthService(testEnvironment, repository);
  const email = `phase4-${randomUUID()}@example.invalid`;
  const credentials = { email, password: 'synthetic authentication password for tests' };
  let fixtureId: string | undefined;
  const unauthorized = (error: unknown): boolean =>
    error instanceof AppError && error.status === 401;
  try {
    await service.register(credentials);
    const account = await repository.findAccount(email);
    assert.ok(account);
    fixtureId = account.id;
    await t.test(
      'registration stores Argon2 and handles duplicate PostgreSQL uniqueness',
      async () => {
        assert.match(account.passwordHash, /^\$argon2id\$/);
        await assert.rejects(
          service.register(credentials),
          (error: unknown) => error instanceof AppError && error.code === 'ACCOUNT_EXISTS',
        );
      },
    );
    const first = await service.login(credentials);
    await t.test('session persists only a digest and authenticates its farmer', async () => {
      const principal = await service.authenticate(first.accessToken);
      assert.equal(principal.userId, account.id);
      const stored = await database.authSession.findUniqueOrThrow({
        where: { id: principal.sessionId },
      });
      assert.equal(stored.refreshTokenHash, tokenHash(first.refreshToken));
      assert.notEqual(stored.refreshTokenHash, first.refreshToken);
    });
    await t.test(
      'real HTTP app uses Prisma for login, me, refresh, logout and access revocation',
      async () => {
        const app = createApp(
          testEnvironment,
          silentLogger,
          createHealthRepository(database),
          repository,
        );
        await withServer(app, async (url) => {
          async function post(path: string, body: unknown, cookie = '') {
            return fetch(`${url}/api/v1/auth/${path}`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-Auth-Request': '1',
                Cookie: cookie,
              },
              body: JSON.stringify(body),
            });
          }
          const login = await post('login', credentials);
          assert.equal(login.status, 200);
          const loggedIn = (await login.json()) as SuccessResponse<{ accessToken: string }>;
          const cookie = login.headers.get('set-cookie')?.split(';')[0];
          assert.ok(cookie);
          assert.equal(
            (
              await fetch(`${url}/api/v1/auth/me`, {
                headers: { Authorization: `Bearer ${loggedIn.data.accessToken}` },
              })
            ).status,
            200,
          );
          const refreshed = await post('refresh', {}, cookie);
          assert.equal(refreshed.status, 200);
          const newCookie = refreshed.headers.get('set-cookie')?.split(';')[0];
          assert.ok(newCookie);
          await refreshed.text();
          assert.equal((await post('logout', {}, newCookie)).status, 200);
          assert.equal(
            (
              await fetch(`${url}/api/v1/auth/me`, {
                headers: { Authorization: `Bearer ${loggedIn.data.accessToken}` },
              })
            ).status,
            401,
          );
        });
      },
    );
    await t.test(
      'concurrent refresh consumes a token once and replay revocation commits',
      async () => {
        const results = await Promise.allSettled([
          service.refresh(first.refreshToken),
          service.refresh(first.refreshToken),
        ]);
        assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
        const success = results.find((result) => result.status === 'fulfilled');
        assert.ok(success?.status === 'fulfilled');
        await assert.rejects(service.authenticate(success.value.accessToken), unauthorized);
        await assert.rejects(service.refresh(success.value.refreshToken), unauthorized);
        const sessions = await database.authSession.findMany({ where: { userId: account.id } });
        assert.ok(sessions.every((session) => session.revokedAt !== null));
      },
    );
    await t.test(
      'session expiry/owner/hash/revocation constraints reject unsafe writes with rollback',
      async () => {
        const grant = await service.login(credentials);
        const { sessionId } = await service.authenticate(grant.accessToken);
        await assert.rejects(
          database.$transaction(async (tx) => {
            await assertSqlRejects(
              tx,
              "UPDATE auth_sessions SET expires_at = expires_at + interval '1 day' WHERE id=$1::uuid",
              [sessionId],
              '23514',
            );
            await assertSqlRejects(
              tx,
              'UPDATE auth_sessions SET user_id = $1::uuid WHERE id=$2::uuid',
              [randomUUID(), sessionId],
              '23514',
            );
            await assertSqlRejects(
              tx,
              "UPDATE auth_sessions SET refresh_token_hash = 'invalid' WHERE id=$1::uuid",
              [sessionId],
              '23514',
            );
            await tx.authSession.update({
              where: { id: sessionId },
              data: { revokedAt: new Date() },
            });
            await assertSqlRejects(
              tx,
              'UPDATE auth_sessions SET revoked_at = NULL WHERE id=$1::uuid',
              [sessionId],
              '23514',
            );
            throw rollbackFixture;
          }),
          (error: unknown) => error === rollbackFixture,
        );
        await service.authenticate(grant.accessToken);
        await service.logout(grant.refreshToken);
      },
    );
  } finally {
    // Only this test's newly created UUID+email may be removed; FK cascade cleans its sessions.
    if (fixtureId) {
      await database.user.deleteMany({ where: { id: fixtureId, email } });
      assert.equal(await database.authSession.count({ where: { userId: fixtureId } }), 0);
    }
    await database.$disconnect();
  }
});
