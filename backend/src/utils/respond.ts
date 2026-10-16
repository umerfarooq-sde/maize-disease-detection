import type { Response } from 'express';
import type { SuccessResponse } from '../types/api.js';
import { responseContract } from '../contracts/responses.js';
import { AppError } from '../errors/app-error.js';

export function sendSuccess<T>(response: Response, data: T, status = 200): void {
  const request = response.req;
  if (request?.route && request.baseUrl.startsWith('/api/v1')) {
    const path = (request.baseUrl.slice('/api/v1'.length) + String(request.route.path)).replace(
      /\/$/,
      '',
    );
    const contract = responseContract(request.method.toLowerCase(), path);
    if (contract && !contract.safeParse(data).success) throw new AppError('INTERNAL_SERVER_ERROR');
  }
  const body: SuccessResponse<T> = { success: true, data, requestId: response.locals.requestId };
  response.status(status).json(body);
}
