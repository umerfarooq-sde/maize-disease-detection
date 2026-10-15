import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import { hashPassword, verifyPassword } from '../../src/modules/auth/auth.password.js';

test('global password-work capacity bounds memory across callers and releases slots', async () => {
  const results = await Promise.allSettled(
    Array.from({ length: 8 }, () => hashPassword('long synthetic password for bounded work')),
  );
  const accepted = results.filter((row) => row.status === 'fulfilled');
  const denied = results.filter((row) => row.status === 'rejected');
  assert.equal(accepted.length, 4);
  assert.equal(denied.length, 4);
  for (const row of denied)
    assert.ok(row.reason instanceof AppError && row.reason.code === 'RATE_LIMITED');
  assert.equal(await verifyPassword(undefined, 'unknown account fixture'), false);
  const encoded = await hashPassword('long synthetic password for later work');
  assert.equal(encoded.split('$')[1], 'argon2id');
  assert.equal(encoded.split('$')[2], 'v=19');
  assert.deepEqual(new Set(encoded.split('$')[3]?.split(',')), new Set(['m=65536', 't=3', 'p=1']));
  assert.equal(await verifyPassword(encoded, 'long synthetic password for later work'), true);
});
