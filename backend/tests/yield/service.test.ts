import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import {
  createYieldService,
  publicYieldConfiguration,
} from '../../src/modules/yield/yield.service.js';
import { yieldParametersSchema } from '../../src/modules/yield/yield.types.js';
import { draft, input, memoryYield } from './helpers.js';

const fails = (code: string) => (error: unknown) =>
  error instanceof AppError && error.code === code;
test('empty or incompatible approved yield catalogue remains explicitly pending', async () => {
  const memory = memoryYield();
  memory.records.length = 0;
  const service = createYieldService(memory.repository);
  assert.deepEqual((await service.list()).items, []);
  assert.equal((await service.list()).status, 'PENDING_CONFIGURATION');
  await assert.rejects(
    service.calculate(input(randomUUID())),
    fails('YIELD_CONFIGURATION_CHANGED'),
  );
});
test('legacy, wrong-kind/unit/source and unreviewed or unknown yield parameters are never published', () => {
  const memory = memoryYield();
  assert.ok(publicYieldConfiguration(memory.record));
  const parameters = yieldParametersSchema.parse(memory.record.parameters);
  for (const change of [
    { algorithm: 'UNREVIEWED_FORMULA' },
    { formulaVersion: 'unknown' },
    { engineVersion: 'unknown' },
    { crop: 'RICE' },
    { approval: null },
    { expectedYieldKgPerHectare: '-1' },
    { roundingMode: 'FLOOR' },
  ]) {
    assert.equal(
      publicYieldConfiguration({ ...memory.record, parameters: { ...parameters, ...change } }),
      null,
    );
  }
  for (const change of [
    { parameters: {} },
    { unit: 't/acre' },
    { kind: 'FERTILIZER' as const },
    { configKey: 'other' },
    { sourceReference: 'https://example.invalid/changed' },
    { status: 'DRAFT' as const },
  ])
    assert.equal(publicYieldConfiguration({ ...memory.record, ...change }), null);
});
test('inactive, absent or stale versions cannot calculate; malformed ACTIVE data fails safely', async () => {
  const memory = memoryYield();
  const service = createYieldService(memory.repository);
  await assert.rejects(
    service.calculate(input(memory.record.id, { configVersion: 2 })),
    fails('YIELD_CONFIGURATION_CHANGED'),
  );
  memory.record.status = 'INACTIVE';
  await assert.rejects(
    service.calculate(input(memory.record.id)),
    fails('YIELD_CONFIGURATION_CHANGED'),
  );
  memory.record.status = 'ACTIVE';
  memory.record.parameters = {};
  await assert.rejects(
    service.calculate(input(memory.record.id)),
    fails('YIELD_CONFIGURATION_INVALID'),
  );
});
test('draft review identity/time and fixed formula are server-owned; versions are immutable', async () => {
  const memory = memoryYield();
  const now = new Date('2026-10-15T01:02:03Z');
  const service = createYieldService(memory.repository, () => now);
  const actorId = randomUUID();
  const created = await service.createDraft({ ...draft(), version: 2 }, actorId, 'fixture-request');
  assert.equal(created.status, 'DRAFT');
  assert.equal(created.validForActivation, true);
  const saved = memory.records.find((record) => record.id === created.id);
  assert.ok(
    saved &&
      typeof saved.parameters === 'object' &&
      saved.parameters !== null &&
      !Array.isArray(saved.parameters),
  );
  assert.deepEqual(saved.parameters.approval, {
    status: 'PROJECT_APPROVED_SOURCE',
    reviewedAt: now.toISOString(),
    reviewedBy: actorId,
    note: draft().reviewNote,
  });
  assert.equal(saved.parameters.formulaVersion, 'area-times-reviewed-yield-rate-v1');
  await assert.rejects(
    service.createDraft({ ...draft(), version: 2 }, actorId, 'fixture-request'),
    fails('CONFLICT'),
  );
  await service.changeStatus(created.id, 'ACTIVE', actorId, 'fixture-request');
  assert.equal(memory.record.status, 'INACTIVE');
  assert.equal((await service.list()).items[0]?.version, 2);
  await assert.rejects(
    service.calculate(input(memory.record.id)),
    fails('YIELD_CONFIGURATION_CHANGED'),
  );
  await service.changeStatus(created.id, 'INACTIVE', actorId, 'fixture-request');
  assert.equal((await service.list()).status, 'PENDING_CONFIGURATION');
});
test('incompatible draft activation and absent management target return safe application errors', async () => {
  const memory = memoryYield();
  const service = createYieldService(memory.repository);
  memory.record.parameters = {};
  await assert.rejects(
    service.changeStatus(memory.record.id, 'ACTIVE', randomUUID(), 'fixture'),
    fails('YIELD_CONFIGURATION_INVALID'),
  );
  await assert.rejects(
    service.changeStatus(randomUUID(), 'ACTIVE', randomUUID(), 'fixture'),
    fails('NOT_FOUND'),
  );
});
