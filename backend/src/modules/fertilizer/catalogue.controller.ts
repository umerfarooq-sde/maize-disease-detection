import type { RequestHandler } from 'express';
import type { z } from 'zod';
import { sendSuccess } from '../../utils/respond.js';
import { AppError } from '../../errors/app-error.js';
import type { ProductService } from './catalogue.service.js';
import type { ProductWrite, productStatus } from './catalogue.types.js';
export function productController(
  service: ProductService,
  action: 'list' | 'create' | 'edit' | 'status',
): RequestHandler {
  return async (_request, response) => {
    const actor = response.locals.principal?.userId;
    if (!actor) throw new AppError('AUTHENTICATION_ERROR');
    const input = response.locals.validated as {
      body: unknown;
      params: { id: string };
      query: { cursor?: string };
    };
    response.setHeader('Cache-Control', 'no-store');
    const status = input.body as z.infer<typeof productStatus>;
    sendSuccess(
      response,
      action === 'list'
        ? await service.list(input.query.cursor)
        : action === 'status'
          ? await service.status(
              input.params.id,
              status.expectedRevision,
              status.status,
              actor,
              response.locals.requestId,
            )
          : await service.write(
              action === 'create' ? null : input.params.id,
              input.body as ProductWrite,
              actor,
              response.locals.requestId,
            ),
      action === 'create' ? 201 : 200,
    );
  };
}
