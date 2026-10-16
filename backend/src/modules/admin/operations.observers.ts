import type { AiInferenceClient } from '../inference/inference.types.js';
import type { KnowledgeClient } from '../knowledge/knowledge.types.js';
import type { GenerationClient } from '../generation/generation.types.js';
import type { OperationsService } from './operations.service.js';
export function observeInference(
  client: AiInferenceClient,
  operations: OperationsService,
): AiInferenceClient {
  return {
    enabled: client.enabled,
    predict: (image) => operations.measure('INFERENCE', () => client.predict(image)),
  };
}
export function observeKnowledge(
  client: KnowledgeClient,
  operations: OperationsService,
): KnowledgeClient {
  return {
    enabled: client.enabled,
    search: (input) => operations.measure('RETRIEVAL', () => client.search(input)),
  };
}
export function observeGeneration(
  client: GenerationClient,
  operations: OperationsService,
): GenerationClient {
  return {
    enabled: client.enabled,
    ask: (input) => operations.measure('GENERATION', () => client.ask(input)),
    explain: (input) => operations.measure('EXPLANATION', () => client.explain(input)),
  };
}
