import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { flutterTestEnvironment } from './flutter-test-environment.mjs';

test('frontend subprocess sees only SDK essentials and explicit disposable fixture values', () => {
  const secretNames = [
    'DATABASE_URL',
    'DIRECT_DATABASE_URL',
    'JWT_SECRET',
    'JWT_REFRESH_SECRET',
    'GEMINI_API_KEY',
    'CLOUDINARY_API_KEY',
    'CLOUDINARY_API_SECRET',
    'AI_SERVICE_TOKEN',
    'PGPASSWORD',
    'DATASET_PATH',
    'NODE_OPTIONS',
    'PYTHONPATH',
    'DART_VM_OPTIONS',
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'SSLKEYLOGFILE',
    'google_application_credentials',
  ];
  const source = Object.fromEntries(secretNames.map((name) => [name, 'private-fixture-sentinel']));
  Object.assign(source, {
    Path: process.env.PATH,
    SYSTEMROOT: process.env.SYSTEMROOT,
    HOME: 'sdk-home',
  });
  const environment = flutterTestEnvironment(source);
  assert.equal(environment.Path, process.env.PATH);
  assert.equal(environment.HOME, 'sdk-home');
  for (const name of secretNames) assert.equal(environment[name], undefined);
  const child = spawnSync(
    process.execPath,
    ['-e', 'process.stdout.write(JSON.stringify(process.env))'],
    {
      env: { ...environment, DISPOSABLE_FIXTURE: 'only-this-test' },
      encoding: 'utf8',
      windowsHide: true,
    },
  );
  assert.equal(child.status, 0);
  const observed = JSON.parse(child.stdout);
  assert.equal(observed.DISPOSABLE_FIXTURE, 'only-this-test');
  assert.ok(!child.stdout.includes('private-fixture-sentinel'));
  for (const name of secretNames) assert.equal(observed[name], undefined);
});

test('legacy Flutter runners use the reviewed allowlist rather than inheriting the server env', () => {
  for (const name of ['check-scan-upload.mjs', 'check-model-health.mjs']) {
    const source = readFileSync(new URL(name, import.meta.url), 'utf8');
    assert.ok(source.includes('flutterTestEnvironment()'), name);
    assert.ok(!source.includes('...process.env'), name);
  }
});
