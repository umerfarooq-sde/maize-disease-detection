import type { RequestHandler } from 'express';
import { sendSuccess } from '../../utils/respond.js';
import type { KnowledgeService } from './knowledge.service.js';
import type { KnowledgeSearch } from './knowledge.types.js';

export function createKnowledgeController(service: KnowledgeService): {
  list: RequestHandler;
  detail: RequestHandler;
  search: RequestHandler;
} {
  return {
    list: async (_request, response) => {
      sendSuccess(response, await service.listDiseases());
    },
    detail: async (_request, response) => {
      const input = response.locals.validated as { params: { slug: string } };
      sendSuccess(response, await service.getDisease(input.params.slug));
    },
    search: async (_request, response) => {
      const input = response.locals.validated as { body: KnowledgeSearch };
      sendSuccess(response, await service.search(input.body));
    },
  };
}
