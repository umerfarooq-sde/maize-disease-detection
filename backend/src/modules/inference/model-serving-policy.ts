import type { ModelVersion } from '../../generated/prisma/client.js';

/** Serving eligibility is distinct from technical artifact registration. */
export type ServingEnvironment = 'development' | 'test' | 'production';
export type RegisteredModel = Pick<ModelVersion, 'status' | 'trainingConfig'>;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function canServeRegisteredModel(
  model: RegisteredModel | null | undefined,
  environment: ServingEnvironment,
): boolean {
  if (!model || (model.status !== 'VALIDATED' && model.status !== 'PRODUCTION')) return false;
  if (environment !== 'production') return true;
  if (model.status !== 'PRODUCTION' || !isRecord(model.trainingConfig)) return false;
  const policy = model.trainingConfig['researchPolicy'];
  // No implicit commercial permission for missing, malformed or research-only metadata.
  return (
    isRecord(policy) &&
    policy['commercial_clearance'] === true &&
    typeof policy['permitted_use'] === 'string' &&
    /commercial/i.test(policy['permitted_use']) &&
    !/non[- ]commercial|research only|academic\/FYP/i.test(policy['permitted_use'])
  );
}
