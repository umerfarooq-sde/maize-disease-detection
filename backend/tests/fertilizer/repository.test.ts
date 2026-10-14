import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  createFertilizerRepository,
  type FertilizerDatabase,
} from '../../src/modules/fertilizer/fertilizer.repository.js';

test('catalogue and calculations read only active products/rules/configs in one repeatable snapshot', async () => {
  const calls: { operation: string; args: unknown }[] = [];
  const transaction = {
    fertilizerRule: {
      async findMany(args: unknown) {
        calls.push({ operation: 'rules', args });
        return [];
      },
    },
    calculatorConfig: {
      async findMany(args: unknown) {
        calls.push({ operation: 'configs', args });
        return [];
      },
    },
  };
  const database = {
    async $transaction(
      callback: (fixture: typeof transaction) => Promise<unknown>,
      options: unknown,
    ) {
      calls.push({ operation: 'snapshot', args: options });
      return callback(transaction);
    },
  } as unknown as FertilizerDatabase;
  const repository = createFertilizerRepository(database);
  assert.deepEqual(await repository.catalogue('area-rate-v1'), { rules: [], configs: [] });
  assert.deepEqual(calls[0], {
    operation: 'snapshot',
    args: { isolationLevel: 'RepeatableRead' },
  });
  assert.deepEqual(calls[1], {
    operation: 'rules',
    args: {
      where: { status: 'ACTIVE', fertilizer: { status: 'ACTIVE' } },
      include: { fertilizer: true },
      orderBy: [{ fertilizerId: 'asc' }, { ruleKey: 'asc' }, { version: 'desc' }],
      take: 100,
    },
  });
  assert.deepEqual(calls[2], {
    operation: 'configs',
    args: {
      where: { kind: 'FERTILIZER', configKey: 'area-rate-v1', status: 'ACTIVE' },
      orderBy: { version: 'desc' },
    },
  });
  calls.length = 0;
  await repository.calculation('00000000-0000-4000-8000-000000000001', 'area-rate-v1');
  const ruleCall = calls[1];
  assert.ok(ruleCall);
  assert.deepEqual((ruleCall.args as { where: unknown }).where, {
    id: '00000000-0000-4000-8000-000000000001',
    status: 'ACTIVE',
    fertilizer: { status: 'ACTIVE' },
  });
});
