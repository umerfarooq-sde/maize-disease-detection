import { randomUUID } from 'node:crypto';
import type { Prisma } from '../../src/generated/prisma/client.js';
import type {
  YieldConfigurationRecord,
  YieldRepository,
} from '../../src/modules/yield/yield.repository.js';
import {
  YIELD_CONFIG_KEY,
  YIELD_ENGINE_VERSION,
  YIELD_FORMULA_VERSION,
  type YieldDraft,
  type YieldInput,
  yieldDraftSchema,
} from '../../src/modules/yield/yield.types.js';

// Synthetic arithmetic fixtures only. Never seed/publish as real agronomic data.
export function draft(): YieldDraft {
  return yieldDraftSchema.parse({
    version: 1,
    title: 'SYNTHETIC arithmetic scenario; not agricultural advice',
    expectedYieldKgPerHectare: '12.5',
    applicability: 'Synthetic tests only; no farm applicability.',
    assumptions: ['Synthetic arithmetic fixture only.'],
    source: {
      title: 'Synthetic test source',
      publisher: 'Test suite',
      url: 'https://example.invalid/synthetic-yield',
      citation: 'Fixture only; no authoritative yield data.',
    },
    quantityDecimalPlaces: 3,
    reviewNote: 'Synthetic isolated attestation only; no actual agronomic approval.',
  });
}
export function configuration(): YieldConfigurationRecord {
  const data = draft();
  return {
    id: randomUUID(),
    kind: 'YIELD',
    configKey: YIELD_CONFIG_KEY,
    version: 1,
    unit: 'kg/ha',
    sourceReference: data.source.url,
    status: 'ACTIVE',
    createdById: null,
    createdAt: new Date('2026-10-15T00:00:00Z'),
    updatedAt: new Date('2026-10-15T00:00:00Z'),
    parameters: {
      algorithm: 'AREA_TIMES_REVIEWED_YIELD_RATE_V1',
      engineVersion: YIELD_ENGINE_VERSION,
      formulaVersion: YIELD_FORMULA_VERSION,
      crop: 'MAIZE',
      title: data.title,
      expectedYieldKgPerHectare: data.expectedYieldKgPerHectare,
      applicability: data.applicability,
      assumptions: data.assumptions,
      source: data.source,
      quantityDecimalPlaces: data.quantityDecimalPlaces,
      roundingMode: 'HALF_UP',
      approval: {
        status: 'PROJECT_APPROVED_SOURCE',
        reviewedAt: '2026-10-15T00:00:00Z',
        reviewedBy: randomUUID(),
        note: data.reviewNote,
      },
    },
  };
}
export function input(configId: string, overrides: Partial<YieldInput> = {}): YieldInput {
  return {
    area: '2',
    areaUnit: 'HECTARE',
    outputUnit: 'KG',
    configId,
    configVersion: 1,
    ...overrides,
  };
}
export function memoryYield() {
  const record = configuration();
  const records: YieldConfigurationRecord[] = [record];
  const writes: { actorId: string; requestId: string }[] = [];
  const repository: YieldRepository = {
    async list(activeOnly) {
      return records.filter((entry) => !activeOnly || entry.status === 'ACTIVE');
    },
    async find(id) {
      return records.find((entry) => entry.id === id) ?? null;
    },
    async createDraft(data, actorId, requestId) {
      if (records.some((entry) => entry.version === data.version)) return null;
      writes.push({ actorId, requestId });
      const created: YieldConfigurationRecord = {
        ...record,
        ...data,
        id: randomUUID(),
        parameters: data.parameters as Prisma.JsonObject,
        createdById: actorId,
        status: 'DRAFT',
      };
      records.push(created);
      return created;
    },
    async changeStatus(id, status, actorId, requestId, admit) {
      const candidate = records.find((entry) => entry.id === id);
      if (!candidate) return null;
      if (status === 'ACTIVE' && !admit(candidate)) return 'INVALID';
      if (status === 'ACTIVE') for (const previous of records) previous.status = 'INACTIVE';
      candidate.status = status;
      writes.push({ actorId, requestId });
      return candidate;
    },
  };
  return { repository, records, record, writes };
}
