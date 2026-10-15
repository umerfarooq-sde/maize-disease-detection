import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import { validateImage } from '../scans/scan.validation.js';
import type { ProfileMediaService } from './profile-media.service.js';

export function profileMediaController(
  service: ProfileMediaService,
  action: 'upload' | 'remove',
): RequestHandler {
  return async (request, response) => {
    try {
      const principal = response.locals.principal;
      if (!principal) throw new AppError('AUTHENTICATION_ERROR');
      const input = response.locals.validated as { body: { expectedRevision: string } };
      sendSuccess(
        response,
        action === 'upload'
          ? await service.upload(
              principal.userId,
              input.body.expectedRevision,
              await validateImage(request.file),
            )
          : await service.remove(principal.userId, input.body.expectedRevision),
      );
    } finally {
      response.locals.releaseProfileUpload?.();
    }
  };
}
