import type { Environment } from '../../config/environment.js';
import { requestKnowledge } from '../knowledge/knowledge.transport.js';
import {
  indexReceiptSchema,
  type ManagementIndexer,
  preparedDocumentSchema,
} from './management.types.js';

export function createManagementIndexer(environment: Environment): ManagementIndexer {
  return {
    prepare(document) {
      return requestKnowledge(environment, 'knowledge/prepare', document, preparedDocumentSchema);
    },
    index(documentId, actorId, requestId, checkOnly) {
      return requestKnowledge(
        environment,
        checkOnly ? 'knowledge/check' : 'knowledge/index',
        { documentId, actorId, requestId },
        indexReceiptSchema,
        environment.KNOWLEDGE_INDEX_TIMEOUT_MS,
      );
    },
  };
}
