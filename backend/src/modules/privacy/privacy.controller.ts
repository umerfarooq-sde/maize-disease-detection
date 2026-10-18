import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { PrivacyService } from './privacy.service.js';

export function privacyController(
  service: PrivacyService,
  action: 'read' | 'request',
): RequestHandler {
  return async (_request, response) => {
    const principal = response.locals.principal;
    if (!principal) throw new AppError('AUTHENTICATION_ERROR');
    sendSuccess(
      response,
      action === 'read'
        ? await service.read(principal.userId)
        : await service.request(principal.userId, response.locals.requestId),
    );
  };
}
