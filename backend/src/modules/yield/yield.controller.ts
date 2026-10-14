import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { YieldService } from './yield.service.js';
import type { YieldDraft, YieldInput } from './yield.types.js';

export function createYieldController(
  service: YieldService,
): Record<'list' | 'calculate' | 'drafts' | 'createDraft' | 'changeStatus', RequestHandler> {
  return {
    list: async (_request, response) => {
      sendSuccess(response, await service.list());
    },
    calculate: async (_request, response) => {
      const input = response.locals.validated as { body: YieldInput };
      sendSuccess(response, await service.calculate(input.body));
    },
    drafts: async (_request, response) => {
      sendSuccess(response, await service.drafts());
    },
    createDraft: async (_request, response) => {
      const actor = response.locals.principal;
      if (!actor) throw new AppError('AUTHENTICATION_ERROR');
      const input = response.locals.validated as { body: YieldDraft };
      sendSuccess(
        response,
        await service.createDraft(input.body, actor.userId, response.locals.requestId),
        201,
      );
    },
    changeStatus: async (_request, response) => {
      const actor = response.locals.principal;
      if (!actor) throw new AppError('AUTHENTICATION_ERROR');
      const input = response.locals.validated as {
        body: { status: 'ACTIVE' | 'INACTIVE' };
        params: { configId: string };
      };
      sendSuccess(
        response,
        await service.changeStatus(
          input.params.configId,
          input.body.status,
          actor.userId,
          response.locals.requestId,
        ),
      );
    },
  };
}
