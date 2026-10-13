import { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { diseaseLabels, predictionSchema } from '../inference/inference.types.js';
import {
  knowledgeSearchSchema,
  knowledgeSourceSchema,
  knowledgeTypes,
} from '../knowledge/knowledge.types.js';

const nonblank = (maximum: number) =>
  z
    .string()
    .max(maximum)
    .refine((value) => value.trim().length > 0);
const identifier = z
  .string()
  .min(1)
  .max(160)
  .regex(/^[A-Za-z0-9][A-Za-z0-9._:/@-]*$/);
const sourceId = z.string().regex(/^e[1-9][0-9]{0,2}$/);

export const predictionContextSchema = z
  .strictObject({
    predictedClass: predictionSchema.shape.predictedClass,
    confidence: predictionSchema.shape.confidence,
    modelVersion: predictionSchema.shape.modelVersion,
    preprocessingVersion: predictionSchema.shape.preprocessingVersion,
    predictionStatus: predictionSchema.shape.predictionStatus,
    confidenceThreshold: predictionSchema.shape.confidenceThreshold,
    uncertaintyReason: predictionSchema.shape.uncertaintyReason,
  })
  .refine((value) => {
    if (value.confidenceThreshold === null)
      return (
        value.predictionStatus === 'LOW_CONFIDENCE' &&
        value.uncertaintyReason === 'THRESHOLD_UNCONFIGURED'
      );
    return value.confidence < value.confidenceThreshold
      ? value.predictionStatus === 'LOW_CONFIDENCE' &&
          value.uncertaintyReason === 'BELOW_VALIDATION_THRESHOLD'
      : value.predictionStatus === 'CONFIDENT' && value.uncertaintyReason === null;
  });

export const askSchema = z.strictObject({
  question: knowledgeSearchSchema.shape.query,
  diseaseLabel: z.enum(diseaseLabels).optional(),
  knowledgeType: z.enum(knowledgeTypes).optional(),
});

export const generationDataSchema = z
  .strictObject({
    status: z.enum([
      'GROUNDED',
      'INSUFFICIENT_INFORMATION',
      'OUT_OF_SCOPE',
      'CONFLICTING_EVIDENCE',
    ]),
    reason: z.string().regex(/^[A-Z][A-Z0-9_]{0,79}$/),
    message: nonblank(2000),
    sections: z
      .array(
        z.strictObject({
          knowledgeType: z.enum(knowledgeTypes),
          heading: nonblank(160),
          items: z
            .array(
              z.strictObject({
                text: nonblank(4000),
                sourceIds: z.array(sourceId).min(1).max(20),
              }),
            )
            .min(1)
            .max(10),
        }),
      )
      .max(7),
    sources: z
      .array(
        z.strictObject({
          id: sourceId,
          documentId: z.uuid(),
          documentKey: z
            .string()
            .max(160)
            .regex(/^[a-z0-9][a-z0-9._-]*$/),
          documentVersion: z.number().int().min(1).max(2_147_483_647),
          chunkIds: z.array(z.uuid()).min(1).max(32),
          source: knowledgeSourceSchema,
        }),
      )
      .max(20),
    classifierPrediction: predictionContextSchema.nullable(),
    warnings: z.array(nonblank(1000)).max(10),
    providerUsed: z.boolean(),
    generationModel: identifier,
    promptVersion: z.literal('grounded-evidence-selection-v1'),
    contextPolicyVersion: z.literal('reviewed-excerpts-v1'),
    reviewSetVersion: identifier,
    durationMs: z.number().finite().min(0).max(120_000),
  })
  .refine((data) => {
    const grounded = data.status === 'GROUNDED';
    if (grounded && !data.providerUsed) return false;
    if (
      grounded
        ? !data.sections.length || !data.sources.length
        : data.sections.length || data.sources.length
    )
      return false;
    if (
      new Set(data.sources.map((source) => source.id)).size !== data.sources.length ||
      new Set(data.sections.map((section) => section.knowledgeType)).size !== data.sections.length
    )
      return false;
    if (data.sources.some((source) => new Set(source.chunkIds).size !== source.chunkIds.length))
      return false;
    const available = new Set(data.sources.map((source) => source.id));
    const used = new Set<string>();
    for (const section of data.sections) {
      for (const item of section.items) {
        if (new Set(item.sourceIds).size !== item.sourceIds.length) return false;
        for (const id of item.sourceIds) {
          if (!available.has(id)) return false;
          used.add(id);
        }
      }
    }
    if (used.size !== available.size) return false;
    return (
      data.classifierPrediction?.predictionStatus !== 'LOW_CONFIDENCE' || data.warnings.length > 0
    );
  });

export type PredictionContext = z.infer<typeof predictionContextSchema>;
export type AskInput = z.infer<typeof askSchema>;
export type GenerationData = z.infer<typeof generationDataSchema>;
export interface GenerationClient {
  readonly enabled: boolean;
  ask(input: AskInput): Promise<GenerationData>;
  explain(prediction: PredictionContext): Promise<GenerationData>;
}

export function assertPredictionPreserved(
  data: GenerationData,
  expected: PredictionContext | null,
): void {
  const actual = data.classifierPrediction;
  if (expected === null) {
    if (actual !== null) throw new AppError('GEN_INVALID_RESPONSE');
    return;
  }
  const fields = [
    'predictedClass',
    'confidence',
    'modelVersion',
    'preprocessingVersion',
    'predictionStatus',
    'confidenceThreshold',
    'uncertaintyReason',
  ] as const;
  if (actual === null || fields.some((field) => actual[field] !== expected[field]))
    throw new AppError('GEN_INVALID_RESPONSE');
}
