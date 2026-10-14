import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import { Prisma } from '../../src/generated/prisma/client.js';
import {
  createFertilizerService,
  publicFertilizerRule,
} from '../../src/modules/fertilizer/fertilizer.service.js';
import {
  FERTILIZER_CONFIG_KEY,
  FERTILIZER_ENGINE_VERSION,
  FERTILIZER_UNIT_REFERENCE,
} from '../../src/modules/fertilizer/fertilizer.types.js';
import { fertilizerDraftInputSchema } from '../../src/modules/fertilizer/fertilizer.validators.js';
import { draftInput, fertilizerInput, memoryFertilizer } from './helpers.js';

function rejects(code: string) {
  return (error: unknown) => error instanceof AppError && error.code === code;
}

test('empty approved catalogue reports pending recommendations without invented defaults', async () => {
  const setup = memoryFertilizer();
  setup.records.rules.length = 0;
  setup.records.configs.length = 0;
  const result = await createFertilizerService(setup.repository).listRules();
  assert.equal(result.status, 'PENDING_RULES');
  assert.equal(result.engineVersion, FERTILIZER_ENGINE_VERSION);
  assert.match(result.message, /pending/i);
  assert.deepEqual(result.items, []);
  assert.deepEqual(setup.reads, [{ operation: 'catalogue', configKey: FERTILIZER_CONFIG_KEY }]);
});

test('approved immutable rate scales exactly and returns provenance and explicit units once', async () => {
  const setup = memoryFertilizer();
  const service = createFertilizerService(setup.repository);
  const catalogue = await service.listRules();
  assert.equal(catalogue.status, 'READY');
  assert.equal(catalogue.items.length, 1);
  const input = fertilizerInput(setup.rule.id);
  const result = await service.calculate(input);
  assert.deepEqual(result.input, input);
  assert.deepEqual(result.quantity, { value: '15.000', unit: 'KG', unroundedValue: '15' });
  assert.deepEqual(result.normalizedArea, { value: '1.5', unit: 'HECTARE' });
  assert.deepEqual(result.rule, catalogue.items[0]);
  assert.deepEqual(result.rule.source, setup.draft.rule.source);
  assert.deepEqual(result.unitReference, FERTILIZER_UNIT_REFERENCE);
  assert.match(result.explanation, /multiplied/);
  const serialized = JSON.stringify(result);
  for (const field of [
    'approval',
    'reviewedBy',
    'parameters',
    'createdById',
    'fertilizerId',
    'productSnapshot',
  ]) {
    assert.ok(!serialized.includes(`"${field}"`));
  }
});

test('ACTIVE status alone cannot publish malformed, unreviewed, unsourced or incompatible JSON', async () => {
  for (const change of [
    (params: Prisma.JsonObject) => {
      delete params.approval;
    },
    (params: Prisma.JsonObject) => {
      params.approval = { status: 'UNREVIEWED' };
    },
    (params: Prisma.JsonObject) => {
      params.algorithm = 'AI_GUESSED_RATE';
    },
    (params: Prisma.JsonObject) => {
      params.crop = 'WHEAT';
    },
    (params: Prisma.JsonObject) => {
      params.rateKgPerHectare = '-1';
    },
    (params: Prisma.JsonObject) => {
      params.rateKgPerHectare = 10;
    },
    (params: Prisma.JsonObject) => {
      params.source = { url: 'https://example.invalid/no-citation' };
    },
    (params: Prisma.JsonObject) => {
      params.unrecognized = 'field';
    },
  ]) {
    const setup = memoryFertilizer();
    change(setup.rule.parameters as Prisma.JsonObject);
    const service = createFertilizerService(setup.repository);
    assert.equal((await service.listRules()).status, 'PENDING_RULES');
    await assert.rejects(
      service.calculate(fertilizerInput(setup.rule.id)),
      rejects('FERTILIZER_CONFIGURATION_INVALID'),
    );
  }
});

test('mutable product edits invalidate its immutable reviewed snapshot and public advice', async () => {
  for (const change of [
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.rule.fertilizer.name = 'Unreviewed changed name';
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.rule.fertilizer.description += ' Changed';
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.rule.fertilizer.precautions = ['Changed precautions'];
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.rule.fertilizer.nitrogenPercent = new Prisma.Decimal('1');
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.rule.fertilizer.sourceReference = 'https://example.invalid/changed';
    },
  ]) {
    const setup = memoryFertilizer();
    change(setup);
    const service = createFertilizerService(setup.repository);
    assert.deepEqual((await service.listRules()).items, []);
    await assert.rejects(
      service.calculate(fertilizerInput(setup.rule.id)),
      rejects('FERTILIZER_CONFIGURATION_INVALID'),
    );
  }
});

test('rule/config units, references and pinned version are prerequisites for public admission', async () => {
  for (const mutate of [
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.rule.unit = 'grams/acre';
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.config.unit = 'g';
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.config.configKey = 'other';
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.config.sourceReference = 'https://example.invalid/units';
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      setup.rule.sourceReference = 'https://example.invalid/changed-source';
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      (setup.rule.parameters as Prisma.JsonObject).configVersion = 2;
    },
    (setup: ReturnType<typeof memoryFertilizer>) => {
      (setup.config.parameters as Prisma.JsonObject).engineVersion = 'unsupported';
    },
  ]) {
    const setup = memoryFertilizer();
    mutate(setup);
    assert.equal(publicFertilizerRule(setup.rule, setup.config), null);
    await assert.rejects(
      createFertilizerService(setup.repository).calculate(fertilizerInput(setup.rule.id)),
      rejects('FERTILIZER_CONFIGURATION_INVALID'),
    );
  }
});

test('explicit stale/missing rule or configuration versions require catalogue reload', async () => {
  const setup = memoryFertilizer();
  const service = createFertilizerService(setup.repository);
  const input = fertilizerInput(setup.rule.id);
  for (const stale of [
    { ...input, ruleId: randomUUID() },
    { ...input, ruleVersion: 2 },
    { ...input, configVersion: 2 },
  ])
    await assert.rejects(service.calculate(stale), rejects('FERTILIZER_CONFIGURATION_CHANGED'));
  setup.config.status = 'INACTIVE';
  await assert.rejects(service.calculate(input), rejects('FERTILIZER_CONFIGURATION_CHANGED'));
});

test('draft review identity/time and technical config provenance are server-authored', async () => {
  const setup = memoryFertilizer();
  const actorId = randomUUID();
  const service = createFertilizerService(setup.repository, () => new Date('2026-10-14T12:30:00Z'));
  const draft = await service.createDraft(setup.draft, actorId, 'test-request-id');
  assert.equal(draft.status, 'DRAFT');
  const write = setup.writes[0];
  assert.ok(write);
  assert.equal(write.actorId, actorId);
  assert.equal(write.requestId, 'test-request-id');
  assert.deepEqual(write.input.rule.parameters.approval, {
    status: 'PROJECT_APPROVED_SOURCE',
    reviewedAt: '2026-10-14T12:30:00.000Z',
    reviewedBy: actorId,
    note: setup.draft.rule.reviewNote,
  });
  assert.deepEqual(write.input.rule.parameters.productSnapshot, setup.draft.product);
  assert.equal(write.input.rule.parameters.configVersion, setup.draft.config.version);
  assert.equal(write.input.rule.sourceReference, setup.draft.rule.source.url);
  assert.equal(write.input.config.sourceReference, FERTILIZER_UNIT_REFERENCE.url);
  assert.equal(write.input.config.parameters.engineVersion, FERTILIZER_ENGINE_VERSION);
});

test('draft/version conflicts and rejected publication return controlled errors', async () => {
  const setup = memoryFertilizer();
  const service = createFertilizerService(setup.repository);
  const actorId = randomUUID();
  setup.repository.createDraft = async () => null;
  await assert.rejects(service.createDraft(setup.draft, actorId, 'request'), rejects('CONFLICT'));
  await assert.rejects(
    service.changeStatus(randomUUID(), 'ACTIVE', actorId, 'request'),
    rejects('NOT_FOUND'),
  );
  (setup.rule.parameters as Prisma.JsonObject).approval = {};
  await assert.rejects(
    service.changeStatus(setup.rule.id, 'ACTIVE', actorId, 'request'),
    rejects('FERTILIZER_CONFIGURATION_INVALID'),
  );
  const result = await service.changeStatus(setup.rule.id, 'INACTIVE', actorId, 'request');
  assert.equal(result.status, 'INACTIVE');
  assert.deepEqual((await service.listRules()).items, []);
});

test('admin listing bounds output and cannot turn invalid historical drafts into usable rules', async () => {
  const setup = memoryFertilizer();
  setup.rule.status = 'DRAFT';
  const service = createFertilizerService(setup.repository);
  assert.equal((await service.listDrafts()).items[0]?.validForActivation, true);
  setup.rule.parameters = {};
  const result = await service.listDrafts();
  assert.equal(result.limit, 100);
  assert.equal(result.items[0]?.configVersion, null);
  assert.equal(result.items[0]?.validForActivation, false);
  assert.ok(!JSON.stringify(result).includes('parameters'));
});

test('admin draft validation rejects forged review fields, missing attribution and unknown arithmetic', () => {
  const valid = draftInput();
  const examples: unknown[] = [
    { ...valid, approval: { status: 'PROJECT_APPROVED_SOURCE' } },
    { ...valid, rule: { ...valid.rule, reviewedBy: randomUUID() } },
    { ...valid, rule: { ...valid.rule, algorithm: 'GEMINI' } },
    { ...valid, rule: { ...valid.rule, source: { ...valid.rule.source, citation: '' } } },
    {
      ...valid,
      rule: { ...valid.rule, source: { ...valid.rule.source, url: 'http://example.invalid' } },
    },
    { ...valid, rule: { ...valid.rule, reviewNote: 'ok' } },
    { ...valid, rule: { ...valid.rule, rateKgPerHectare: '-1' } },
    { ...valid, rule: { ...valid.rule, rateKgPerHectare: '1.0000001' } },
    { ...valid, product: { ...valid.product, nitrogenPercent: '-1' } },
    { ...valid, config: { ...valid.config, quantityDecimalPlaces: 7 } },
  ];
  for (const invalid of examples)
    assert.equal(fertilizerDraftInputSchema.safeParse(invalid).success, false);
  assert.equal(
    fertilizerDraftInputSchema.safeParse({
      ...valid,
      rule: { ...valid.rule, rateKgPerHectare: '0' },
    }).success,
    true,
  );
});
