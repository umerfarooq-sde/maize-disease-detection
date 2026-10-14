import { AppError } from '../../errors/app-error.js';
import { calculateYield } from './yield.engine.js';
import type { YieldConfigurationRecord, YieldRepository } from './yield.repository.js';
import {
  type PublicYieldConfiguration,
  YIELD_CONFIG_KEY,
  YIELD_ENGINE_VERSION,
  YIELD_FORMULA_VERSION,
  type YieldCatalogue,
  type YieldDraft,
  type YieldInput,
  type YieldResult,
  yieldParametersSchema,
} from './yield.types.js';

export function publicYieldConfiguration(
  record: YieldConfigurationRecord,
  activeOnly = true,
): PublicYieldConfiguration | null {
  const parameters = yieldParametersSchema.safeParse(record.parameters);
  if (
    !parameters.success ||
    record.kind !== 'YIELD' ||
    record.configKey !== YIELD_CONFIG_KEY ||
    record.unit !== 'kg/ha' ||
    record.sourceReference !== parameters.data.source.url ||
    (activeOnly && record.status !== 'ACTIVE')
  )
    return null;
  const data = parameters.data;
  return {
    id: record.id,
    configKey: YIELD_CONFIG_KEY,
    version: record.version,
    title: data.title,
    crop: data.crop,
    expectedYieldKgPerHectare: data.expectedYieldKgPerHectare,
    applicability: data.applicability,
    assumptions: data.assumptions,
    source: data.source,
    engineVersion: data.engineVersion,
    formulaVersion: data.formulaVersion,
    rounding: { mode: data.roundingMode, decimalPlaces: data.quantityDecimalPlaces },
  };
}
export interface YieldDraftSummary {
  id: string;
  configKey: string;
  version: number;
  status: 'DRAFT' | 'ACTIVE' | 'INACTIVE';
  validForActivation: boolean;
}
const summary = (record: YieldConfigurationRecord): YieldDraftSummary => ({
  id: record.id,
  configKey: record.configKey,
  version: record.version,
  status: record.status,
  validForActivation: publicYieldConfiguration(record, false) !== null,
});
export interface YieldService {
  list(): Promise<YieldCatalogue>;
  calculate(input: YieldInput): Promise<YieldResult>;
  drafts(): Promise<{ items: YieldDraftSummary[]; limit: number }>;
  createDraft(input: YieldDraft, actorId: string, requestId: string): Promise<YieldDraftSummary>;
  changeStatus(
    id: string,
    status: 'ACTIVE' | 'INACTIVE',
    actorId: string,
    requestId: string,
  ): Promise<YieldDraftSummary>;
}
export function createYieldService(
  repository: YieldRepository,
  now: () => Date = () => new Date(),
): YieldService {
  return {
    async list() {
      const items = (await repository.list(true)).flatMap((record) => {
        const configuration = publicYieldConfiguration(record);
        return configuration ? [configuration] : [];
      });
      return {
        status: items.length ? 'READY' : 'PENDING_CONFIGURATION',
        engineVersion: YIELD_ENGINE_VERSION,
        message: items.length
          ? 'Use only a reviewed planning configuration whose conditions apply to your field.'
          : 'An authoritative maize yield model and applicable rates have not been approved. No expected yield is available yet.',
        items,
      };
    },
    async calculate(input) {
      const record = await repository.find(input.configId);
      if (record?.status !== 'ACTIVE' || record.version !== input.configVersion)
        throw new AppError('YIELD_CONFIGURATION_CHANGED');
      const configuration = publicYieldConfiguration(record);
      if (!configuration) throw new AppError('YIELD_CONFIGURATION_INVALID');
      return calculateYield(input, configuration);
    },
    async drafts() {
      return { items: (await repository.list(false)).map(summary), limit: 100 };
    },
    async createDraft(input, actorId, requestId) {
      const parameters = yieldParametersSchema.parse({
        algorithm: 'AREA_TIMES_REVIEWED_YIELD_RATE_V1',
        engineVersion: YIELD_ENGINE_VERSION,
        formulaVersion: YIELD_FORMULA_VERSION,
        crop: 'MAIZE',
        title: input.title,
        expectedYieldKgPerHectare: input.expectedYieldKgPerHectare,
        applicability: input.applicability,
        assumptions: input.assumptions,
        source: input.source,
        quantityDecimalPlaces: input.quantityDecimalPlaces,
        roundingMode: 'HALF_UP',
        approval: {
          status: 'PROJECT_APPROVED_SOURCE',
          reviewedAt: now().toISOString(),
          reviewedBy: actorId,
          note: input.reviewNote,
        },
      });
      const record = await repository.createDraft(
        { version: input.version, parameters, sourceReference: input.source.url },
        actorId,
        requestId,
      );
      if (!record) throw new AppError('CONFLICT');
      return summary(record);
    },
    async changeStatus(id, status, actorId, requestId) {
      const record = await repository.changeStatus(
        id,
        status,
        actorId,
        requestId,
        (candidate) => publicYieldConfiguration(candidate, false) !== null,
      );
      if (!record) throw new AppError('NOT_FOUND');
      if (record === 'INVALID') throw new AppError('YIELD_CONFIGURATION_INVALID');
      return summary(record);
    },
  };
}
