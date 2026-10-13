import { randomUUID } from 'node:crypto';
import type {
  AskInput,
  GenerationClient,
  GenerationData,
  PredictionContext,
} from '../../src/modules/generation/generation.types.js';
import type { scanResponse } from '../../src/modules/scans/scan.types.js';
import { source } from '../knowledge/helpers.js';

export function prediction(overrides: Partial<PredictionContext> = {}): PredictionContext {
  return {
    predictedClass: 'Common_Rust',
    confidence: 0.8,
    modelVersion: 'fixture-model-v1',
    preprocessingVersion: '1.0.0',
    predictionStatus: 'LOW_CONFIDENCE',
    confidenceThreshold: null,
    uncertaintyReason: 'THRESHOLD_UNCONFIGURED',
    ...overrides,
  };
}
export function answer(context: PredictionContext | null = null): GenerationData {
  return {
    status: 'GROUNDED',
    reason: 'EVIDENCE_SELECTED',
    message: 'Reviewed educational evidence.',
    sections: [
      {
        knowledgeType: 'OVERVIEW',
        heading: 'Common Rust overview',
        items: [
          { text: 'Synthetic reviewed evidence paragraph for contract tests.', sourceIds: ['e1'] },
        ],
      },
    ],
    sources: [
      {
        id: 'e1',
        documentId: randomUUID(),
        documentKey: 'maize-common-rust-overview',
        documentVersion: 1,
        chunkIds: [randomUUID()],
        source,
      },
    ],
    classifierPrediction: context,
    warnings:
      context?.predictionStatus === 'LOW_CONFIDENCE'
        ? ['The model result is uncertain; no confidence threshold has been approved.']
        : [],
    providerUsed: true,
    generationModel: 'fixture-generation-model-v1',
    promptVersion: 'grounded-evidence-selection-v1',
    contextPolicyVersion: 'reviewed-excerpts-v1',
    reviewSetVersion: 'fixture-reviewed-evidence-v1',
    durationMs: 18.25,
  };
}
export function scanDto(): ReturnType<typeof scanResponse> {
  const createdAt = new Date().toISOString();
  return {
    id: randomUUID(),
    status: 'COMPLETED',
    createdAt,
    finishedAt: createdAt,
    prediction: {
      ...prediction(),
      probabilities: {
        Common_Rust: 0.8,
        Gray_Leaf_Spot: 0.1,
        Healthy: 0.05,
        Northern_Corn_Leaf_Blight: 0.05,
      },
      inferenceDurationMs: 12,
      inferredAt: createdAt,
    },
    analysisError: null,
    image: {
      url: 'https://res.cloudinary.com/private-signed-url-sentinel',
      mimeType: 'image/png',
      bytes: 200,
      uploadedAt: createdAt,
    },
  };
}
export function fakeGeneration() {
  const asks: AskInput[] = [];
  const explanations: PredictionContext[] = [];
  const client: GenerationClient = {
    enabled: true,
    async ask(input) {
      asks.push(input);
      return answer();
    },
    async explain(context) {
      explanations.push(context);
      return answer(context);
    },
  };
  return { client, asks, explanations };
}
