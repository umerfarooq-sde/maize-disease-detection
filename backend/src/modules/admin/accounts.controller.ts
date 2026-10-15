import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { AccountsService } from './accounts.service.js';
import type { AuditQuery, FarmerQuery, StatusPatch } from './accounts.types.js';

export function accountsController(
  service: AccountsService,
  action: 'farmers' | 'status' | 'audits',
): RequestHandler {
  return async (_request, response) => {
    const principal = response.locals.principal;
    if (!principal) throw new AppError('AUTHENTICATION_ERROR');
    const input = response.locals.validated as {
      params: { id: string };
      body: StatusPatch;
      query: FarmerQuery & AuditQuery;
    };
    sendSuccess(
      response,
      action === 'farmers'
        ? await service.farmers(input.query)
        : action === 'audits'
          ? await service.audits(input.query)
          : await service.status(
              input.params.id,
              input.body,
              principal.userId,
              response.locals.requestId,
            ),
    );
  };
}
