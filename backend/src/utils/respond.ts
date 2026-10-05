import type { Response } from 'express';
import type { SuccessResponse } from '../types/api.js';

export function sendSuccess<T>(response: Response, data: T, status = 200): void {
  const body: SuccessResponse<T> = { success: true, data, requestId: response.locals.requestId };
  response.status(status).json(body);
}
