import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { FertilizerService } from './fertilizer.service.js';
import type { CalculatorInput } from './fertilizer.types.js';
import type { FertilizerDraftInput } from './fertilizer.validators.js';

export function createFertilizerController(service: FertilizerService): {
  list: RequestHandler;
  calculate: RequestHandler;
  drafts: RequestHandler;
  createDraft: RequestHandler;
  changeStatus: RequestHandler;
} {
  return {
    list: async (_request, response) => {
      sendSuccess(response, await service.listRules());
    },
    calculate: async (_request, response) => {
      const input = response.locals.validated as { body: CalculatorInput };
      sendSuccess(response, await service.calculate(input.body));
    },
    drafts: async (_request, response) => {
      sendSuccess(response, await service.listDrafts());
    },
    createDraft: async (_request, response) => {
      const principal = response.locals.principal;
      if (!principal) throw new AppError('AUTHENTICATION_ERROR');
      const input = response.locals.validated as { body: FertilizerDraftInput };
      sendSuccess(
        response,
        await service.createDraft(input.body, principal.userId, response.locals.requestId),
        201,
      );
    },
    changeStatus: async (_request, response) => {
      const principal = response.locals.principal;
      if (!principal) throw new AppError('AUTHENTICATION_ERROR');
      const input = response.locals.validated as {
        body: { status: 'ACTIVE' | 'INACTIVE' };
        params: { ruleId: string };
      };
      sendSuccess(
        response,
        await service.changeStatus(
          input.params.ruleId,
          input.body.status,
          principal.userId,
          response.locals.requestId,
        ),
      );
    },
  };
}
