import { randomUUID } from 'node:crypto';
import { Prisma } from '../../src/generated/prisma/client.js';
import type {
  FertilizerConfigRecord,
  FertilizerDraftWrite,
  FertilizerRepository,
  FertilizerRuleRecord,
} from '../../src/modules/fertilizer/fertilizer.repository.js';
import {
  FERTILIZER_CONFIG_KEY,
  FERTILIZER_ENGINE_VERSION,
  FERTILIZER_UNIT_REFERENCE,
  type CalculatorInput,
} from '../../src/modules/fertilizer/fertilizer.types.js';
import {
  fertilizerDraftInputSchema,
  type FertilizerDraftInput,
} from '../../src/modules/fertilizer/fertilizer.validators.js';

// Deliberately synthetic in-memory fixtures. They are never a recommendation seed.
export function draftInput(): FertilizerDraftInput {
  return fertilizerDraftInputSchema.parse({
    product: {
      slug: 'synthetic-test-product',
      name: 'Synthetic test product',
      description: 'Synthetic arithmetic fixture; not agricultural advice.',
      nitrogenPercent: '0',
      phosphorusPercent: '0',
      potassiumPercent: '0',
      applicationMethod: null,
      precautions: [],
      sourceReference: 'https://example.invalid/synthetic-product',
    },
    rule: {
      ruleKey: 'synthetic-test-rule',
      version: 1,
      title: 'Synthetic test rule',
      rateKgPerHectare: '10',
      applicability: 'Synthetic testing only; no field applicability.',
      assumptions: ['Synthetic arithmetic fixture; not a fertilizer recommendation.'],
      source: {
        title: 'Synthetic source fixture',
        publisher: 'Synthetic test publisher',
        url: 'https://example.invalid/synthetic-rule',
        citation: 'Test fixture only; not an authoritative dosage source.',
      },
      reviewNote: 'Synthetic isolated review fixture; no agronomic approval is implied.',
    },
    config: { version: 1, quantityDecimalPlaces: 3 },
  });
}

export function memoryFertilizer() {
  const draft = draftInput();
  const productId = randomUUID();
  const dates = {
    createdAt: new Date('2026-10-14T00:00:00Z'),
    updatedAt: new Date('2026-10-14T00:00:00Z'),
  };
  const rule: FertilizerRuleRecord = {
    id: randomUUID(),
    fertilizerId: productId,
    ruleKey: draft.rule.ruleKey,
    version: 1,
    growthStage: null,
    unit: 'kg/ha',
    sourceReference: draft.rule.source.url,
    status: 'ACTIVE',
    ...dates,
    parameters: {
      algorithm: 'AREA_RATE_V1',
      crop: 'MAIZE',
      configVersion: 1,
      title: draft.rule.title,
      rateKgPerHectare: draft.rule.rateKgPerHectare,
      applicability: draft.rule.applicability,
      assumptions: draft.rule.assumptions,
      source: draft.rule.source,
      productSnapshot: draft.product,
      approval: {
        status: 'PROJECT_APPROVED_SOURCE',
        reviewedAt: dates.createdAt.toISOString(),
        reviewedBy: randomUUID(),
        note: draft.rule.reviewNote,
      },
    },
    fertilizer: {
      ...draft.product,
      id: productId,
      status: 'ACTIVE',
      ...dates,
      nitrogenPercent: new Prisma.Decimal(draft.product.nitrogenPercent),
      phosphorusPercent: new Prisma.Decimal(draft.product.phosphorusPercent),
      potassiumPercent: new Prisma.Decimal(draft.product.potassiumPercent),
    },
  };
  const config: FertilizerConfigRecord = {
    id: randomUUID(),
    kind: 'FERTILIZER',
    configKey: FERTILIZER_CONFIG_KEY,
    version: 1,
    parameters: {
      algorithm: 'AREA_RATE_V1',
      engineVersion: FERTILIZER_ENGINE_VERSION,
      crop: 'MAIZE',
      quantityDecimalPlaces: 3,
      roundingMode: 'HALF_UP',
    },
    unit: 'kg',
    sourceReference: FERTILIZER_UNIT_REFERENCE.url,
    status: 'ACTIVE',
    createdById: randomUUID(),
    ...dates,
  };
  const records = { rules: [rule], configs: [config] };
  const writes: { input: FertilizerDraftWrite; actorId: string; requestId: string }[] = [];
  const changes: { ruleId: string; status: string; actorId: string; requestId: string }[] = [];
  const reads: { operation: string; configKey: string; ruleId?: string }[] = [];
  const repository: FertilizerRepository = {
    async catalogue(configKey) {
      reads.push({ operation: 'catalogue', configKey });
      return {
        rules: records.rules.filter(
          (entry) => entry.status === 'ACTIVE' && entry.fertilizer.status === 'ACTIVE',
        ),
        configs: records.configs.filter((entry) => entry.status === 'ACTIVE'),
      };
    },
    async calculation(ruleId, configKey) {
      reads.push({ operation: 'calculation', ruleId, configKey });
      return {
        rules: records.rules.filter(
          (entry) =>
            entry.id === ruleId &&
            entry.status === 'ACTIVE' &&
            entry.fertilizer.status === 'ACTIVE',
        ),
        configs: records.configs.filter((entry) => entry.status === 'ACTIVE'),
      };
    },
    async drafts(configKey) {
      reads.push({ operation: 'drafts', configKey });
      return records;
    },
    async createDraft(input, actorId, requestId) {
      writes.push({ input, actorId, requestId });
      return {
        ...rule,
        id: randomUUID(),
        version: input.rule.version,
        parameters: input.rule.parameters as Prisma.JsonObject,
        status: 'DRAFT',
      };
    },
    async changeStatus(ruleId, status, actorId, requestId, _configKey, admit) {
      changes.push({ ruleId, status, actorId, requestId });
      const record = records.rules.find((entry) => entry.id === ruleId);
      if (!record) return null;
      if (status === 'ACTIVE' && !admit(record, config)) return 'INVALID';
      record.status = status;
      if (status === 'ACTIVE') record.fertilizer.status = 'ACTIVE';
      return record;
    },
  };
  return { repository, rule, config, records, draft, writes, changes, reads };
}
export function fertilizerInput(ruleId: string): CalculatorInput {
  return {
    area: '1.5',
    areaUnit: 'HECTARE',
    outputUnit: 'KG',
    ruleId,
    ruleVersion: 1,
    configVersion: 1,
  };
}
