import { z } from 'zod';
import { diseaseLabels } from '../inference/inference.types.js';

const count = z.number().int().nonnegative().safe();
const score = z.number().finite().min(0).max(1);
const name = z.string().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/);
const distribution = z.strictObject({
  Common_Rust: count,
  Gray_Leaf_Spot: count,
  Healthy: count,
  Northern_Corn_Leaf_Blight: count,
});
export const evaluationSchema = z
  .strictObject({
    class_names: z.array(z.enum(diseaseLabels)).length(4),
    sample_count: count.positive(),
    accuracy: score,
    macro_precision: score,
    macro_recall: score,
    macro_f1: score,
    per_class: z
      .array(
        z.strictObject({
          label: z.enum(diseaseLabels),
          support: count,
          precision: score.nullable(),
          recall: score.nullable(),
          f1: score.nullable(),
          specificity: score.nullable(),
        }),
      )
      .length(4),
    confusion_matrix: z.array(z.array(count).length(4)).length(4),
  })
  .refine(
    (v) =>
      diseaseLabels.every(
        (label, i) =>
          v.class_names[i] === label &&
          v.per_class[i]?.label === label &&
          v.confusion_matrix[i]?.reduce((a, b) => a + b, 0) === v.per_class[i]?.support,
      ) &&
      v.confusion_matrix.flat().reduce((a, b) => a + b, 0) === v.sample_count &&
      Math.abs(
        v.confusion_matrix.reduce((sum, row, i) => sum + (row[i] ?? 0), 0) / v.sample_count -
          v.accuracy,
      ) < 1e-9,
  );
export const modelHealthSchema = z
  .strictObject({
    ready: z.boolean(),
    modelVersion: name.nullable(),
    preprocessingVersion: name.nullable(),
    confidencePolicy: z.enum(['VALIDATION_BASED', 'UNCONFIGURED']),
    development: z
      .strictObject({
        architecture: name,
        datasetVersion: name,
        indexFingerprint: z.string().regex(/^[a-f0-9]{64}$/),
        experimentId: name,
        trainedAt: z.null(),
        evaluation: evaluationSchema,
      })
      .nullable(),
    runtime: z.strictObject({
      scope: z.literal('PROCESS_SINCE_START'),
      since: z.iso.datetime({ offset: true }),
      requests: count,
      inFlight: count,
      successes: count,
      failures: count,
      lowConfidence: count,
      lowConfidenceRate: score.nullable(),
      meanLatencyMs: z.number().finite().nonnegative().nullable(),
      predictionDistribution: distribution,
    }),
  })
  .refine(
    (v) =>
      v.ready === (v.modelVersion !== null && v.preprocessingVersion !== null) &&
      (v.ready || (v.modelVersion === null && v.preprocessingVersion === null)) &&
      (v.ready || v.development === null) &&
      v.runtime.requests === v.runtime.inFlight + v.runtime.successes + v.runtime.failures &&
      Object.values(v.runtime.predictionDistribution).reduce((a, b) => a + b, 0) ===
        v.runtime.successes &&
      v.runtime.lowConfidence <= v.runtime.successes &&
      (v.runtime.successes === 0
        ? v.runtime.lowConfidenceRate === null
        : v.runtime.lowConfidenceRate !== null &&
          Math.abs(v.runtime.lowConfidenceRate - v.runtime.lowConfidence / v.runtime.successes) <
            1e-9) &&
      (v.runtime.successes + v.runtime.failures === 0) === (v.runtime.meanLatencyMs === null),
  );
export type ModelHealth = z.infer<typeof modelHealthSchema>;
export const registryModelSchema = z.strictObject({
  version: name,
  architecture: name,
  datasetVersion: name,
  preprocessingVersion: name,
  status: z.enum(['DRAFT', 'VALIDATED', 'PRODUCTION', 'RETIRED']),
  registeredAt: z.iso.datetime(),
});
export type RegistryModel = z.infer<typeof registryModelSchema>;
export interface ModelHealthSummary {
  asOf: string;
  registry: {
    status: 'NOT_PROMOTED' | 'SINGLE_PRODUCTION' | 'MULTIPLE_PRODUCTION';
    productionVersion: string | null;
    models: RegistryModel[];
  };
  service: {
    status: 'READY' | 'NOT_LOADED' | 'UNAVAILABLE' | 'INCOMPATIBLE';
    configuredVersion: string | null;
    registered: boolean;
    matchesProduction: boolean;
    data: ModelHealth | null;
  };
  drift: 'NOT_AVAILABLE_NO_GROUND_TRUTH';
}
