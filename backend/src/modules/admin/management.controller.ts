import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { ManagementService } from './management.service.js';
import type { DiseaseEdit, DraftDocument } from './management.types.js';

type Action =
  | 'diseases'
  | 'editDisease'
  | 'documents'
  | 'document'
  | 'createDraft'
  | 'index'
  | 'status';
export function managementController(service: ManagementService, action: Action): RequestHandler {
  return async (_request, response) => {
    const principal = response.locals.principal;
    if (!principal) throw new AppError('AUTHENTICATION_ERROR');
    const input = response.locals.validated as {
      body: unknown;
      params: { slug: string; id: string };
      query: { cursor?: string };
    };
    const actor = principal.userId,
      requestId = response.locals.requestId;
    let result: unknown;
    switch (action) {
      case 'diseases':
        result = await service.diseases();
        break;
      case 'editDisease':
        result = await service.editDisease(
          input.params.slug,
          input.body as DiseaseEdit,
          actor,
          requestId,
        );
        break;
      case 'documents':
        result = await service.documents(input.query.cursor);
        break;
      case 'document':
        result = await service.document(input.params.id);
        break;
      case 'createDraft':
        result = await service.createDraft(input.body as DraftDocument, actor, requestId);
        break;
      case 'index':
        result = await service.index(input.params.id, actor, requestId);
        break;
      case 'status': {
        const body = input.body as {
          status: 'ACTIVE' | 'ARCHIVED';
          expectedStatus: 'DRAFT' | 'ACTIVE' | 'ARCHIVED';
        };
        result = await service.changeStatus(
          input.params.id,
          body.status,
          body.expectedStatus,
          actor,
          requestId,
        );
        break;
      }
    }
    sendSuccess(response, result, action === 'createDraft' ? 201 : 200);
  };
}
