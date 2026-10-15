import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createHealthRepository } from '../../src/modules/health/health.repository.js';

test('production database admission rejects privileged/owning/DDL roles and malformed evidence', async () => {
  const safe = { privileged: false, owns_objects: false, can_create: false };
  for (const evidence of [
    [safe],
    [{ ...safe, privileged: true }],
    [{ ...safe, owns_objects: true }],
    [{ ...safe, can_create: true }],
    [],
  ]) {
    const repository = createHealthRepository(
      {
        async $queryRaw(query) {
          return query.join('').includes('pg_catalog') ? evidence : [{ value: 1 }];
        },
      },
      true,
    );
    if (evidence.length === 1 && evidence[0] === safe) await repository.checkDatabase();
    else await assert.rejects(repository.checkDatabase(), /privileges are unsafe/);
  }
});
