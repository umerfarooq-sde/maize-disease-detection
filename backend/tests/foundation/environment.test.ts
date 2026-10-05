import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseEnvironment } from '../../src/config/environment.js';
import { databaseConnectionUrl } from '../../src/database/connection-url.js';

const database = { DATABASE_URL: 'postgresql://localhost/maizedoctor' };

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

test('CORS requires exact origins and future feature secrets are not required', () => {
  assert.deepEqual(
    parseEnvironment({
      ...database,
      CORS_ORIGINS: 'https://example.com, http://localhost:5173',
      JWT_SECRET: '',
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

test('invalid configuration never echoes connection secrets', () => {
  for (const DATABASE_URL of [
    'http://user:sensitive-password@example.com/db',
    'postgresql://user:sensitive-password@example.com/',
  ]) {
    assert.throws(
      () => parseEnvironment({ DATABASE_URL }),
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
