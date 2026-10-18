import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Router } from 'express';
import SwaggerParser from '@apidevtools/swagger-parser';
import { createApp } from '../../src/app.js';
import { generateOpenApi, registeredOperations } from '../../src/contracts/openapi.js';
import { responseContract } from '../../src/contracts/responses.js';
import { testEnvironment, silentLogger } from './helpers.js';
test('OpenAPI validates and covers each runtime method/path exactly once', async () => {
  const app = createApp(testEnvironment, silentLogger, { async checkDatabase() {} });
  const router = app.locals.contractRouter as Router,
    registered = registeredOperations(router),
    spec = generateOpenApi(router);
  await SwaggerParser.validate(JSON.parse(JSON.stringify(spec)), { resolve: { external: false } });
  assert.equal(registered.length, 61);
  assert.equal(
    Object.values(spec.paths).reduce((n, operations) => n + Object.keys(operations).length, 0),
    registered.length,
  );
  assert.equal(
    new Set(registered.map((row) => `${row.method} ${row.path}`)).size,
    registered.length,
  );
  for (const row of registered)
    assert.ok(spec.paths[row.path.replace(/:([A-Za-z]+)/g, '{$1}')]?.[row.method]);
  for (const path of ['/analytics/scans', '/analytics/scans/activity', '/profile', '/scans']) {
    const operation = spec.paths[path]?.get as Record<string, unknown>;
    assert.deepEqual(operation.security, [{ BearerAuth: [] }]);
    assert.deepEqual(operation['x-required-roles'], ['FARMER']);
  }
  const headerRequired = (path: string, method: string) => {
    const operation = spec.paths[path]?.[method] as {
      parameters: { name: string; required?: boolean }[];
    };
    return operation.parameters.some((p) => p.name === 'X-Auth-Request' && p.required);
  };
  assert.equal(headerRequired('/profile', 'get'), false);
  assert.equal(headerRequired('/profile/avatar', 'get'), true);
  assert.equal(headerRequired('/scans/{scanId}/explanation', 'post'), false);
  assert.equal(headerRequired('/auth/refresh', 'post'), true);
});
test('new routes cannot bypass runtime-schema documentation and public response validation', () => {
  const router = Router();
  router.get('/undocumented', (_req, res) => res.json({}));
  assert.throws(() => generateOpenApi(router), /lacks runtime request schema/);
  assert.throws(() => responseContract('get', '/undocumented'), /Missing response contract/);
  assert.equal(
    responseContract('get', '/profile')?.safeParse({ profile: { passwordHash: 'private' } })
      .success,
    false,
  );
});
