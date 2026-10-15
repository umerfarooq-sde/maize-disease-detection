import type { Environment } from '../../config/environment.js';
import { requestKnowledge } from '../knowledge/knowledge.transport.js';
import type { ModelHealthRepository } from './model-health.repository.js';
import {
  modelHealthSchema,
  type ModelHealth,
  type ModelHealthSummary,
} from './model-health.types.js';

export interface ModelHealthService {
  summary(): Promise<ModelHealthSummary>;
}
export function createModelHealthClient(
  environment: Pick<Environment, 'AI_SERVICE_URL' | 'AI_SERVICE_TOKEN' | 'AI_SERVICE_TIMEOUT_MS'>,
  transport: typeof fetch = fetch,
) {
  return () =>
    requestKnowledge(
      environment,
      'model-dashboard',
      undefined,
      modelHealthSchema,
      environment.AI_SERVICE_TIMEOUT_MS,
      transport,
    );
}
export function createModelHealthService(
  repository: ModelHealthRepository,
  environment: Pick<Environment, 'AI_MODEL_VERSION' | 'AI_PREPROCESSING_VERSION'>,
  probe: () => Promise<ModelHealth>,
  now: () => Date = () => new Date(),
): ModelHealthService {
  return {
    async summary() {
      const registry = await repository.registry();
      const productionVersion =
        registry.productionVersions.length === 1 ? (registry.productionVersions[0] ?? null) : null;
      let data: ModelHealth | null = null;
      let status: ModelHealthSummary['service']['status'] = 'UNAVAILABLE';
      try {
        const value = modelHealthSchema.parse(await probe());
        if (
          value.ready &&
          (value.modelVersion !== environment.AI_MODEL_VERSION ||
            value.preprocessingVersion !== environment.AI_PREPROCESSING_VERSION)
        )
          status = 'INCOMPATIBLE';
        else {
          value.runtime.since = new Date(value.runtime.since).toISOString();
          data = value;
          status = value.ready ? 'READY' : 'NOT_LOADED';
        }
      } catch {
        /* Deliberately omit service origins, credentials and provider errors. */
      }
      return {
        asOf: now().toISOString(),
        registry: {
          models: registry.models,
          productionVersion,
          status:
            registry.productionVersions.length === 0
              ? 'NOT_PROMOTED'
              : registry.productionVersions.length === 1
                ? 'SINGLE_PRODUCTION'
                : 'MULTIPLE_PRODUCTION',
        },
        service: {
          status,
          configuredVersion: environment.AI_MODEL_VERSION || null,
          registered:
            !!data?.modelVersion &&
            registry.models.some((row) => row.version === data?.modelVersion),
          matchesProduction: !!productionVersion && data?.modelVersion === productionVersion,
          data,
        },
        drift: 'NOT_AVAILABLE_NO_GROUND_TRUTH',
      };
    },
  };
}
