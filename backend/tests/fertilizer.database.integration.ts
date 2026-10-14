import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { createDatabaseClient } from '../src/database/client.js';
import {
  createFertilizerRepository,
  type FertilizerDatabase,
} from '../src/modules/fertilizer/fertilizer.repository.js';
import { assertSqlRejects, rollbackFixture } from './database-support.js';

test('PostgreSQL fertilizer snapshots, immutable versions and active-version uniqueness', {
  timeout: 120000,
}, async (context) => {
  const database = createDatabaseClient();
  const before = await Promise.all([
    database.fertilizer.count(),
    database.fertilizerRule.count(),
    database.calculatorConfig.count(),
  ]);
  try {
    await assert.rejects(
      database.$transaction(
        async (transaction) => {
          const marker = randomUUID();
          const product = await transaction.fertilizer.create({
            data: {
              slug: `synthetic-phase17-${marker}`,
              name: 'SYNTHETIC TEST PRODUCT; NOT AGRONOMIC ADVICE',
              description: 'Rollback-only isolated integration fixture.',
              nitrogenPercent: '0',
              phosphorusPercent: '0',
              potassiumPercent: '0',
              sourceReference: 'TEST FIXTURE ONLY; not an approved recommendation.',
              status: 'ACTIVE',
            },
          });
          const rule = await transaction.fertilizerRule.create({
            data: {
              fertilizerId: product.id,
              ruleKey: marker,
              version: 1,
              parameters: { synthetic: true },
              unit: 'kg/ha',
              sourceReference: 'TEST FIXTURE ONLY',
              status: 'ACTIVE',
            },
          });
          const config = await transaction.calculatorConfig.create({
            data: {
              kind: 'FERTILIZER',
              configKey: marker,
              version: 1,
              parameters: { synthetic: true },
              unit: 'kg',
              sourceReference: 'TEST FIXTURE ONLY',
              status: 'ACTIVE',
            },
          });
          const repository = createFertilizerRepository({
            ...transaction,
            $transaction: async (operation: (tx: typeof transaction) => Promise<unknown>) =>
              operation(transaction),
          } as unknown as FertilizerDatabase);
          await context.test(
            'one snapshot returns the precise active rule and configuration',
            async () => {
              const snapshot = await repository.calculation(rule.id, marker);
              assert.equal(snapshot.rules.length, 1);
              assert.equal(snapshot.rules[0]?.version, 1);
              assert.equal(snapshot.configs[0]?.version, 1);
              assert.equal(snapshot.rules[0]?.fertilizer.id, product.id);
            },
          );
          await context.test('rule/config payloads cannot be edited in place', async () => {
            await assertSqlRejects(
              transaction,
              'UPDATE fertilizer_rules SET parameters = \'{"synthetic":false}\'::jsonb WHERE id=$1::uuid',
              [rule.id],
              '23514',
            );
            await assertSqlRejects(
              transaction,
              'UPDATE calculator_configs SET parameters = \'{"synthetic":false}\'::jsonb WHERE id=$1::uuid',
              [config.id],
              '23514',
            );
          });
          await context.test(
            'one-active indexes reject a competing active rule/config version',
            async () => {
              await assertSqlRejects(
                transaction,
                `INSERT INTO fertilizer_rules
              (fertilizer_id,rule_key,version,parameters,unit,source_reference,status)
              VALUES ($1::uuid,$2,2,'{}','kg/ha','TEST FIXTURE ONLY','ACTIVE')`,
                [product.id, marker],
                '23505',
              );
              await assertSqlRejects(
                transaction,
                `INSERT INTO calculator_configs
              (kind,config_key,version,parameters,unit,source_reference,status)
              VALUES ('FERTILIZER',$1,2,'{}','kg','TEST FIXTURE ONLY','ACTIVE')`,
                [marker],
                '23505',
              );
            },
          );
          await context.test(
            'inactive rules and products cease to be public candidates',
            async () => {
              await transaction.fertilizerRule.update({
                where: { id: rule.id },
                data: { status: 'INACTIVE' },
              });
              assert.equal((await repository.calculation(rule.id, marker)).rules.length, 0);
              await transaction.fertilizerRule.update({
                where: { id: rule.id },
                data: { status: 'ACTIVE' },
              });
              await transaction.fertilizer.update({
                where: { id: product.id },
                data: { status: 'INACTIVE' },
              });
              assert.equal((await repository.calculation(rule.id, marker)).rules.length, 0);
            },
          );
          throw rollbackFixture;
        },
        { maxWait: 10000, timeout: 90000, isolationLevel: 'RepeatableRead' },
      ),
      (error: unknown) => error === rollbackFixture,
    );
    assert.deepEqual(
      await Promise.all([
        database.fertilizer.count(),
        database.fertilizerRule.count(),
        database.calculatorConfig.count(),
      ]),
      before,
    );
  } finally {
    await database.$disconnect();
  }
});
