import type { RequestHandler } from 'express';
import type { ModelSpecification } from './model-specification.types.js';
import type { SpecificationService } from './model-specification.service.js';
import { sendSuccess } from '../../utils/respond.js';
import { AppError } from '../../errors/app-error.js';
export function specificationController(
  service: SpecificationService,
  create = false,
): RequestHandler {
  return async (_request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    const actor = response.locals.principal?.userId;
    if (!actor) throw new AppError('AUTHENTICATION_ERROR');
    sendSuccess(
      response,
      create
        ? await service.create(
            (response.locals.validated as { body: ModelSpecification }).body,
            actor,
            response.locals.requestId,
          )
        : await service.list(),
      create ? 201 : 200,
    );
  };
}
