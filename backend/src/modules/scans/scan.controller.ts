import type { RequestHandler } from 'express';
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
