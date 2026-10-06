import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { test } from 'node:test';
import { parseEnvironment } from '../../src/config/environment.js';
import { databaseConnectionUrl } from '../../src/database/connection-url.js';

const signingKeys = {
  JWT_SECRET: randomBytes(32).toString('base64url'),
  JWT_REFRESH_SECRET: randomBytes(32).toString('base64url'),
};
const database = { DATABASE_URL: 'postgresql://localhost/maizedoctor', ...signingKeys };

test('startup settings require a database and validate supplied operational settings', () => {
  assert.throws(() => parseEnvironment({}), /DATABASE_URL/);
  assert.equal(parseEnvironment(database).PORT, 3000);
  assert.equal(parseEnvironment(database).HOST, '127.0.0.1');
  assert.deepEqual(parseEnvironment(database).CORS_ORIGINS, []);
  for (const input of [
    { PORT: '0' },
    { PORT: 'abc' },
    { NODE_ENV: 'invalid' },
    { LOG_LEVEL: 'invalid' },
    { SHUTDOWN_TIMEOUT_MS: '0' },
    { HOST: 'bad host' },
  ]) {
    assert.throws(() => parseEnvironment({ ...database, ...input }));
  }
});

test('CORS requires exact origins and blank provider configuration disables uploads', () => {
  assert.deepEqual(
    parseEnvironment({
      ...database,
      CORS_ORIGINS: 'https://example.com, http://localhost:5173',
      CLOUDINARY_API_SECRET: '',
    }).CORS_ORIGINS,
    ['https://example.com', 'http://localhost:5173'],
  );
  for (const origin of [
    '*',
    'https://example.com/path',
    'https://user:secret@example.com',
    'https://example.com/',
  ]) {
    assert.throws(() => parseEnvironment({ ...database, CORS_ORIGINS: origin }));
  }
});

test('Cloudinary credentials must be complete and errors never echo provider secrets', () => {
  assert.equal(parseEnvironment(database).CLOUDINARY_CLOUD_NAME, '');
  const credentials = {
    CLOUDINARY_CLOUD_NAME: 'test-cloud',
    CLOUDINARY_API_KEY: '123456',
    CLOUDINARY_API_SECRET: 'synthetic-private-key',
  };
  assert.equal(
    parseEnvironment({ ...database, ...credentials }).CLOUDINARY_CLOUD_NAME,
    'test-cloud',
  );
  assert.throws(
    () =>
      parseEnvironment({ ...database, CLOUDINARY_API_SECRET: credentials.CLOUDINARY_API_SECRET }),
    (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.ok(error.message.includes('CLOUDINARY'));
      assert.ok(!error.message.includes(credentials.CLOUDINARY_API_SECRET));
      return true;
    },
  );
});

test('invalid configuration never echoes connection secrets', () => {
  for (const DATABASE_URL of [
    'http://user:sensitive-password@example.com/db',
    'postgresql://user:sensitive-password@example.com/',
  ]) {
    assert.throws(
      () => parseEnvironment({ DATABASE_URL, ...signingKeys }),
      (error: unknown) => {
        assert.ok(error instanceof Error);
        assert.ok(error.message.includes('DATABASE_URL'));
        assert.ok(!error.message.includes('sensitive-password'));
        return true;
      },
    );
  }
});

test('PostgreSQL URL normalization preserves verified TLS and explicit compatibility', () => {
  assert.equal(
    databaseConnectionUrl(`${database.DATABASE_URL}?sslmode=require`).searchParams.get('sslmode'),
    'verify-full',
  );
  assert.equal(
    databaseConnectionUrl(
      `${database.DATABASE_URL}?sslmode=require&uselibpqcompat=true`,
    ).searchParams.get('sslmode'),
    'require',
  );
});

test('JWT keys are required, independent and strong-format; TTLs are bounded', () => {
  for (const changes of [
    { JWT_SECRET: '' },
    { JWT_REFRESH_SECRET: '' },
    { JWT_SECRET: 'short' },
    { JWT_REFRESH_SECRET: signingKeys.JWT_SECRET },
    { JWT_ACCESS_TTL_SECONDS: '3600' },
    { JWT_REFRESH_TTL_SECONDS: '999999999' },
  ]) {
    assert.throws(
      () => parseEnvironment({ ...database, ...changes }),
      (error: unknown) => {
        assert.ok(error instanceof Error);
        assert.ok(!error.message.includes(signingKeys.JWT_SECRET));
        assert.ok(!error.message.includes(signingKeys.JWT_REFRESH_SECRET));
        return true;
      },
    );
  }
});
