import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { ProfileService } from './profile.service.js';
import type { ProfilePatch } from './profile.types.js';

export function profileController(
  service: ProfileService,
  action: 'read' | 'patch',
): RequestHandler {
  return async (_request, response) => {
    const principal = response.locals.principal;
    if (!principal) throw new AppError('AUTHENTICATION_ERROR');
    const input = response.locals.validated as { body: ProfilePatch };
    sendSuccess(
      response,
      action === 'read'
        ? await service.read(principal.userId)
        : await service.patch(principal.userId, input.body),
    );
  };
}
