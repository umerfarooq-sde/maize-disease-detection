import { z } from 'zod';
import type { ValidatedImage } from '../scans/scan.types.js';

export const diseaseLabels = [
  'Common_Rust',
  'Gray_Leaf_Spot',
  'Healthy',
  'Northern_Corn_Leaf_Blight',
] as const;

export const predictionSchema = z
  .strictObject({
    predictedClass: z.enum(diseaseLabels),
    confidence: z.number().finite().min(0).max(1),
    topProbabilities: z
      .array(
        z.strictObject({
          className: z.enum(diseaseLabels),
          probability: z.number().finite().min(0).max(1),
        }),
      )
      .length(4),
    modelVersion: z.string().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/),
    preprocessingVersion: z.string().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/),
    inferenceDurationMs: z.number().finite().min(0).max(20000),
    predictionStatus: z.enum(['CONFIDENT', 'LOW_CONFIDENCE']),
    uncertaintyReason: z.enum(['BELOW_VALIDATION_THRESHOLD', 'THRESHOLD_UNCONFIGURED']).nullable(),
    confidenceThreshold: z.number().finite().gt(0).lt(1).nullable(),
  })
  .refine((data) => {
    const probabilities = data.topProbabilities;
    const first = probabilities[0];
    if (
      !first ||
      first.className !== data.predictedClass ||
      Math.abs(first.probability - data.confidence) > 1e-6 ||
      new Set(probabilities.map((item) => item.className)).size !== 4 ||
      Math.abs(probabilities.reduce((sum, item) => sum + item.probability, 0) - 1) > 1e-5
    )
      return false;
    for (let index = 1; index < probabilities.length; index++) {
      const previous = probabilities[index - 1];
      const current = probabilities[index];
      if (
        !previous ||
        !current ||
        previous.probability < current.probability ||
        (previous.probability === current.probability &&
          diseaseLabels.indexOf(previous.className) > diseaseLabels.indexOf(current.className))
      )
        return false;
    }
    if (data.confidenceThreshold === null)
      return (
        data.predictionStatus === 'LOW_CONFIDENCE' &&
        data.uncertaintyReason === 'THRESHOLD_UNCONFIGURED'
      );
    return data.confidence < data.confidenceThreshold
      ? data.predictionStatus === 'LOW_CONFIDENCE' &&
          data.uncertaintyReason === 'BELOW_VALIDATION_THRESHOLD'
      : data.predictionStatus === 'CONFIDENT' && data.uncertaintyReason === null;
  }, 'Classifier probabilities and uncertainty must be coherent.');

export type InferencePrediction = z.infer<typeof predictionSchema>;

export interface AiInferenceClient {
  readonly enabled: boolean;
  predict(image: ValidatedImage): Promise<InferencePrediction>;
}
