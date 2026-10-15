import { AppError } from '../../errors/app-error.js';
import { type KnowledgeClient, retrievalResultSchema } from './knowledge.types.js';
import { requestKnowledge, type KnowledgeEnvironment } from './knowledge.transport.js';
export function createKnowledgeClient(
  environment: KnowledgeEnvironment,
  transport: typeof fetch = fetch,
): KnowledgeClient {
  return {
    enabled: environment.AI_SERVICE_URL !== '',
    async search(input) {
      const result = await requestKnowledge(
        environment,
        'retrieve',
        input,
        retrievalResultSchema,
        environment.AI_SERVICE_TIMEOUT_MS,
        transport,
      );
      if (
        result.chunks.length > input.topK ||
        result.chunks.some(
          (chunk) =>
            (input.diseaseLabel !== undefined && chunk.diseaseLabel !== input.diseaseLabel) ||
            (input.knowledgeType !== undefined && chunk.knowledgeType !== input.knowledgeType) ||
            (input.documentVersion !== undefined &&
              chunk.documentVersion !== input.documentVersion),
        )
      )
        throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
      return result;
    },
  };
}
