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

test('AI integration defaults disabled and requires explicit origin, token and expected versions', () => {
  const disabled = parseEnvironment(database);
  assert.equal(disabled.AI_SERVICE_URL, '');
  assert.equal(disabled.AI_SERVICE_TOKEN, '');
  assert.equal(disabled.AI_MODEL_VERSION, '');
  assert.equal(disabled.AI_PREPROCESSING_VERSION, '');
  assert.equal(disabled.AI_SERVICE_TIMEOUT_MS, 10000);
  const ai = {
    AI_SERVICE_URL: 'http://ai-service:8000/',
    AI_SERVICE_TOKEN: randomBytes(32).toString('base64url'),
    AI_MODEL_VERSION: 'synthetic-model-v1',
    AI_PREPROCESSING_VERSION: '1.0.0',
  };
  assert.equal(parseEnvironment({ ...database, ...ai }).AI_SERVICE_URL, 'http://ai-service:8000');
  assert.equal(
    parseEnvironment({ ...database, ...ai, NODE_ENV: 'production' }).AI_SERVICE_URL,
    'http://ai-service:8000',
  );
  for (const partial of [
    { AI_SERVICE_URL: ai.AI_SERVICE_URL },
    { AI_SERVICE_TOKEN: ai.AI_SERVICE_TOKEN },
    { AI_MODEL_VERSION: ai.AI_MODEL_VERSION },
    { AI_PREPROCESSING_VERSION: ai.AI_PREPROCESSING_VERSION },
    { ...ai, AI_MODEL_VERSION: '' },
    { ...ai, AI_PREPROCESSING_VERSION: '' },
    { ...ai, AI_SERVICE_TOKEN: '' },
  ]) {
    assert.throws(() => parseEnvironment({ ...database, ...partial }), /AI_SERVICE/);
  }
});

test('AI origins, token format and deadlines are bounded without leaking service secrets', () => {
  const ai = {
    AI_SERVICE_URL: 'https://private-ai.example',
    AI_SERVICE_TOKEN: randomBytes(32).toString('base64url'),
    AI_MODEL_VERSION: 'synthetic-model-v1',
    AI_PREPROCESSING_VERSION: '1.0.0',
  };
  for (const changes of [
    { AI_SERVICE_URL: 'ftp://private-ai.example' },
    { AI_SERVICE_URL: 'https://user:private-service-secret@private-ai.example' },
    { AI_SERVICE_URL: 'https://private-ai.example/path' },
    { AI_SERVICE_URL: 'https://private-ai.example?secret=private-service-secret' },
    { AI_SERVICE_URL: 'https://private-ai.example#fragment' },
    { AI_SERVICE_URL: ' https://private-ai.example' },
    { AI_SERVICE_URL: 'https://private-ai.example/' + '../' },
    { AI_SERVICE_TOKEN: 'weak-private-service-secret' },
    { AI_SERVICE_TOKEN: `${randomBytes(32).toString('base64url')}=` },
    { AI_SERVICE_TOKEN: randomBytes(200).toString('base64url') },
    { AI_MODEL_VERSION: 'model\nprivate-service-secret' },
    { AI_MODEL_VERSION: 'm'.repeat(81) },
    { AI_PREPROCESSING_VERSION: 'p'.repeat(121) },
    { AI_SERVICE_TIMEOUT_MS: '999' },
    { AI_SERVICE_TIMEOUT_MS: '20001' },
    { AI_SERVICE_TIMEOUT_MS: 'Infinity' },
    { AI_SERVICE_TIMEOUT_MS: '1000.5' },
  ]) {
    assert.throws(
      () => parseEnvironment({ ...database, ...ai, ...changes }),
      (error: unknown) => {
        assert.ok(error instanceof Error);
        assert.ok(!error.message.includes('private-service-secret'));
        assert.ok(!error.message.includes(ai.AI_SERVICE_TOKEN));
        return true;
      },
    );
  }
});
