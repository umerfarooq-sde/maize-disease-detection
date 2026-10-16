import type { RequestHandler } from 'express';
import { sendSuccess } from '../../utils/respond.js';
import { AppError } from '../../errors/app-error.js';
import { validateImage } from '../scans/scan.validation.js';
import type { PrivateImageReader } from '../scans/private-image.js';
import type { ReferenceService } from './media.service.js';
import type { ReferenceMetadata, referenceEdit, referenceStatus } from './media.types.js';
import type { z } from 'zod';
type Action = 'list' | 'upload' | 'edit' | 'status' | 'image';
export function referenceController(
  service: ReferenceService,
  action: Action,
  admin: boolean,
  readImage: PrivateImageReader,
): RequestHandler {
  return async (request, response) => {
    try {
      const { body, params } = response.locals.validated as {
        body: unknown;
        params: { slug: string; id: string };
      };
      const actor = response.locals.principal?.userId ?? '';
      if (admin && !actor) throw new AppError('AUTHENTICATION_ERROR');
      if (action === 'image') {
        const image = await readImage(await service.imageLocation(params.id, admin));
        response.setHeader('Cache-Control', 'private, no-store');
        response.setHeader('Referrer-Policy', 'no-referrer');
        response.type(image.mimeType).send(image.bytes);
        return;
      }
      const result =
        action === 'list'
          ? await service.list(params.slug, admin)
          : action === 'upload'
            ? await service.upload(
                body as ReferenceMetadata,
                await validateImage(request.file),
                actor,
                response.locals.requestId,
              )
            : action === 'edit'
              ? await service.edit(
                  params.id,
                  body as z.infer<typeof referenceEdit>,
                  actor,
                  response.locals.requestId,
                )
              : await service.status(
                  params.id,
                  body as z.infer<typeof referenceStatus>,
                  actor,
                  response.locals.requestId,
                );
      sendSuccess(response, result, action === 'upload' ? 201 : 200);
    } finally {
      response.locals.releaseReferenceUpload?.();
    }
  };
}
