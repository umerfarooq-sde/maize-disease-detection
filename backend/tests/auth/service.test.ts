import assert from 'node:assert/strict';
import { test } from 'node:test';
import { decodeJwt, SignJWT } from 'jose';
import { AppError } from '../../src/errors/app-error.js';
import { createAuthService } from '../../src/modules/auth/auth.service.js';
import { createTokenService } from '../../src/modules/auth/auth.tokens.js';
import { testEnvironment } from '../foundation/helpers.js';
import { memoryRepository } from './helpers.js';

const credentials = { email: 'farmer@example.com', password: 'correct horse battery staple' };
const unauthorized = (error: unknown): boolean => error instanceof AppError && error.status === 401;

test('Argon2 registration stores a salted hash and returns a safe FARMER DTO', async () => {
  const { repository, accounts } = memoryRepository();
  const service = createAuthService(testEnvironment, repository);
  const user = await service.register(credentials);
  const stored = accounts.get(credentials.email);
  assert.ok(stored);
  const encoded = stored.passwordHash.split('$');
  assert.equal(encoded[1], 'argon2id');
  assert.equal(encoded[2], 'v=19');
  assert.deepEqual(
    Object.fromEntries((encoded[3] ?? '').split(',').map((parameter) => parameter.split('='))),
    { m: '65536', t: '3', p: '1' },
  );
  assert.ok(!stored.passwordHash.includes(credentials.password));
  assert.deepEqual(Object.keys(user).sort(), ['createdAt', 'email', 'role']);
  assert.equal(user.role, 'FARMER');
  await assert.rejects(
    service.register(credentials),
    (error: unknown) => error instanceof AppError && error.code === 'ACCOUNT_EXISTS',
  );
});

test('login rejects wrong/unknown/inactive accounts uniformly; correct credentials create hashed sessions', async () => {
  const { repository, accounts, sessions } = memoryRepository();
  const service = createAuthService(testEnvironment, repository);
  await service.register(credentials);
  await assert.rejects(service.login({ ...credentials, password: 'wrong password' }), unauthorized);
  await assert.rejects(
    service.login({ ...credentials, email: 'unknown@example.com' }),
    unauthorized,
  );
  const grant = await service.login(credentials);
  const session = [...sessions.values()][0];
  assert.ok(session);
  assert.match(session.refreshTokenHash, /^[a-f0-9]{64}$/);
  assert.notEqual(session.refreshTokenHash, grant.refreshToken);
  const user = accounts.get(credentials.email);
  assert.ok(user);
  user.status = 'SUSPENDED';
  await assert.rejects(service.login(credentials), unauthorized);
  await assert.rejects(service.authenticate(grant.accessToken), unauthorized);
  await assert.rejects(service.refresh(grant.refreshToken), unauthorized);
});

test('refresh rotates once, retains absolute expiry, and replay revokes the entire session', async () => {
  const { repository, sessions } = memoryRepository();
  const service = createAuthService(testEnvironment, repository);
  await service.register(credentials);
  const original = await service.login(credentials);
  const refreshed = await service.refresh(original.refreshToken);
  assert.notEqual(refreshed.refreshToken, original.refreshToken);
  assert.equal(refreshed.refreshExpiresAt.getTime(), original.refreshExpiresAt.getTime());
  await service.authenticate(refreshed.accessToken);
  await assert.rejects(service.refresh(original.refreshToken), unauthorized);
  assert.ok([...sessions.values()][0]?.revokedAt);
  await assert.rejects(service.refresh(refreshed.refreshToken), unauthorized);
  await assert.rejects(service.authenticate(original.accessToken), unauthorized);
  await assert.rejects(service.authenticate(refreshed.accessToken), unauthorized);
});

test('logout revokes current session and access immediately, preserving other logins', async () => {
  const { repository } = memoryRepository();
  const service = createAuthService(testEnvironment, repository);
  await service.register(credentials);
  const first = await service.login(credentials);
  const second = await service.login(credentials);
  await service.logout(first.refreshToken);
  await service.logout(first.refreshToken);
  await assert.rejects(service.refresh(first.refreshToken), unauthorized);
  await assert.rejects(service.authenticate(first.accessToken), unauthorized);
  await service.authenticate(second.accessToken);
});

test('tokens cannot cross purposes; signatures, issuer, audience, claims and expiry are enforced', async () => {
  let now = new Date();
  const { repository } = memoryRepository();
  const service = createAuthService(testEnvironment, repository, () => now);
  await service.register(credentials);
  const grant = await service.login(credentials);
  await assert.rejects(service.authenticate(grant.refreshToken), unauthorized);
  await assert.rejects(service.refresh(grant.accessToken), unauthorized);
  await assert.rejects(
    service.authenticate(`${grant.accessToken.slice(0, -8)}bad-data`),
    unauthorized,
  );
  const payload = decodeJwt(grant.accessToken);
  assert.ok(!('userId' in payload) && !('email' in payload) && !('role' in payload));
  const key = Buffer.from(testEnvironment.JWT_SECRET, 'base64url');
  const noExpiry = { ...payload };
  delete noExpiry.exp;
  for (const altered of [
    { ...payload, iss: 'wrong' },
    { ...payload, aud: 'wrong' },
    { ...payload, purpose: 'refresh' },
    { ...payload, sub: 'not-a-uuid' },
    noExpiry,
  ]) {
    const token = await new SignJWT(altered)
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .sign(key);
    await assert.rejects(service.authenticate(token), unauthorized);
  }
  const otherAlgorithm = await new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS384', typ: 'JWT' })
    .sign(key);
  await assert.rejects(service.authenticate(otherAlgorithm), unauthorized);
  now = new Date(now.getTime() + testEnvironment.JWT_ACCESS_TTL_SECONDS * 1000);
  await assert.rejects(service.authenticate(grant.accessToken), unauthorized);
  await service.refresh(grant.refreshToken);
  now = new Date(grant.refreshExpiresAt.getTime() + 1000);
  await assert.rejects(service.refresh(grant.refreshToken), unauthorized);
});

test('controlled admin creation and current database roles drive authorization', async () => {
  const { repository, accounts } = memoryRepository();
  const service = createAuthService(testEnvironment, repository);
  const admin = await service.createAdmin(credentials);
  assert.equal(admin.role, 'ADMIN');
  const grant = await service.login(credentials);
  assert.equal((await service.authenticate(grant.accessToken)).role, 'ADMIN');
  const stored = accounts.get(credentials.email);
  assert.ok(stored);
  stored.role = 'FARMER';
  assert.equal((await service.authenticate(grant.accessToken)).role, 'FARMER');
});

test('session expiry independently invalidates access even with a valid JWT', async () => {
  const tokens = createTokenService(testEnvironment, () => new Date());
  const { repository } = memoryRepository();
  const service = createAuthService(testEnvironment, repository);
  await service.register(credentials);
  const grant = await service.login(credentials);
  const id = await tokens.verify(grant.refreshToken, 'refresh');
  const session = await repository.findSession(id);
  assert.ok(session);
  session.expiresAt = new Date(0);
  await assert.rejects(service.authenticate(grant.accessToken), unauthorized);
});
