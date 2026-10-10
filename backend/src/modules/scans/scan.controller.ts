import type { RequestHandler } from 'express';
import { AppError } from '../../errors/app-error.js';
import { sendSuccess } from '../../utils/respond.js';
import type { ScanService } from './scan.service.js';

export function createScanController(service: ScanService): RequestHandler {
  return async (request, response) => {
    const input = response.locals.validated as { key: string };
    try {
      const result = await service.create(
        request.file,
        input.key,
        response.locals.principal?.userId ?? null,
      );
      response.setHeader('Cache-Control', 'no-store');
      sendSuccess(response, result.scan, result.replayed ? 200 : 201);
    } finally {
      response.locals.releaseUpload?.();
    }
  };
}

export function readScanController(service: ScanService): RequestHandler {
  return async (_request, response) => {
    const input = response.locals.validated as { params: { scanId: string }; key?: string };
    response.setHeader('Cache-Control', 'no-store');
    sendSuccess(
      response,
      await service.read(input.params.scanId, response.locals.principal?.userId ?? null, input.key),
    );
  };
}

export function scanHistoryController(service: ScanService): RequestHandler {
  return async (_request, response) => {
    const principal = response.locals.principal;
    if (!principal) throw new AppError('AUTHENTICATION_ERROR');
    const input = response.locals.validated as { limit: number; cursor?: string };
    sendSuccess(response, await service.history(principal.userId, input.limit, input.cursor));
  };
}
