import assert from 'node:assert/strict';
import { Writable } from 'node:stream';
import { test } from 'node:test';
import express from 'express';
import { pino } from 'pino';
import { z } from 'zod';
import { createApp } from '../../src/app.js';
import { AppError, type ErrorCode } from '../../src/errors/app-error.js';
import { errorHandler } from '../../src/middleware/error-handler.js';
import { requestContext } from '../../src/middleware/request-context.js';
import type { HealthStatus } from '../../src/modules/health/health.service.js';
import type { ErrorResponse, SuccessResponse } from '../../src/types/api.js';
import { sendSuccess } from '../../src/utils/respond.js';
import { validateRequest } from '../../src/validators/request.js';
import { silentLogger, testEnvironment, withServer } from './helpers.js';

const healthy = { async checkDatabase() {} };

test('versioned health follows repository checks and returns one safe envelope', async () => {
  let calls = 0;
  const app = createApp(testEnvironment, silentLogger, {
    async checkDatabase() {
      calls++;
    },
  });
  await withServer(app, async (url) => {
    const response = await fetch(`${url}/api/v1/health`);
    const body = (await response.json()) as SuccessResponse<HealthStatus>;
    assert.equal(response.status, 200);
    assert.equal(body.success, true);
    assert.equal(body.data.status, 'ok');
    assert.equal(body.data.checks.database, 'up');
    assert.equal(body.data.service, 'maizedoctor-backend');
    assert.ok(Number.isFinite(Date.parse(body.data.timestamp)));
    assert.ok(body.data.uptimeSeconds >= 0);
    assert.equal(body.requestId, response.headers.get('x-request-id'));
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(response.headers.get('x-powered-by'), null);
    assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(calls, 1);
  });
});

test('database outage reports degraded health without dependency details', async () => {
  const app = createApp(testEnvironment, silentLogger, {
    async checkDatabase() {
      throw new Error('postgresql://user:sensitive-password@host/db');
    },
  });
  await withServer(app, async (url) => {
    const response = await fetch(`${url}/api/v1/health`);
    const text = await response.text();
    const body = JSON.parse(text) as SuccessResponse<HealthStatus>;
    assert.equal(response.status, 503);
    assert.equal(body.data.status, 'degraded');
    assert.equal(body.data.checks.database, 'down');
    assert.ok(!text.includes('sensitive-password'));
  });
});

test('unknown routes and methods use the error contract; unversioned health does not exist', async () => {
  await withServer(createApp(testEnvironment, silentLogger, healthy), async (url) => {
    for (const [path, method] of [
      ['/health', 'GET'],
      ['/api/v1/missing', 'GET'],
      ['/api/v1/health', 'POST'],
    ] as const) {
      const response = await fetch(`${url}${path}`, { method });
      const body = (await response.json()) as ErrorResponse;
      assert.equal(response.status, 404);
      assert.equal(body.success, false);
      assert.equal(body.error.code, 'NOT_FOUND');
      assert.equal(body.requestId, response.headers.get('x-request-id'));
    }
  });
});

test('health rejects unexpected query values through Zod', async () => {
  await withServer(createApp(testEnvironment, silentLogger, healthy), async (url) => {
    const response = await fetch(`${url}/api/v1/health?unexpected=value`);
    const body = (await response.json()) as ErrorResponse;
    assert.equal(response.status, 400);
    assert.equal(body.error.code, 'VALIDATION_ERROR');
    assert.deepEqual(body.error.details, [{ path: 'query', code: 'unrecognized_keys' }]);
  });
});

test('rate limiting protects repository work and returns the standard 429 envelope', async () => {
  let calls = 0;
  const app = createApp({ ...testEnvironment, RATE_LIMIT_MAX: 1 }, silentLogger, {
    async checkDatabase() {
      calls++;
    },
  });
  await withServer(app, async (url) => {
    await (await fetch(`${url}/api/v1/health`)).text();
    const limited = await fetch(`${url}/api/v1/health`);
    assert.equal(limited.status, 429);
    assert.equal(((await limited.json()) as ErrorResponse).error.code, 'RATE_LIMITED');
    assert.ok(limited.headers.has('retry-after'));
    assert.equal(calls, 1);
  });
});

test('CORS enforces exact allowlists, rejects wildcard defaults and supports preflight', async () => {
  const origin = 'https://example.com';
  await withServer(
    createApp({ ...testEnvironment, CORS_ORIGINS: [origin] }, silentLogger, healthy),
    async (url) => {
      const allowed = await fetch(`${url}/api/v1/health`, { headers: { Origin: origin } });
      assert.equal(allowed.headers.get('access-control-allow-origin'), origin);
      assert.equal(allowed.headers.get('access-control-allow-credentials'), null);
      const preflight = await fetch(`${url}/api/v1/health`, {
        method: 'OPTIONS',
        headers: { Origin: origin, 'Access-Control-Request-Method': 'GET' },
      });
      assert.equal(preflight.status, 204);
      const denied = await fetch(`${url}/api/v1/health`, {
        headers: { Origin: 'https://untrusted.example' },
      });
      assert.equal(denied.status, 403);
      assert.equal(denied.headers.get('access-control-allow-origin'), null);
      assert.equal(((await denied.json()) as ErrorResponse).error.code, 'AUTHORIZATION_ERROR');
    },
  );
  await withServer(createApp(testEnvironment, silentLogger, healthy), async (url) => {
    assert.equal(
      (await fetch(`${url}/api/v1/health`, { headers: { Origin: origin } })).status,
      403,
    );
  });
});

test('malformed, oversized and encoded JSON receive safe structured errors', async () => {
  await withServer(createApp(testEnvironment, silentLogger, healthy), async (url) => {
    for (const fixture of [
      {
        body: '{"secret":"sensitive-password"',
        headers: {},
        status: 400,
        code: 'VALIDATION_ERROR',
      },
      {
        body: JSON.stringify({ value: 'x'.repeat(110000) }),
        headers: {},
        status: 413,
        code: 'PAYLOAD_TOO_LARGE',
      },
      {
        body: '{}',
        headers: { 'Content-Encoding': 'gzip' },
        status: 415,
        code: 'UNSUPPORTED_MEDIA_TYPE',
      },
    ]) {
      const response = await fetch(`${url}/api/v1/health`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...fixture.headers },
        body: fixture.body,
      });
      const text = await response.text();
      assert.equal(response.status, fixture.status);
      assert.equal((JSON.parse(text) as ErrorResponse).error.code, fixture.code);
      assert.ok(!text.includes('sensitive-password'));
      assert.ok(!text.includes('stack'));
    }
  });
});

test('central handler supports application errors and hides rejected async error details', async () => {
  const app = express();
  app.use(requestContext(silentLogger));
  const statuses: [ErrorCode, number][] = [
    ['VALIDATION_ERROR', 400],
    ['AUTHENTICATION_ERROR', 401],
    ['AUTHORIZATION_ERROR', 403],
    ['NOT_FOUND', 404],
    ['CONFLICT', 409],
    ['INTERNAL_SERVER_ERROR', 500],
  ];
  for (const [code] of statuses)
    app.get(`/${code}`, () => {
      throw new AppError(code);
    });
  app.get('/unexpected', async () => {
    throw new Error('private connection sensitive-password');
  });
  app.get('/internal-details', () => {
    throw new AppError('INTERNAL_SERVER_ERROR', [{ path: 'sensitive-password', code: 'private' }]);
  });
  app.use(errorHandler(silentLogger));
  await withServer(app, async (url) => {
    for (const [code, status] of statuses) {
      const response = await fetch(`${url}/${code}`);
      assert.equal(response.status, status);
      assert.equal(((await response.json()) as ErrorResponse).error.code, code);
    }
    const response = await fetch(`${url}/unexpected`);
    assert.equal(response.status, 500);
    const text = await response.text();
    assert.ok(!text.includes('sensitive-password'));
    assert.ok(!text.includes('stack'));
    const internal = await fetch(`${url}/internal-details`);
    assert.ok(!(await internal.text()).includes('sensitive-password'));
  });
});

test('validation supports body, params and query with coercion and safe issue codes', async () => {
  const schema = z.object({
    body: z.object({ count: z.coerce.number().int().positive() }).strict(),
    params: z.object({ id: z.uuid() }),
    query: z.object({ page: z.coerce.number().int().positive() }).strict(),
  });
  const app = express();
  app.use(requestContext(silentLogger), express.json());
  app.post('/fixture/:id', validateRequest(schema), (_request, response) =>
    sendSuccess(response, response.locals.validated),
  );
  app.use(errorHandler(silentLogger));
  await withServer(app, async (url) => {
    const valid = await fetch(`${url}/fixture/00000000-0000-4000-8000-000000000001?page=2`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{"count":"3"}',
    });
    assert.equal(valid.status, 200);
    const body = (await valid.json()) as SuccessResponse<z.infer<typeof schema>>;
    assert.equal(body.data.body.count, 3);
    assert.equal(body.data.query.page, 2);
    const invalid = await fetch(`${url}/fixture/invalid?page=0`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{"count":-1}',
    });
    assert.equal(invalid.status, 400);
    const failure = (await invalid.json()) as ErrorResponse;
    assert.deepEqual(
      failure.error.details?.map((issue) => issue.path),
      ['body.count', 'params.id', 'query.page'],
    );
  });
});

test('request logs omit secrets, client correlation headers and untrusted URL values', async () => {
  let logs = '';
  const logger = pino(
    { level: 'info' },
    new Writable({
      write(chunk: Buffer, _encoding, done) {
        logs += chunk.toString();
        done();
      },
    }),
  );
  await withServer(createApp(testEnvironment, logger, healthy), async (url) => {
    const response = await fetch(`${url}/api/v1/health?token=query-secret`, {
      headers: {
        Authorization: 'Bearer header-secret',
        Cookie: 'session=cookie-secret',
        'X-Request-Id': 'untrusted-id',
      },
    });
    assert.notEqual(response.headers.get('x-request-id'), 'untrusted-id');
    await response.text();
    assert.ok(logs.includes('Request completed'));
    for (const secret of ['query-secret', 'header-secret', 'cookie-secret', 'untrusted-id'])
      assert.ok(!logs.includes(secret));
  });
});
