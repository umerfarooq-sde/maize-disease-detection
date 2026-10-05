import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import { createApp } from '../../src/app.js';
import { authenticate } from '../../src/middleware/authentication.js';
import { authorize } from '../../src/middleware/authorization.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import type { PublicAccount } from '../../src/modules/auth/auth.types.js';
import type { ErrorResponse, SuccessResponse } from '../../src/types/api.js';
import { sendSuccess } from '../../src/utils/respond.js';
import { silentLogger, testEnvironment, withServer } from '../foundation/helpers.js';
import { memoryRepository } from './helpers.js';

const credentials = { email: 'farmer@example.com', password: 'correct horse battery staple' };
const headers = { 'Content-Type': 'application/json', 'X-Auth-Request': '1' };
type Grant = { accessToken: string; tokenType: 'Bearer'; expiresIn: number; user: PublicAccount };
function post(url: string, route: string, body: unknown = {}, cookie?: string) {
  return fetch(`${url}/api/v1/auth/${route}`, {
    method: 'POST',
    headers: { ...headers, ...(cookie ? { Cookie: cookie } : {}) },
    body: JSON.stringify(body),
  });
}
function cookie(response: Response): string {
  const value = response.headers.get('set-cookie');
  assert.ok(value);
  return value.split(';')[0] ?? '';
}
const healthy = { async checkDatabase() {} };

test('HTTP registration normalizes email, rejects duplicates/admin assignment and validates input', async () => {
  const { repository, accounts } = memoryRepository();
  await withServer(createApp(testEnvironment, silentLogger, healthy, repository), async (url) => {
    const registered = await post(url, 'register', {
      ...credentials,
      email: ' Farmer@Example.COM ',
    });
    assert.equal(registered.status, 201);
    const body = (await registered.json()) as SuccessResponse<{ user: PublicAccount }>;
    assert.equal(body.data.user.email, credentials.email);
    assert.equal(body.data.user.role, 'FARMER');
    assert.deepEqual(Object.keys(body.data.user).sort(), ['createdAt', 'email', 'role']);
    assert.equal((await post(url, 'register', credentials)).status, 409);
    for (const invalid of [
      { ...credentials, role: 'ADMIN' },
      { ...credentials, password: 'short' },
      { ...credentials, email: 'invalid' },
      { ...credentials, userId: 'injected' },
      { ...credentials, password: 'x'.repeat(129) },
    ])
      assert.equal((await post(url, 'register', invalid)).status, 400);
    assert.equal(accounts.size, 1);
  });
});

test('HTTP login, protected me, invalid bearer, cookie-only refresh and logout', async () => {
  const { repository } = memoryRepository();
  await withServer(createApp(testEnvironment, silentLogger, healthy, repository), async (url) => {
    await (await post(url, 'register', credentials)).text();
    const wrong = await post(url, 'login', { ...credentials, password: 'wrong' });
    assert.equal(wrong.status, 401);
    assert.equal(((await wrong.json()) as ErrorResponse).error.code, 'INVALID_CREDENTIALS');
    const login = await post(url, 'login', { ...credentials, email: 'FARMER@EXAMPLE.COM' });
    assert.equal(login.status, 200);
    assert.equal(login.headers.get('cache-control'), 'no-store');
    const loggedIn = (await login.json()) as SuccessResponse<Grant>;
    assert.deepEqual(Object.keys(loggedIn.data).sort(), [
      'accessToken',
      'expiresIn',
      'tokenType',
      'user',
    ]);
    const initialCookie = cookie(login);
    assert.match(login.headers.get('set-cookie') ?? '', /HttpOnly/);
    assert.match(login.headers.get('set-cookie') ?? '', /SameSite=Strict/);
    const me = await fetch(`${url}/api/v1/auth/me`, {
      headers: { Authorization: `Bearer ${loggedIn.data.accessToken}` },
    });
    assert.equal(me.status, 200);
    assert.equal(
      ((await me.json()) as SuccessResponse<{ user: PublicAccount }>).data.user.role,
      'FARMER',
    );
    for (const authorization of ['', 'Bearer invalid', 'Basic credentials', initialCookie])
      assert.equal(
        (await fetch(`${url}/api/v1/auth/me`, { headers: { Authorization: authorization } }))
          .status,
        401,
      );
    const refresh = await post(url, 'refresh', {}, initialCookie);
    assert.equal(refresh.status, 200);
    const refreshed = (await refresh.json()) as SuccessResponse<Grant>;
    const refreshedCookie = cookie(refresh);
    assert.notEqual(refreshedCookie, initialCookie);
    const logout = await post(url, 'logout', {}, refreshedCookie);
    assert.equal(logout.status, 200);
    assert.match(logout.headers.get('set-cookie') ?? '', /Max-Age=0/);
    assert.equal((await post(url, 'refresh', {}, refreshedCookie)).status, 401);
    assert.equal(
      (
        await fetch(`${url}/api/v1/auth/me`, {
          headers: { Authorization: `Bearer ${refreshed.data.accessToken}` },
        })
      ).status,
      401,
    );
    assert.equal(
      (await post(url, 'refresh', { refreshToken: 'body tokens are forbidden' })).status,
      400,
    );
    assert.equal((await post(url, 'refresh')).status, 401);
  });
});

test('replayed refresh cookies revoke new grants and are cleared from the client', async () => {
  const { repository } = memoryRepository();
  await createAuthService(testEnvironment, repository).register(credentials);
  await withServer(createApp(testEnvironment, silentLogger, healthy, repository), async (url) => {
    const originalCookie = cookie(await post(url, 'login', credentials));
    const rotated = await post(url, 'refresh', {}, originalCookie);
    const nextCookie = cookie(rotated);
    const access = ((await rotated.json()) as SuccessResponse<Grant>).data.accessToken;
    const replay = await post(url, 'refresh', {}, originalCookie);
    assert.equal(replay.status, 401);
    assert.match(replay.headers.get('set-cookie') ?? '', /Max-Age=0/);
    assert.equal((await post(url, 'refresh', {}, nextCookie)).status, 401);
    assert.equal(
      (await fetch(`${url}/api/v1/auth/me`, { headers: { Authorization: `Bearer ${access}` } }))
        .status,
      401,
    );
  });
});

test('reusable RBAC protects FARMER/ADMIN routes and rejects unauthenticated users', async () => {
  const { repository } = memoryRepository();
  const service = createAuthService(testEnvironment, repository);
  await service.register(credentials);
  await service.createAdmin({ ...credentials, email: 'admin@example.com' });
  const farmer = await service.login(credentials);
  const admin = await service.login({ ...credentials, email: 'admin@example.com' });
  const app = express();
  app.use(requestContext(silentLogger));
  // Fixture routes only; no business/admin endpoint is registered in production.
  app.get('/farmer-only', authenticate(service), authorize('FARMER'), (_request, response) =>
    sendSuccess(response, {}),
  );
  app.get('/admin-only', authenticate(service), authorize('ADMIN'), (_request, response) =>
    sendSuccess(response, {}),
  );
  app.use(errorHandler(silentLogger));
  await withServer(app, async (url) => {
    for (const [token, path, status] of [
      [farmer.accessToken, '/farmer-only', 200],
      [farmer.accessToken, '/admin-only', 403],
      [admin.accessToken, '/admin-only', 200],
      [admin.accessToken, '/farmer-only', 403],
      ['', '/admin-only', 401],
    ] as const)
      assert.equal(
        (await fetch(`${url}${path}`, { headers: { Authorization: `Bearer ${token}` } })).status,
        status,
      );
  });
});

test('auth CSRF guards reject simple requests; credentialed CORS remains explicit', async () => {
  const { repository } = memoryRepository();
  const origin = 'https://example.com';
  await withServer(
    createApp({ ...testEnvironment, CORS_ORIGINS: [origin] }, silentLogger, healthy, repository),
    async (url) => {
      assert.equal(
        (
          await fetch(`${url}/api/v1/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(credentials),
          })
        ).status,
        403,
      );
      assert.equal(
        (
          await fetch(`${url}/api/v1/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Auth-Request': '1' },
            body: 'email=foo',
          })
        ).status,
        415,
      );
      assert.equal(
        (
          await fetch(`${url}/api/v1/auth/login`, {
            method: 'POST',
            headers: { ...headers, Origin: 'https://hostile.example' },
            body: JSON.stringify(credentials),
          })
        ).status,
        403,
      );
      const preflight = await fetch(`${url}/api/v1/auth/login`, {
        method: 'OPTIONS',
        headers: {
          Origin: origin,
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'X-Auth-Request, Content-Type',
        },
      });
      assert.equal(preflight.status, 204);
      assert.equal(preflight.headers.get('access-control-allow-credentials'), 'true');
    },
  );
});

test('production refresh cookie is host-bound, Secure, HttpOnly and omitted from JSON', async () => {
  const { repository } = memoryRepository();
  const environment = { ...testEnvironment, NODE_ENV: 'production' as const };
  await createAuthService(environment, repository).register(credentials);
  await withServer(createApp(environment, silentLogger, healthy, repository), async (url) => {
    const login = await post(url, 'login', credentials);
    const setCookie = login.headers.get('set-cookie') ?? '';
    assert.ok(setCookie.startsWith('__Host-maizedoctor_refresh='));
    assert.match(setCookie, /Secure/);
    assert.match(setCookie, /HttpOnly/);
    assert.match(setCookie, /Path=\//);
    assert.ok(!setCookie.includes('Domain='));
    const body = await login.text();
    for (const key of [
      'refreshToken',
      'refreshTokenHash',
      'passwordHash',
      'userId',
      'sessionId',
      'JWT_SECRET',
    ])
      assert.ok(!body.includes(key));
  });
});

test('credential rate limits stop login hashing beyond the configured limit', async () => {
  const { repository } = memoryRepository();
  await withServer(
    createApp({ ...testEnvironment, AUTH_RATE_LIMIT_MAX: 1 }, silentLogger, healthy, repository),
    async (url) => {
      assert.equal((await post(url, 'login', credentials)).status, 401);
      const limited = await post(url, 'register', credentials);
      assert.equal(limited.status, 429);
      assert.equal(((await limited.json()) as ErrorResponse).error.code, 'RATE_LIMITED');
      assert.ok(limited.headers.has('retry-after'));
    },
  );
});
