import { AppError } from '../../errors/app-error.js';
import { calculateFertilizer } from './fertilizer.engine.js';
import {
  type FertilizerConfigRecord,
  type FertilizerRepository,
  type FertilizerRuleRecord,
  fertilizerProductSnapshot,
  sameFertilizerSnapshot,
} from './fertilizer.repository.js';
import {
  type CalculatorInput,
  FERTILIZER_CONFIG_KEY,
  FERTILIZER_ENGINE_VERSION,
  type FertilizerCatalogue,
  type FertilizerResult,
  fertilizerConfigParametersSchema,
  fertilizerRuleParametersSchema,
  type PublicFertilizerRule,
  FERTILIZER_UNIT_REFERENCE as UNIT_REFERENCE,
} from './fertilizer.types.js';
import type { FertilizerDraftInput } from './fertilizer.validators.js';

export function publicFertilizerRule(
  record: FertilizerRuleRecord,
  configuration: FertilizerConfigRecord,
  activeOnly = true,
): PublicFertilizerRule | null {
  const rule = fertilizerRuleParametersSchema.safeParse(record.parameters);
  const config = fertilizerConfigParametersSchema.safeParse(configuration.parameters);
  if (
    !rule.success ||
    !config.success ||
    record.unit !== 'kg/ha' ||
    configuration.unit !== 'kg' ||
    configuration.kind !== 'FERTILIZER' ||
    configuration.configKey !== FERTILIZER_CONFIG_KEY ||
    configuration.sourceReference !== UNIT_REFERENCE.url ||
    record.sourceReference !== rule.data.source.url ||
    rule.data.configVersion !== configuration.version ||
    !sameFertilizerSnapshot(rule.data.productSnapshot, fertilizerProductSnapshot(record.fertilizer))
  )
    return null;
  if (
    activeOnly &&
    (record.status !== 'ACTIVE' ||
      record.fertilizer.status !== 'ACTIVE' ||
      configuration.status !== 'ACTIVE')
  )
    return null;
  return {
    id: record.id,
    ruleKey: record.ruleKey,
    version: record.version,
    title: rule.data.title,
    crop: 'MAIZE',
    fertilizer: { slug: rule.data.productSnapshot.slug, name: rule.data.productSnapshot.name },
    rateKgPerHectare: rule.data.rateKgPerHectare,
    applicability: rule.data.applicability,
    assumptions: rule.data.assumptions,
    source: rule.data.source,
    config: {
      key: FERTILIZER_CONFIG_KEY,
      version: configuration.version,
      engineVersion: FERTILIZER_ENGINE_VERSION,
      quantityDecimalPlaces: config.data.quantityDecimalPlaces,
      roundingMode: 'HALF_UP',
    },
  };
}

export interface FertilizerService {
  listRules(): Promise<FertilizerCatalogue>;
  calculate(input: CalculatorInput): Promise<FertilizerResult>;
  listDrafts(): Promise<{ items: FertilizerDraftSummary[]; limit: number }>;
  createDraft(
    input: FertilizerDraftInput,
    actorId: string,
    requestId: string,
  ): Promise<FertilizerDraftSummary>;
  changeStatus(
    ruleId: string,
    status: 'ACTIVE' | 'INACTIVE',
    actorId: string,
    requestId: string,
  ): Promise<FertilizerDraftSummary>;
}
export interface FertilizerDraftSummary {
  draftInput?: FertilizerDraftInput | null;
  createdAt?: string;
  updatedAt?: string;
  id: string;
  ruleKey: string;
  version: number;
  status: 'DRAFT' | 'ACTIVE' | 'INACTIVE';
  product: { slug: string; name: string; status: 'DRAFT' | 'ACTIVE' | 'INACTIVE' };
  configVersion: number | null;
  validForActivation: boolean;
}
function draftSummary(
  record: FertilizerRuleRecord,
  config?: FertilizerConfigRecord,
): FertilizerDraftSummary {
  const params = fertilizerRuleParametersSchema.safeParse(record.parameters);
  return {
    id: record.id,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
    draftInput:
      params.success && config && publicFertilizerRule(record, config, false)
        ? {
            product: params.data.productSnapshot,
            rule: {
              ruleKey: record.ruleKey,
              version: record.version,
              title: params.data.title,
              rateKgPerHectare: params.data.rateKgPerHectare,
              applicability: params.data.applicability,
              assumptions: params.data.assumptions,
              source: params.data.source,
              reviewNote: '',
            },
            config: {
              version: config.version,
              quantityDecimalPlaces: (config.parameters as { quantityDecimalPlaces: number })
                .quantityDecimalPlaces,
            },
          }
        : null,
    ruleKey: record.ruleKey,
    version: record.version,
    status: record.status,
    product: {
      slug: record.fertilizer.slug,
      name: record.fertilizer.name,
      status: record.fertilizer.status,
    },
    configVersion: params.success ? params.data.configVersion : null,
    validForActivation:
      config !== undefined && publicFertilizerRule(record, config, false) !== null,
  };
}

export function createFertilizerService(
  repository: FertilizerRepository,
  now: () => Date = () => new Date(),
): FertilizerService {
  return {
    async listRules() {
      const snapshot = await repository.catalogue(FERTILIZER_CONFIG_KEY);
      const config = snapshot.configs[0];
      const items = config
        ? snapshot.rules.flatMap((record) => {
            const rule = publicFertilizerRule(record, config);
            return rule ? [rule] : [];
          })
        : [];
      return {
        status: items.length ? 'READY' : 'PENDING_RULES',
        message: items.length
          ? 'Use only a rule whose stated conditions match your farm. Quantities are calculated from the reviewed rule.'
          : 'Source-reviewed maize fertilizer recommendations are pending. No fertilizer dose is available yet.',
        engineVersion: FERTILIZER_ENGINE_VERSION,
        items,
      };
    },
    async calculate(input) {
      const snapshot = await repository.calculation(input.ruleId, FERTILIZER_CONFIG_KEY);
      const record = snapshot.rules[0];
      const config = snapshot.configs[0];
      if (
        !record ||
        !config ||
        record.version !== input.ruleVersion ||
        config.version !== input.configVersion
      )
        throw new AppError('FERTILIZER_CONFIGURATION_CHANGED');
      const rule = publicFertilizerRule(record, config);
      if (!rule) throw new AppError('FERTILIZER_CONFIGURATION_INVALID');
      return calculateFertilizer(input, rule);
    },
    async listDrafts() {
      const snapshot = await repository.drafts(FERTILIZER_CONFIG_KEY);
      return {
        items: snapshot.rules.map((record) => {
          const params = fertilizerRuleParametersSchema.safeParse(record.parameters);
          const config = params.success
            ? snapshot.configs.find((entry) => entry.version === params.data.configVersion)
            : undefined;
          return draftSummary(record, config);
        }),
        limit: 100,
      };
    },
    async createDraft(input, actorId, requestId) {
      const parameters = fertilizerRuleParametersSchema.parse({
        algorithm: 'AREA_RATE_V1',
        crop: 'MAIZE',
        title: input.rule.title,
        rateKgPerHectare: input.rule.rateKgPerHectare,
        applicability: input.rule.applicability,
        assumptions: input.rule.assumptions,
        source: input.rule.source,
        configVersion: input.config.version,
        productSnapshot: input.product,
        approval: {
          status: 'PROJECT_APPROVED_SOURCE',
          reviewedAt: now().toISOString(),
          reviewedBy: actorId,
          note: input.rule.reviewNote,
        },
      });
      const configParameters = fertilizerConfigParametersSchema.parse({
        algorithm: 'AREA_RATE_V1',
        engineVersion: FERTILIZER_ENGINE_VERSION,
        crop: 'MAIZE',
        quantityDecimalPlaces: input.config.quantityDecimalPlaces,
        roundingMode: 'HALF_UP',
      });
      const record = await repository.createDraft(
        {
          product: input.product,
          rule: {
            ruleKey: input.rule.ruleKey,
            version: input.rule.version,
            parameters,
            sourceReference: input.rule.source.url,
          },
          config: {
            configKey: FERTILIZER_CONFIG_KEY,
            version: input.config.version,
            parameters: configParameters,
            sourceReference: UNIT_REFERENCE.url,
          },
        },
        actorId,
        requestId,
      );
      if (!record) throw new AppError('CONFLICT');
      return { ...draftSummary(record), validForActivation: true };
    },
    async changeStatus(ruleId, status, actorId, requestId) {
      const record = await repository.changeStatus(
        ruleId,
        status,
        actorId,
        requestId,
        FERTILIZER_CONFIG_KEY,
        (rule, config) => publicFertilizerRule(rule, config, false) !== null,
      );
      if (record === null) throw new AppError('NOT_FOUND');
      if (record === 'INVALID') throw new AppError('FERTILIZER_CONFIGURATION_INVALID');
      return { ...draftSummary(record), validForActivation: status === 'ACTIVE' };
    },
  };
}
