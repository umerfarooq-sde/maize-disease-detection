import { AppError } from '../../errors/app-error.js';
import type { ScanService } from '../scans/scan.service.js';
import {
  type AskInput,
  assertPredictionPreserved,
  type GenerationClient,
  type GenerationData,
  predictionContextSchema,
} from './generation.types.js';

export interface GenerationService {
  ask(input: AskInput): Promise<GenerationData>;
  explain(scanId: string, userId: string | null, key?: string): Promise<GenerationData>;
}

export function createGenerationService(
  scans: Pick<ScanService, 'read'>,
  client: GenerationClient,
): GenerationService {
  return {
    async ask(input) {
      const result = await client.ask(input);
      assertPredictionPreserved(result, null);
      return result;
    },
    async explain(scanId, userId, key) {
      // Authorization/capability checks and stale recovery precede any provider
      // call. A scan UUID alone never grants access to an anonymous prediction.
      const scan = await scans.read(scanId, userId, key);
      if (scan.status !== 'COMPLETED' || scan.prediction === null)
        throw new AppError('SCAN_EXPLANATION_UNAVAILABLE');
      const stored = scan.prediction;
      const parsed = predictionContextSchema.safeParse({
        predictedClass: stored.predictedClass,
        confidence: stored.confidence,
        modelVersion: stored.modelVersion,
        preprocessingVersion: stored.preprocessingVersion,
        predictionStatus: stored.predictionStatus,
        confidenceThreshold: stored.confidenceThreshold,
        uncertaintyReason: stored.uncertaintyReason,
      });
      if (!parsed.success) throw new AppError('SCAN_EXPLANATION_UNAVAILABLE');
      // Only these persisted scalar values reach the AI service: no photos,
      // signed URLs, personal identifiers or private anonymous keys.
      const prediction = Object.freeze(parsed.data);
      const result = await client.explain(prediction);
      assertPredictionPreserved(result, prediction);
      return result;
    },
  };
}
