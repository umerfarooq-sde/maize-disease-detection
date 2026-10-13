import type { RequestHandler } from 'express';
import { sendSuccess } from '../../utils/respond.js';
import type { GenerationService } from './generation.service.js';
import type { AskInput } from './generation.types.js';

export function createGenerationController(service: GenerationService): {
  ask: RequestHandler;
  explain: RequestHandler;
} {
  return {
    ask: async (_request, response) => {
      const input = response.locals.validated as { body: AskInput };
      sendSuccess(response, await service.ask(input.body));
    },
    explain: async (_request, response) => {
      const input = response.locals.validated as { params: { scanId: string }; key?: string };
      sendSuccess(
        response,
        await service.explain(
          input.params.scanId,
          response.locals.principal?.userId ?? null,
          input.key,
        ),
      );
    },
  };
}
